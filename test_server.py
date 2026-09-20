import io
import json
import unittest
from unittest.mock import patch

import server


DOCUMENTS = [
    {
        "id": "flight",
        "name": "Flight to Tokyo.pdf",
        "kind": "PDF",
        "modified": "Yesterday",
        "summary": "Tokyo flight confirmation and terminal details.",
    },
    {
        "id": "hotel",
        "name": "Kyoto hotel.pdf",
        "kind": "PDF",
        "modified": "Sep 16",
        "summary": "Kyoto hotel reservation.",
    },
]


class FakeResponse:
    def __init__(self, payload):
        self.body = io.BytesIO(json.dumps(payload).encode())

    def __enter__(self):
        return self.body

    def __exit__(self, *_args):
        return False


class JevPayloadTests(unittest.TestCase):
    def test_builds_one_noul_question_per_document(self):
        payload = server.build_jev_payload("Stuff I need at the airport", DOCUMENTS)

        self.assertEqual(payload["model"], "jev-latest")
        self.assertEqual(set(payload["questions"]), {"flight", "hotel"})
        self.assertTrue(all(item["type"] == "noul" for item in payload["questions"].values()))
        self.assertNotIn("secret-key", json.dumps(payload))

    def test_membership_threshold_is_deterministic(self):
        result = {"answers": {"flight": {"noul": 0.91}, "hotel": {"noul": 0.42}}}

        memberships = server.parse_memberships(DOCUMENTS, result)

        self.assertEqual(
            memberships,
            [
                {"id": "flight", "belongs": True, "confidence": 0.91},
                {"id": "hotel", "belongs": False, "confidence": 0.42},
            ],
        )

    def test_invalid_jev_answer_is_rejected(self):
        with self.assertRaises(ValueError):
            server.parse_memberships(DOCUMENTS, {"answers": {"flight": {"noul": 1.2}}})

    @patch("server.urllib.request.urlopen")
    def test_classification_uses_mocked_http_response(self, mocked_urlopen):
        mocked_urlopen.return_value = FakeResponse(
            {"answers": {"flight": {"noul": 0.95}, "hotel": {"noul": 0.18}}}
        )

        result = server.classify_with_jev("Airport files", DOCUMENTS, "secret-key")

        self.assertEqual([item["belongs"] for item in result], [True, False])
        request = mocked_urlopen.call_args.args[0]
        self.assertEqual(request.headers["Authorization"], "Bearer secret-key")
        mocked_urlopen.assert_called_once()


if __name__ == "__main__":
    unittest.main()
