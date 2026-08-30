#!/usr/bin/env python3
"""
AI Vision Scenario Runner — Choyce Engine (TASK-063)

Drives Godot 4 application scenarios using:
  - TestBridgeAdapter HTTP API for state/screenshot/input
  - Anthropic or LiteLLM Responses vision API for screenshot-based assertions (soft gate)
  - JSON field assertions on gdGSI state (hard gate)

TITAN-pattern execution: Perception Abstraction → Action Optimisation →
Reflective Reasoning → Issue Diagnosis.

Usage:
    python3 scripts/testing/ai_vision_runner.py \\
        --bridge-url http://localhost:9876 \\
        --scenarios tests/ai-scenarios/kid-flows \\
        --task TASK-059 \\
        --tier 1 \\
        --output .ai/manual-qa/TASK-059/evidence

Requirements:
    pip install anthropic pyyaml requests
    ANTHROPIC_API_KEY or LITELLM_API_KEY must be set for the selected provider.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import anthropic
import requests
import yaml

# ── Configuration ─────────────────────────────────────────────────────────────

VISION_MODEL = "claude-opus-4-6"
MAX_TOKENS = 512
STALL_THRESHOLD = 3          # reflective retry after N steps with no state change
REQUEST_TIMEOUT = 30         # seconds for bridge HTTP calls
VISION_REQUEST_TIMEOUT = 90  # seconds for vision provider HTTP calls
SCREENSHOT_RETRY = 3         # retries for screenshot capture
CONFIDENCE_AUTO_PASS = 0.90  # vision confidence threshold for auto-pass


# ── Evidence helpers ──────────────────────────────────────────────────────────

def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def git_sha() -> str:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout.strip() or "unknown"
    except Exception:
        return "unknown"


def make_evidence_dir(output_root: Path, scenario_id: str, run_id: str) -> Path:
    path = output_root / scenario_id / f"run-{run_id}"
    path.mkdir(parents=True, exist_ok=True)
    return path


# ── Bridge client ─────────────────────────────────────────────────────────────

class BridgeClient:
    def __init__(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/")

    def health(self) -> bool:
        try:
            r = requests.get(f"{self.base_url}/health", timeout=REQUEST_TIMEOUT)
            return r.status_code == 200
        except Exception:
            return False

    def get_state(self) -> dict[str, Any]:
        try:
            r = requests.get(f"{self.base_url}/state", timeout=REQUEST_TIMEOUT)
            r.raise_for_status()
            return r.json()
        except Exception as exc:
            print(f"  [bridge] state fetch failed: {exc}", file=sys.stderr)
            return {}

    def screenshot_png_b64(self) -> str | None:
        for attempt in range(SCREENSHOT_RETRY):
            try:
                r = requests.get(f"{self.base_url}/screenshot", timeout=REQUEST_TIMEOUT)
                if r.status_code == 200:
                    return base64.standard_b64encode(r.content).decode()
            except Exception as exc:
                print(f"  [bridge] screenshot attempt {attempt+1} failed: {exc}", file=sys.stderr)
                time.sleep(1)
        return None

    def inject_input(self, event: dict) -> bool:
        try:
            r = requests.post(
                f"{self.base_url}/input",
                json=event,
                timeout=REQUEST_TIMEOUT
            )
            return r.status_code == 200 and r.json().get("accepted", False)
        except Exception as exc:
            print(f"  [bridge] input inject failed: {exc}", file=sys.stderr)
            return False


# ── Claude vision assertion ───────────────────────────────────────────────────

class VisionAsserter:
    def __init__(
        self,
        client: Any | None,
        provider: str = "anthropic",
        model: str | None = None,
        litellm_base_url: str | None = None,
        litellm_api_key: str | None = None,
        vision_request_timeout: int = VISION_REQUEST_TIMEOUT,
    ) -> None:
        self._client = client
        self._provider = provider
        self._model = model or VISION_MODEL
        self._litellm_base_url = (litellm_base_url or "").rstrip("/")
        self._litellm_api_key = litellm_api_key
        self._vision_request_timeout = vision_request_timeout

    def assert_screenshot(
        self,
        png_b64: str,
        prompt_en: str,
        prompt_pl: str | None = None,
    ) -> tuple[bool, float, str]:
        """
        Returns (passed: bool, confidence: float, reasoning: str).
        Confidence ≥ CONFIDENCE_AUTO_PASS → hard pass.
        Confidence < CONFIDENCE_AUTO_PASS → flagged for human review.
        """
        display_prompt = prompt_pl or prompt_en
        system = (
            "You are a QA engineer validating a screenshot from a Polish-language "
            "kid-safe game engine application. Answer the test question with a "
            "structured JSON response: "
            '{"pass": true|false, "confidence": 0.0-1.0, "reasoning": "..."}'
            " where confidence reflects how certain you are, 1.0 = completely certain."
        )
        user_text = (
            f"Test question: {display_prompt}\n\n"
            f"(English reference: {prompt_en})\n\n"
            "Answer ONLY with the JSON object, no other text."
        )
        try:
            if self._provider == "litellm":
                return self._assert_with_litellm(png_b64, system, user_text)

            response = self._client.messages.create(
                model=self._model,
                max_tokens=MAX_TOKENS,
                system=system,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image",
                                "source": {
                                    "type": "base64",
                                    "media_type": "image/png",
                                    "data": png_b64,
                                },
                            },
                            {"type": "text", "text": user_text},
                        ],
                    }
                ],
            )
            raw = response.content[0].text.strip()
            return self._parse_verdict(raw)
        except Exception as exc:
            return False, 0.0, f"Vision API error: {exc}"

    def _assert_with_litellm(
        self,
        png_b64: str,
        instructions: str,
        user_text: str,
    ) -> tuple[bool, float, str]:
        response = requests.post(
            f"{self._litellm_base_url}/v1/responses",
            headers={"Authorization": f"Bearer {self._litellm_api_key}"},
            json={
                "model": self._model,
                "instructions": instructions,
                "input": [{
                    "role": "user",
                    "content": [
                        {"type": "input_text", "text": user_text},
                        {"type": "input_image", "image_url": f"data:image/png;base64,{png_b64}"},
                    ],
                }],
            },
            timeout=self._vision_request_timeout,
        )
        response.raise_for_status()
        raw = self._extract_output_text(response.json())
        return self._parse_verdict(raw)

    @staticmethod
    def _extract_output_text(response: dict[str, Any]) -> str:
        if isinstance(response.get("output_text"), str):
            return response["output_text"].strip()
        for output in response.get("output", []):
            for content in output.get("content", []):
                if content.get("type") == "output_text" and isinstance(content.get("text"), str):
                    return content["text"].strip()
        raise ValueError("Responses API result did not contain output_text")

    @staticmethod
    def _parse_verdict(raw: str) -> tuple[bool, float, str]:
        parsed = json.loads(raw)
        passed = bool(parsed.get("pass", False))
        confidence = float(parsed.get("confidence", 0.0))
        reasoning = str(parsed.get("reasoning", ""))
        return passed, confidence, reasoning


# ── State assertion ───────────────────────────────────────────────────────────

def assert_state(state: dict, section: str, field: str, expected: Any) -> tuple[bool, str]:
    section_data = state.get(section, {})
    actual = section_data.get(field, "__MISSING__")
    if actual == expected:
        return True, f"{section}.{field} == {expected!r}"
    return False, f"{section}.{field}: expected {expected!r}, got {actual!r}"


# ── Reflective reasoning ──────────────────────────────────────────────────────

def state_fingerprint(state: dict) -> str:
    return json.dumps(state, sort_keys=True)


# ── Scenario execution ────────────────────────────────────────────────────────

def execute_scenario(
    scenario: dict,
    bridge: BridgeClient,
    vision: VisionAsserter,
    evidence_dir: Path,
    run_id: str,
    tier: int,
) -> dict[str, Any]:
    scenario_id = scenario["id"]
    steps = scenario.get("steps", [])
    results: list[dict] = []
    stall_count = 0
    prev_fingerprint = ""

    print(f"\n=== {scenario_id}: {scenario.get('title', '')} ===")
    print(f"    Tier: {tier} | Steps: {len(steps)} | Run: {run_id}")

    for step in steps:
        step_id = step.get("id", "unknown")
        action = step.get("action", "")
        print(f"  [{step_id}] {action}: {step.get('description', step.get('prompt_en', ''))[:60]}")

        step_result: dict[str, Any] = {
            "step_id": step_id,
            "action": action,
            "timestamp": now_iso(),
        }

        # Reflective reasoning: detect stall
        current_state = bridge.get_state()
        current_fp = state_fingerprint(current_state)
        if current_fp == prev_fingerprint and action not in ("assert_visual", "capture_evidence"):
            stall_count += 1
            if stall_count >= STALL_THRESHOLD:
                print(f"  [reflect] No state change after {stall_count} steps — triggering reflection")
                stall_count = 0
                step_result["reflection_triggered"] = True
        else:
            stall_count = 0
        prev_fingerprint = current_fp

        if action == "assert_visual":
            png_b64 = bridge.screenshot_png_b64()
            if png_b64 is None:
                step_result.update({"verdict": "ERROR", "reasoning": "Screenshot unavailable"})
                results.append(step_result)
                continue
            # Save screenshot
            png_path = evidence_dir / f"{step_id}.png"
            png_path.write_bytes(base64.standard_b64decode(png_b64))
            step_result["screenshot"] = str(png_path)

            passed, confidence, reasoning = vision.assert_screenshot(
                png_b64,
                step.get("prompt_en", ""),
                step.get("prompt_pl"),
            )
            threshold = float(step.get("confidence_threshold", CONFIDENCE_AUTO_PASS))
            auto_verdict = "PASS" if (passed and confidence >= threshold) else (
                "REVIEW" if (passed and confidence < threshold) else "FAIL"
            )
            step_result.update({
                "verdict": auto_verdict,
                "confidence": confidence,
                "reasoning": reasoning,
            })
            verdict_path = evidence_dir / f"{step_id}-verdict.json"
            verdict_path.write_text(json.dumps(step_result, indent=2), encoding="utf-8")
            print(f"    → {auto_verdict} (confidence={confidence:.2f}): {reasoning[:80]}")

        elif action == "assert_state":
            passed, msg = assert_state(
                current_state,
                step.get("section", ""),
                step.get("field", ""),
                step.get("expected"),
            )
            step_result.update({"verdict": "PASS" if passed else "FAIL", "detail": msg})
            print(f"    → {'PASS' if passed else 'FAIL'}: {msg}")

        elif action == "input":
            event: dict = {
                "type": step.get("type", "mouse_button"),
                "pressed": step.get("pressed", True),
            }
            if "position" in step:
                pos = step["position"]
                event["position"] = {"x": pos[0], "y": pos[1]} if isinstance(pos, list) else pos
            if "button_index" in step:
                event["button_index"] = step["button_index"]
            if "keycode" in step:
                event["keycode"] = step["keycode"]
            ok = bridge.inject_input(event)
            step_result.update({"verdict": "PASS" if ok else "WARN", "accepted": ok})
            print(f"    → input {'accepted' if ok else 'rejected'}")
            time.sleep(float(step.get("wait_after_ms", 500)) / 1000)

        elif action == "wait_for_event":
            deadline = time.monotonic() + float(step.get("timeout_seconds", 10))
            found = False
            while time.monotonic() < deadline:
                s = bridge.get_state()
                val = s.get(step.get("section", ""), {}).get(step.get("field", ""))
                if val == step.get("expected"):
                    found = True
                    break
                time.sleep(0.5)
            step_result.update({"verdict": "PASS" if found else "FAIL", "found": found})
            print(f"    → wait {'resolved' if found else 'timed out'}")

        elif action == "capture_evidence":
            png_b64 = bridge.screenshot_png_b64()
            if png_b64:
                png_path = evidence_dir / f"{step_id}-evidence.png"
                png_path.write_bytes(base64.standard_b64decode(png_b64))
                step_result["screenshot"] = str(png_path)
            state_path = evidence_dir / f"{step_id}-state.json"
            state_path.write_text(json.dumps(current_state, indent=2), encoding="utf-8")
            step_result["verdict"] = "PASS"
            print(f"    → evidence captured")

        elif action == "navigate_to":
            # Navigation is driven by injecting a named action; the game handles routing
            event = {"type": "action", "action_name": step.get("target", ""), "pressed": True}
            bridge.inject_input(event)
            time.sleep(float(step.get("wait_after_ms", 1000)) / 1000)
            step_result["verdict"] = "PASS"
            print(f"    → navigate to {step.get('target')}")

        else:
            step_result.update({"verdict": "SKIP", "reason": f"Unknown action: {action}"})
            print(f"    → SKIP (unknown action)")

        results.append(step_result)

    # Build summary
    passed = sum(1 for r in results if r.get("verdict") == "PASS")
    failed = sum(1 for r in results if r.get("verdict") == "FAIL")
    review = sum(1 for r in results if r.get("verdict") == "REVIEW")
    overall = "PASS" if failed == 0 and review == 0 else ("REVIEW" if failed == 0 else "FAIL")

    summary = {
        "scenario_id": scenario_id,
        "run_id": run_id,
        "commit_sha": git_sha(),
        "hardware_tier": tier,
        "overall_verdict": overall,
        "steps_total": len(results),
        "steps_passed": passed,
        "steps_flagged_for_review": review,
        "steps_failed": failed,
        "requirement_ids": scenario.get("requirement_ids", []),
        "steps": results,
    }
    summary_path = evidence_dir / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n  Summary: {overall} ({passed} pass, {review} review, {failed} fail)")
    return summary


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(description="AI Vision Scenario Runner for Choyce Engine")
    parser.add_argument("--bridge-url", default="http://localhost:9876")
    parser.add_argument("--scenarios", required=True, help="Path to scenario YAML dir or file")
    parser.add_argument("--task", default="TASK-000", help="Task ID for evidence folder naming")
    parser.add_argument("--tier", type=int, default=1, choices=[1, 2])
    parser.add_argument("--output", default=".ai/manual-qa", help="Evidence output root")
    parser.add_argument("--timeout", type=int, default=30, help="Bridge connection timeout (s)")
    parser.add_argument(
        "--vision-request-timeout",
        type=int,
        default=VISION_REQUEST_TIMEOUT,
        help="Vision provider request timeout in seconds (default: 90)",
    )
    parser.add_argument("--vision-provider", choices=["anthropic", "litellm"], default="anthropic")
    parser.add_argument("--vision-model", help="Model for the selected vision provider")
    parser.add_argument("--litellm-base-url", default=os.environ.get("LITELLM_BASE_URL"))
    args = parser.parse_args()

    if args.vision_provider == "anthropic":
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            print("ERROR: ANTHROPIC_API_KEY not set", file=sys.stderr)
            return 1
        vision = VisionAsserter(
            anthropic.Anthropic(api_key=api_key),
            model=args.vision_model,
        )
    else:
        api_key = os.environ.get("LITELLM_API_KEY")
        if not api_key:
            print("ERROR: LITELLM_API_KEY not set", file=sys.stderr)
            return 1
        if not args.litellm_base_url:
            print("ERROR: LITELLM_BASE_URL not set", file=sys.stderr)
            return 1
        vision = VisionAsserter(
            None,
            provider="litellm",
            model=args.vision_model or "opencode/gpt-5.6",
            litellm_base_url=args.litellm_base_url,
            litellm_api_key=api_key,
            vision_request_timeout=args.vision_request_timeout,
        )

    bridge = BridgeClient(args.bridge_url)
    print(f"Checking bridge at {args.bridge_url}…")
    deadline = time.monotonic() + args.timeout
    while not bridge.health():
        if time.monotonic() > deadline:
            print("ERROR: Bridge not reachable within timeout", file=sys.stderr)
            return 1
        time.sleep(2)
    print("Bridge connected.")

    scenarios_path = Path(args.scenarios)
    yaml_files: list[Path] = []
    if scenarios_path.is_file():
        yaml_files = [scenarios_path]
    elif scenarios_path.is_dir():
        yaml_files = sorted(scenarios_path.glob("**/*.yaml"))
    if not yaml_files:
        print(f"ERROR: No scenario YAML files found at {scenarios_path}", file=sys.stderr)
        return 1

    output_root = Path(args.output) / args.task / "evidence"
    run_id = now_iso()
    all_summaries: list[dict] = []

    for yaml_file in yaml_files:
        with yaml_file.open(encoding="utf-8") as f:
            scenario = yaml.safe_load(f)
        if not scenario or "id" not in scenario:
            print(f"  Skipping {yaml_file}: missing 'id' field")
            continue
        if args.tier not in scenario.get("tier", [1, 2]):
            print(f"  Skipping {scenario['id']}: not in tier {args.tier}")
            continue
        ev_dir = make_evidence_dir(output_root, scenario["id"], run_id)
        summary = execute_scenario(scenario, bridge, vision, ev_dir, run_id, args.tier)
        all_summaries.append(summary)

    # Rollup report
    total_pass = sum(1 for s in all_summaries if s["overall_verdict"] == "PASS")
    total_review = sum(1 for s in all_summaries if s["overall_verdict"] == "REVIEW")
    total_fail = sum(1 for s in all_summaries if s["overall_verdict"] == "FAIL")
    rollup_verdict = "PASS" if total_fail == 0 and total_review == 0 else (
        "REVIEW" if total_fail == 0 else "FAIL"
    )

    rollup = {
        "task": args.task,
        "tier": args.tier,
        "run_id": run_id,
        "commit_sha": git_sha(),
        "overall_verdict": rollup_verdict,
        "scenarios_total": len(all_summaries),
        "scenarios_passed": total_pass,
        "scenarios_flagged_for_review": total_review,
        "scenarios_failed": total_fail,
        "scenarios": all_summaries,
    }
    rollup_path = output_root.parent / f"rollup-tier{args.tier}-{run_id}.json"
    rollup_path.write_text(json.dumps(rollup, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"\n{'='*60}")
    print(f"ROLLUP: {rollup_verdict}")
    print(f"  Scenarios: {len(all_summaries)} total, {total_pass} pass, {total_review} review, {total_fail} fail")
    print(f"  Report: {rollup_path}")

    return 0 if rollup_verdict in ("PASS", "REVIEW") else 1


if __name__ == "__main__":
    sys.exit(main())
