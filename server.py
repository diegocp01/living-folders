import json
import os
import shlex
import ssl
import urllib.error
import urllib.request
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import certifi


ROOT = Path(__file__).parent
os.chdir(ROOT)


def load_env(path: Path) -> None:
    """Load only the supported secret without executing the file."""
    if not path.is_file():
        return

    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith("export "):
            line = line[7:].strip()
        name, separator, raw = line.partition("=")
        if separator and name.strip() == "TYPESAFE_API_KEY":
            values = shlex.split(raw, comments=True)
            if len(values) == 1 and values[0]:
                os.environ.setdefault("TYPESAFE_API_KEY", values[0])


load_env(ROOT / ".env")

PUBLIC_FILES = {"/", "/index.html", "/app.js", "/style.css", "/wallpaper.png"}
MAX_DOCUMENTS = 40
TLS_CONTEXT = ssl.create_default_context(cafile=certifi.where())


def build_jev_payload(folder_name: str, documents: list[dict]) -> dict:
    state = {
        "virtual_folder": folder_name,
        "documents": [
            {
                "id": item["id"],
                "name": item["name"],
                "kind": item.get("kind", "document"),
                "modified": item.get("modified", "unknown"),
                "summary": item.get("summary", ""),
            }
            for item in documents
        ],
    }
    questions = {}
    for item in documents:
        questions[item["id"]] = {
            "type": "noul",
            "instructions": (
                f"The virtual folder is named: {folder_name!r}. "
                f"Would the file {item['name']!r} meaningfully belong in that collection? "
                "Use the filename, kind, summary, and ordinary user intent. "
                "Be selective: related is not enough; it should be useful for the named purpose."
            ),
        }
    return {"model": "jev-latest", "state": json.dumps(state), "questions": questions}


def parse_memberships(documents: list[dict], result: dict, threshold: float = 0.55) -> list[dict]:
    answers = result.get("answers", {})
    memberships = []
    for item in documents:
        answer = answers.get(item["id"], {})
        score = answer.get("noul")
        if not isinstance(score, (int, float)) or not 0 <= score <= 1:
            raise ValueError(f"Invalid Jev answer for {item['id']}")
        memberships.append(
            {
                "id": item["id"],
                "belongs": score >= threshold,
                "confidence": round(float(score), 3),
            }
        )
    return memberships


def classify_with_jev(folder_name: str, documents: list[dict], api_key: str) -> list[dict]:
    payload = build_jev_payload(folder_name, documents)
    request = urllib.request.Request(
        "https://api.typesafe.ai/v1/systemone",
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=20, context=TLS_CONTEXT) as response:
        result = json.load(response)
    return parse_memberships(documents, result)


class Handler(SimpleHTTPRequestHandler):
    def send_json(self, data: dict, status: int = 200) -> None:
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/api/status":
            configured = bool(os.getenv("TYPESAFE_API_KEY"))
            return self.send_json({"mode": "jev" if configured else "demo", "configured": configured})

        if self.path.split("?")[0] not in PUBLIC_FILES:
            return self.send_error(404)
        return super().do_GET()

    def do_POST(self):
        if self.path != "/api/classify":
            return self.send_error(404)

        try:
            size = int(self.headers.get("Content-Length", 0))
            if size <= 0 or size > 100_000:
                return self.send_json({"error": "Invalid request size."}, 413)

            data = json.loads(self.rfile.read(size))
            folder_name = str(data.get("folder", "")).strip()
            documents = data.get("documents", [])
            if not 3 <= len(folder_name) <= 160:
                return self.send_json({"error": "Give the folder a more specific name."}, 400)
            if not isinstance(documents, list) or not 1 <= len(documents) <= MAX_DOCUMENTS:
                return self.send_json({"error": "Invalid document collection."}, 400)
            if any(not isinstance(item, dict) or not item.get("id") or not item.get("name") for item in documents):
                return self.send_json({"error": "Every document needs an id and name."}, 400)

            api_key = os.getenv("TYPESAFE_API_KEY")
            if not api_key:
                return self.send_json({"error": "Jev is not configured."}, 503)

            memberships = classify_with_jev(folder_name, documents, api_key)
            return self.send_json({"memberships": memberships, "model": "jev-latest"})
        except (json.JSONDecodeError, ValueError):
            return self.send_json({"error": "Jev returned an invalid classification."}, 502)
        except urllib.error.HTTPError as error:
            status = 401 if error.code in (401, 403) else 502
            return self.send_json({"error": "Jev authentication failed." if status == 401 else "Jev is unavailable."}, status)
        except (urllib.error.URLError, TimeoutError):
            return self.send_json({"error": "Jev did not respond. Try again."}, 502)
        except Exception:
            return self.send_json({"error": "The classification could not be completed."}, 502)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8787), Handler).serve_forever()
