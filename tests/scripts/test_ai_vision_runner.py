import base64
import importlib.util
import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


RUNNER_PATH = Path(__file__).parents[2] / "scripts/testing/ai_vision_runner.py"
SPEC = importlib.util.spec_from_file_location("ai_vision_runner", RUNNER_PATH)
ai_vision_runner = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(ai_vision_runner)


class ResponsesFixture(BaseHTTPRequestHandler):
    request_body = None
    request_path = None

    def do_POST(self):
        type(self).request_path = self.path
        length = int(self.headers["Content-Length"])
        type(self).request_body = json.loads(self.rfile.read(length))
        verdict = json.dumps({"pass": True, "confidence": 0.96, "reasoning": "Scene is visible."})
        response = {
            "output": [{
                "type": "message",
                "content": [{"type": "output_text", "text": verdict}],
            }],
        }
        encoded = json.dumps(response).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format, *args):
        pass


class LiteLLMResponsesVisionTest(unittest.TestCase):
    def setUp(self):
        ResponsesFixture.request_body = None
        ResponsesFixture.request_path = None
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), ResponsesFixture)
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.thread.join()
        self.server.server_close()

    def test_litellm_responses_backend_sends_image_and_parses_verdict(self):
        # This fails if the runner changes endpoint, drops the image, or skips output_text parsing.
        vision = ai_vision_runner.VisionAsserter(
            client=None,
            provider="litellm",
            model="opencode/gpt-5.6",
            litellm_base_url=f"http://127.0.0.1:{self.server.server_port}",
            litellm_api_key="test-key",
        )

        actual = vision.assert_screenshot(
            base64.standard_b64encode(b"png-bytes").decode("ascii"),
            "Is the scene visible?",
        )

        self.assertEqual((True, 0.96, "Scene is visible."), actual)
        self.assertEqual("/v1/responses", ResponsesFixture.request_path)
        self.assertEqual("opencode/gpt-5.6", ResponsesFixture.request_body["model"])
        content = ResponsesFixture.request_body["input"][0]["content"]
        self.assertEqual("input_text", content[0]["type"])
        self.assertEqual("input_image", content[1]["type"])
        self.assertEqual("data:image/png;base64,cG5nLWJ5dGVz", content[1]["image_url"])


if __name__ == "__main__":
    unittest.main()
