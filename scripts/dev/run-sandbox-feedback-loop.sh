#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${CHOYCE_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PORT="${CHOYCE_FEEDBACK_PORT:-9887}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
EVIDENCE_DIR="${CHOYCE_FEEDBACK_DIR:-${REPO_ROOT}/.ai/local-feedback/sandbox-${RUN_ID}}"
LOG_PATH="${EVIDENCE_DIR}/godot.log"
GODOT_PID=""

if [[ ! -x "$GODOT_BIN" ]]; then
  GODOT_BIN="$(command -v godot4 || command -v godot || true)"
fi
if [[ -z "${GODOT_BIN:-}" || ! -x "$GODOT_BIN" ]]; then
  echo "Cannot find Godot 4. Set CHOYCE_GODOT_BIN to its absolute path." >&2
  exit 127
fi

mkdir -p "$EVIDENCE_DIR"

cleanup() {
  if [[ -n "$GODOT_PID" ]]; then
    kill "$GODOT_PID" 2>/dev/null || true
    wait "$GODOT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

run_headless_gate() {
  local label="$1"
  local script="$2"
  echo "[feedback] headless gate: ${label}"
  "$GODOT_BIN" --headless --path "$REPO_ROOT" --script "$script" \
    >"${EVIDENCE_DIR}/${label}.log" 2>&1
}

run_headless_gate bridge tests/adapters/outbound/test_test_bridge_adapter.gd
run_headless_gate sandbox_art tests/gameplay/test_sandbox_art_assets.gd
run_headless_gate sandbox_input tests/gameplay/test_sandbox_player_mouse_input.gd
run_headless_gate sandbox_e2e tests/e2e/run_sandbox_kit_suite.gd

echo "[feedback] launching real GPU sandbox on localhost:${PORT}"
(
  cd "$REPO_ROOT"
  CHOYCE_AUTOPLAY="local_kid_1_starter_sandbox_kit" \
  CHOYCE_DEBUG_TEST_BRIDGE=1 \
  CHOYCE_DEBUG_BRIDGE_PORT="$PORT" \
  CHOYCE_FEATURE_OVERRIDES="debug_test_bridge=true" \
  "$GODOT_BIN" --path "$REPO_ROOT"
) >"$LOG_PATH" 2>&1 &
GODOT_PID=$!

BRIDGE_URL="http://127.0.0.1:${PORT}"
for _ in $(seq 1 30); do
  if curl -fsS "${BRIDGE_URL}/health" >"${EVIDENCE_DIR}/health.json"; then
    break
  fi
  sleep 1
done
if [[ ! -s "${EVIDENCE_DIR}/health.json" ]]; then
  echo "[feedback] bridge did not become ready" >&2
  tail -80 "$LOG_PATH" >&2 || true
  exit 1
fi

sleep "${CHOYCE_FEEDBACK_WARMUP_SEC:-4}"

capture() {
  local name="$1"
  curl -fsS "${BRIDGE_URL}/screenshot" -o "${EVIDENCE_DIR}/${name}.png"
}

capture_state() {
  local name="$1"
  curl -fsS "${BRIDGE_URL}/state" -o "${EVIDENCE_DIR}/${name}.json"
}

send_input() {
  local payload="$1"
  curl -fsS -X POST "${BRIDGE_URL}/input" \
    -H 'Content-Type: application/json' \
    --data "$payload" \
    >>"${EVIDENCE_DIR}/input-responses.jsonl"
  printf '\n' >>"${EVIDENCE_DIR}/input-responses.jsonl"
}

send_action() {
  local payload="$1"
  curl -fsS -X POST "${BRIDGE_URL}/action" \
    -H 'Content-Type: application/json' \
    --data "$payload" \
    >>"${EVIDENCE_DIR}/action-responses.jsonl"
  printf '\n' >>"${EVIDENCE_DIR}/action-responses.jsonl"
}

echo "[feedback] capturing initial GPU frame"
capture 01_initial
capture_state 01_initial_state

if ! jq -e '.runtime.sandbox_active == true and .runtime.session_active == true and (.runtime.players | length) >= 1' \
  "${EVIDENCE_DIR}/01_initial_state.json" >/dev/null; then
  echo "[feedback] FAIL: live runtime did not expose an active sandbox player" >&2
  exit 1
fi

if ! jq -e '
  .runtime.players[0].is_on_floor == true and
  (.runtime.players[0].position.y > 0.75 and .runtime.players[0].position.y < 1.1) and
  (.runtime.players[0].floor_probe.position.y > -0.1 and .runtime.players[0].floor_probe.position.y < 0.1) and
  (.runtime.players[0].animation == "Idle") and
  (.runtime.players[0].spring_arm.target_length > 0.0) and
  (.runtime.players[0].spring_arm.hit_length <= .runtime.players[0].spring_arm.target_length) and
  (.runtime.environment.found == true) and
  (.runtime.environment.ssao_enabled == true) and
  (.runtime.environment.glow_enabled == true) and
  (.runtime.environment.fog_enabled == true) and
  (.runtime.feedback.objective_icon_count == 5) and
  ((.runtime.companions | length) >= 3)
' "${EVIDENCE_DIR}/01_initial_state.json" >/dev/null; then
  echo "[feedback] FAIL: opening runtime contract (ground/camera/environment/objective/companions)" >&2
  exit 1
fi

INITIAL_YAW="$(jq -r '.runtime.players[0].yaw' "${EVIDENCE_DIR}/01_initial_state.json")"
INITIAL_X="$(jq -r '.runtime.players[0].position.x' "${EVIDENCE_DIR}/01_initial_state.json")"
INITIAL_Z="$(jq -r '.runtime.players[0].position.z' "${EVIDENCE_DIR}/01_initial_state.json")"

echo "[feedback] testing forward movement"
send_input '{"type":"key","keycode":87,"pressed":true}'
sleep 0.10
capture_state 01_forward_motion_state
if ! jq -e '.runtime.players[0].animation == "Walk"' "${EVIDENCE_DIR}/01_forward_motion_state.json" >/dev/null; then
  echo "[feedback] FAIL: live forward movement did not enter the AnimationTree Walk state" >&2
  exit 1
fi
sleep 0.35
send_input '{"type":"key","keycode":87,"pressed":false}'
sleep 0.15
capture_state 01_after_forward_state

if ! jq -e --argjson initial_x "$INITIAL_X" --argjson initial_z "$INITIAL_Z" '
  ((.runtime.players[0].position.x - $initial_x) * (.runtime.players[0].position.x - $initial_x) +
   (.runtime.players[0].position.z - $initial_z) * (.runtime.players[0].position.z - $initial_z)) > 0.25
' "${EVIDENCE_DIR}/01_after_forward_state.json" >/dev/null; then
  echo "[feedback] FAIL: forward input did not move the sandbox player" >&2
  exit 1
fi

if ! jq -e --slurpfile initial "${EVIDENCE_DIR}/01_initial_state.json" '
  . as $after |
  reduce range(0; ($after.runtime.companions | length)) as $i
    (false;
      . or
      (((($after.runtime.companions[$i].position.x - $initial[0].runtime.companions[$i].position.x) *
         ($after.runtime.companions[$i].position.x - $initial[0].runtime.companions[$i].position.x)) +
        (($after.runtime.companions[$i].position.z - $initial[0].runtime.companions[$i].position.z) *
         ($after.runtime.companions[$i].position.z - $initial[0].runtime.companions[$i].position.z))) > 0.05))
' "${EVIDENCE_DIR}/01_after_forward_state.json" >/dev/null; then
  echo "[feedback] FAIL: NavigationAgent3D companion did not displace while following the player" >&2
  exit 1
fi

echo "[feedback] testing mouse capture and relative motion"
send_input '{"type":"mouse_button","button_index":1,"pressed":true,"position":{"x":0.5,"y":0.5}}'
send_input '{"type":"mouse_motion","position":{"x":0.5,"y":0.5},"relative":{"x":260.0,"y":0.0},"velocity":{"x":260.0,"y":0.0}}'
sleep 1
capture 02_after_mouse_look
capture_state 02_after_mouse_look_state

echo "[feedback] testing ESC capture toggle without ending the session"
send_input '{"type":"key","keycode":4194305,"pressed":true}'
sleep 1
capture 03_after_escape
capture_state 03_after_escape_state

if cmp -s "${EVIDENCE_DIR}/01_initial.png" "${EVIDENCE_DIR}/02_after_mouse_look.png"; then
  echo "[feedback] FAIL: mouse-look frame did not change" >&2
  exit 1
fi

AFTER_YAW="$(jq -r '.runtime.players[0].yaw' "${EVIDENCE_DIR}/02_after_mouse_look_state.json")"
if [[ "$INITIAL_YAW" == "$AFTER_YAW" ]]; then
  echo "[feedback] FAIL: relative mouse motion did not change player yaw" >&2
  exit 1
fi

if ! jq -e '.runtime.session_active == true and .runtime.mouse_mode == 0' \
  "${EVIDENCE_DIR}/03_after_escape_state.json" >/dev/null; then
  echo "[feedback] FAIL: ESC did not release capture while keeping the session active" >&2
  exit 1
fi

if grep -q "Dobra robota" "$LOG_PATH"; then
  echo "[feedback] FAIL: ESC reached the completion path" >&2
  exit 1
fi

echo "[feedback] testing the offline opening slice loop"
send_action '{"action":"dialogue"}'
sleep 0.1
capture_state 03_dialogue_state
if ! jq -e '.runtime.dialogue_visible == true and .runtime.players[0].animation == "Talk"' "${EVIDENCE_DIR}/03_dialogue_state.json" >/dev/null; then
  echo "[feedback] FAIL: dialogue did not enter the live AnimationTree Talk state" >&2
  exit 1
fi
send_action '{"action":"gather","node":"OpeningSliceWood"}'
sleep 0.1
capture 03_after_gather_feedback
capture_state 03_after_gather_feedback_state
if ! jq -e '
  .runtime.objective_step >= 1 and
  .runtime.feedback.action_icon_visible == true and
  .runtime.feedback.objective_icon_count == 5
' "${EVIDENCE_DIR}/03_after_gather_feedback_state.json" >/dev/null; then
  echo "[feedback] FAIL: gather interaction did not expose immediate image-led feedback" >&2
  exit 1
fi
send_action '{"action":"gather","node":"OpeningSliceStone"}'
send_action '{"action":"gather","node":"OpeningSliceWood0"}'
send_action '{"action":"gather","node":"OpeningSliceWood1"}'
send_action '{"action":"craft","recipe":"stick"}'
send_action '{"action":"repair"}'
send_action '{"action":"reward"}'
send_action '{"action":"attack"}'
send_action '{"action":"save"}'
sleep 0.5
capture 04_after_opening_loop
capture_state 04_opening_loop_state

if ! jq -e '
  .runtime.dialogue_visible == true and
  ((.runtime.inventory.stick // 0) >= 1 or (.runtime.weapon_tier // 0) >= 1) and
  .runtime.slice_repaired == true and
  .runtime.slice_reward_claimed == true and
  (.runtime.score // 0) >= 75 and
  (.runtime.enemies_alive // 0) == 0 and
  (.runtime.probes.navigation.reachable == true)
' "${EVIDENCE_DIR}/04_opening_loop_state.json" >/dev/null; then
  echo "[feedback] FAIL: opening slice mechanics did not complete" >&2
  jq '.runtime | {inventory, dialogue_visible, enemies_alive, slice_repaired, slice_reward_claimed, score, probes}' "${EVIDENCE_DIR}/04_opening_loop_state.json" >&2
  exit 1
fi

echo "[feedback] testing explicit reset"
send_action '{"action":"reset"}'
sleep 0.5
capture_state 05_after_reset_state
if ! jq -e '
  (.runtime.inventory | length) == 0 and
  (.runtime.score // 0) == 0 and
  (.runtime.weapon_tier // 0) == 0 and
  .runtime.slice_repaired == false and
  .runtime.slice_reward_claimed == false
' "${EVIDENCE_DIR}/05_after_reset_state.json" >/dev/null; then
  echo "[feedback] FAIL: explicit reset did not restore opening state" >&2
  jq '.runtime | {inventory, score, weapon_tier, slice_repaired, slice_reward_claimed}' "${EVIDENCE_DIR}/05_after_reset_state.json" >&2
  exit 1
fi

echo "[feedback] PASS"
echo "[feedback] evidence: ${EVIDENCE_DIR}"
echo "[feedback] frames: 01_initial.png 02_after_mouse_look.png 03_after_escape.png 03_after_gather_feedback.png 04_after_opening_loop.png"
