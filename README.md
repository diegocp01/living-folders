# Living Folders

**What if naming a folder was all you had to do to organize it?**

A Finder-inspired demo powered by Jev. Name a virtual folder in plain language and watch matching files gather as you type. Change a few words and watch them rearrange—no Enter key, no chat, no real files moved.

Thirty sample documents, animated file cards, and a translucent desktop window. Built with vanilla JavaScript and a small Python server.

## Run

Requires Python 3.10+; Node.js 20+ is only needed for the JavaScript tests.

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
python3 server.py
```

Open <http://127.0.0.1:8787/?offline=1> to try the deterministic preview without credentials or API usage. Offline results use local demo rules, not Jev.

For live classification, copy `.env.example` to `.env`, add your Jev key, restart the server, and open <http://127.0.0.1:8787>. Typing in live mode sends requests to Jev and may consume API credits. The key stays on the Python server, is excluded from Git, and is unavailable through the static file server.

This is a local demo, bound to `127.0.0.1`. It is not configured as a public hosted service. Only synthetic document metadata is used; the app does not scan your disk.

## How it works

Space, paste, and preset selection trigger classification immediately. Other edits use a 120 ms idle fallback; Enter is unnecessary. Two requests can run concurrently, with only the latest waiting intent retained. Identical in-flight names share a request, and up to 64 successful results are cached for the page session. Every edit invalidates older UI results. Each request still evaluates all 30 documents in one batch. Card movement lasts 420 ms and avoids forced per-card layout reads. The server reuses its verified TLS context. These are scheduling guarantees, not a measured live Jev latency claim. The shorter idle delay can issue more requests during slow typing.

For a recorded demo, use the four suggested beats in order:

1. Stuff for my Japan trip
2. Stuff I need at the airport
3. Things I downloaded to become a different person
4. Fine. Just the Python tutorials.

Each update sends one `noul` question per document in a single `jev-latest` request. Jev decides membership and returns a probability. Browser code moves the existing cards so viewers can follow what stayed, joined, or left.

## Test without API usage

```bash
python3 -m unittest -v
node --check app.js
node --test test_scheduler.cjs
```

The Python suite mocks the network response and does not call Jev or consume API credit. Use <http://127.0.0.1:8787/?offline=1> for visual QA with deterministic sample classifications.

## Project files

- `app.js` — sample documents, request scheduling, offline rules, and animation.
- `style.css` / `index.html` — desktop interface and file artwork.
- `server.py` — static file allowlist and server-side Jev proxy.
- `wallpaper.png` — demo desktop background.
- `test_server.py` / `test_scheduler.cjs` — offline regression tests.
