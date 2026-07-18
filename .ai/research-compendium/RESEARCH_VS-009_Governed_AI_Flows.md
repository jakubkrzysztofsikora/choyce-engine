# RESEARCH VS-009: Governed AI Flows

## Choyce Engine - Vertical Slice Research Compendium

**Task ID:** VS-009  
**Title:** Replace voice and AI scaffolds with governed cancellable flows  
**Specialty:** ai-safety  
**Status:** in_progress  
**Dependencies:** [VS-008]  
**Owner:** codex  
**Cross-review:** claude  

---

## Table of Contents

1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research Summary](#online-research-summary)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Code Samples & Patterns](#code-samples--patterns)
6. [Security & Compliance](#security--compliance)
7. [Learning Resources](#learning-resources)
8. [Implementation Checklist](#implementation-checklist)
9. [Child-Safety Constraints](#child-safety-constraints)
10. [References](#references)

---

## Task Overview

### Objective

Replace existing synchronous AI/voice scaffolds with production-ready governed flows that:
- **Input Moderation:** Filter user prompts before LLM/STT processing
- **Output Moderation:** Filter AI responses before rendering/applying
- **Parent Approval:** Gate high-impact changes behind verifiable consent
- **Audit Events:** Log all AI interactions with revert capability
- **Cancellation:** Support safe cancellation of in-progress operations
- **Offline Fallback:** Graceful degradation when AI is unavailable

### Acceptance Criteria (from backlog.yaml)

- [ ] Input moderation precedes LLM/STT interpretation
- [ ] Output moderation precedes rendering/apply
- [ ] Parent approval gates high-impact changes
- [ ] Every mutation has audit event and revert path
- [ ] Cancellation and offline fallback are safe

### Existing Evidence (from backlog.yaml)

- `src/application/request_ai_creation_help_service.gd` (input and output text/image moderation gates)
- `src/application/approve_ai_patch_service.gd` (parent approval logic and event sourcing checkpoint)

---

## Current Implementation Analysis

### 1. RequestAICreationHelpService.gd

**File:** `src/application/request_ai_creation_help_service.gd`  
**Purpose:** Application service for AI-assisted creation requests  
**Key Features (from codebase):**

- Input text/image moderation gates
- Output moderation before applying changes
- Event-sourced action logging
- Parent approval workflow integration

**Pattern:** Ports and adapters - decouples AI orchestration from domain logic

### 2. ApproveAIPatchService.gd

**File:** `src/application/approve_ai_patch_service.gd`  
**Purpose:** Parent approval workflow for AI-generated changes  
**Key Features:**

- Parent approval logic
- Event sourcing checkpoints
- Rollback capability
- Audit trail

### 3. Current Architecture Gaps

Based on codebase review:
- Synchronous shim for AI tool execution (needs async replacement)
- Canned/placeholder voice input (needs real STT)
- Tauri bridge exists but needs authentication and production hardening
- Need bounded message handling and timeout enforcement

---

## Online Research Summary

### 1. Input/Output Moderation for LLMs

**Core Principle:** Defense in depth - filter at input, filter at output

**Approach:**
```
User Input → [Input Sanitization] → [Classification Filter] → LLM → [Output Filter] → [Safety Check] → User
```

**Key Resources:**
- **[Safe Child LLM Evaluation](https://github.com/The-Responsible-AI-Initiative/Safe_Child_LLM_Evaluation)** - Framework for stress-testing LLMs with 100 harmful queries (violence, self-harm, hate, etc.)
- **[Bluedot: Input/Output Filtering](https://blog.bluedot.org/p/input-output-filtering)** - Defense strategy for LLM safety
- **[Guardrailing LLMs](https://bhargavaparv.medium.com/guardrailing-large-language-models-llms-ensuring-safe-and-responsible-ai-a72791ea6a37)** - Comprehensive guide to LLM guardrails

**Classification Categories (must block):**
- Violence / harm
- Hate speech / discrimination
- Sexual content / grooming
- Self-harm / suicide
- Illegal activity
- Personal data exposure
- Profanity (configurable by age band)

**Implementation Options:**

| Method | Pros | Cons | Godot Integration |
|--------|------|------|-------------------|
| **Ollama Local + Safety Model** | Offline, private, fast | Needs GPU, model size | HTTPRequest to localhost:11434 |
| **Moderation API (OpenAI, Google)** | High accuracy, managed | Online dependency, cost | HTTPRequest with SSL |
| **Rule-Based Filter** | Fast, deterministic | Limited coverage | GDScript regex/keyword lists |
| **Hybrid (Rule + LLM)** | Best coverage | More complex | Combine approaches |

### 2. Parent Approval Gates (COPPA Compliance)

**Legal Requirements:**
- **COPPA:** Children under 13 require verifiable parental consent (VPC)
- **GDPR:** Similar requirements for EU children under 16 (configurable by region)
- **FTC Guidelines:** Consent must be informed, clear, and verifiable

**Verifiable Parental Consent Methods:**

| Method | Verification Level | Implementation Complexity | Cost |
|--------|-------------------|--------------------------|------|
| **Email Verification** | Low | Medium | Low |
| **Credit Card Check** | High | High (PCI compliance) | Medium |
| **SMS Verification** | Medium | Medium | Medium |
| **Video Call** | High | Very High | High |
| **Government ID** | High | Very High | Low |

**Godot Implementation:**
- For Choyce Engine (family-focused, offline-capable): **Email verification** is sufficient
- Use backend service or self-hosted verification

**Key Resources:**
- **[COPPA Compliance 2025 Guide](https://blog.promise.legal/startup-central/coppa-compliance-in-2025-a-practical-guide-for-tech-edtech-and-kids-apps/)** - Practical guide
- **[FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/children-s-online-privacy-protection-rule)** - Official regulation
- **[Godot Privacy Policy](https://godotengine.org/privacy-policy/)** - Engine-level commitments

### 3. Audit Events & Event Sourcing

**Event Sourcing Pattern:**
- All state changes stored as immutable events
- State can be reconstructed by replaying events
- Enables audit, debug, rollback

**Godot Implementation:**
```gdscript
# Event Sourcing in GDScript
var _event_log: Array[Dictionary] = []

func apply_command(command: Dictionary) -> void:
    # Capture previous state
    var event = {
        "event_id": generate_uuid(),
        "timestamp": Time.get_unix_time_from_system(),
        "event_type": command["type"],
        "actor": command["actor"],
        "previous_state": capture_state(),
        "new_state": command["new_state"],
        "provenance": capture_provenance()
    }
    _event_log.append(event)
    
    # Apply to current state
    apply_state_change(command)
    
    # Emit for real-time listeners
    EventBus.emit_signal("state_changed", event)

func rollback_to(event_id: String) -> bool:
    # Find index of event
    var index = _find_event_index(event_id)
    if index == -1:
        return false
    
    # Clear all events after this one
    _event_log.resize(index + 1)
    
    # Reconstruct state from scratch
    _reset_state()
    for event in _event_log:
        apply_state_change(event)
    
    return true
```

**Key Resources:**
- **[Godot Rollback Netcode](https://godotengine.org/asset-library/asset/2450)** - State saving/loading for rollback
- **[Event Sourcing vs Audit Log](https://www.kurrent.io/blog/event-sourcing-audit)** - Pattern comparison
- **[Snopek Games Rollback Tutorial](https://www.snopekgames.com/course/rollback-netcode-godot/)** - Godot-specific implementation

### 4. Cancellable Async Operations

**Challenge:** Godot 4 does not natively support cancelling `await`

**Solution:** Manual cancellation flag + cleanup

**Key Resources:**
- **[Godot Proposal: Cancelable Coroutines](https://github.com/godotengine/godot-proposals/issues/8838)** - Feature request
- **[DEV: Await Keyword Guide](https://dev.to/ziva/gdscripts-await-keyword-is-the-underused-way-to-kill-callback-hell-in-godot-1oei)** - Best practices
- **[Godot Forum: Cancel Await](https://forum.godotengine.org/t/is-there-a-best-way-to-cancel-an-await/104392)** - Community discussion

### 5. Local Ollama Integration for Moderation

**Recommended Safety Models:**
- **`granite3-guardian:2b`** - Guardrail model by IBM, optimized for safety
- **`shieldgemma:2b`** - Safety-focused variant of Gemma
- **`llama3.2-vision:11b`** - Multimodal with safety filtering
- **`qwen2.5-coder:7b`** - Code-focused with safety layers

**Ollama Setup:**
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull safety model
ollama pull granite3-guardian:2b

# Start server
ollama serve
```

**Moderation Prompt:**
```text
You are a content safety classifier. Respond ONLY with "SAFE" or "UNSAFE".

Classify the following content as SAFE or UNSAFE:
- UNSAFE if it contains: violence, hate speech, sexual content, self-harm, illegal activity, personal data, or profanity
- SAFE otherwise

Content: {user_input}

Response:
```

**Godot Integration:**
```gdscript
func moderate_with_ollama(content: String) -> String:
    var http = HTTPRequest.new()
    add_child(http)
    
    var payload = {
        "model": "granite3-guardian:2b",
        "prompt": MODERATION_PROMPT.replace("{user_input}", content),
        "stream": false
    }
    
    var error = http.request("http://localhost:11434/api/generate", ["Content-Type: application/json"], true, HTTPClient.METHOD_POST, JSON.stringify(payload))
    if error != OK:
        return "ERROR"
    
    await http.request_completed
    var response = http.get_response_body_string()
    var json = JSON.parse(response)
    
    if json.result == OK:
        var result = json.data["response"]
        # Extract first word (SAFE or UNSAFE)
        return result.strip_edges().split("\n")[0].strip_edges().to_upper()
    
    return "ERROR"
```

**Key Resources:**
- **[Haystack: AI Guardrails](https://haystack.deepset.ai/cookbook/safety_moderation_open_lms)** - Moderation cookbook
- **[Gopilot Utils](https://godotengine.org/asset-library/asset/3504)** - Godot AI plugin
- **[Markaicode: Godot AI Integration](https://markaicode.com/godot-gdscript-ai-integration/)** - 20-minute tutorial
- **[DEV: Godot + Ollama Journey](https://web.lumintu.workers.dev/ykbmck/running-local-llms-in-game-engines-heres-my-journey-with-godot-ollama-4hhd)** - Integration guide

---

## Technical Deep Dive

### 1. Moderation Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      AI Request Pipeline                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │  User    │───▶│ Input    │───▶│  LLM     │───▶│ Output   │  │
│  │  Input   │    │ Moderator│    │  Engine  │    │ Moderator│  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘  │
│                       │              │              │              │
│                       ▼              ▼              ▼              ▼
│                 ┌──────────────────────────────────────────┐    │
│                 │           Audit Event Log                   │    │
│                 │  {timestamp, actor, input, output, result}   │    │
│                 └──────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Input Moderator Implementation

```gdscript
# input_moderator.gd
class_name InputModerator
extends Node

enum ModerationResult {
    SAFE,
    UNSAFE,
    NEEDS_REVIEW,
    ERROR
}

signal moderation_complete(result: ModerationResult, input: String, details: Dictionary)

@export var use_ollama: bool = true
@export var ollama_url: String = "http://localhost:11434/api/generate"
@export var ollama_model: String = "granite3-guardian:2b"
@export var fallback_to_rules: bool = true

var _keyword_filters: Array[String] = [
    # Violence
    "kill", "murder", "die", "blood", "weapon", "gun", "knife",
    # Hate speech
    "hate", "racist", "sexist", "homophobic",
    # Sexual content
    "sex", "porn", "nude", "fuck", "shit",
    # Self-harm
    "suicide", "cut myself", "hurt myself",
    # Personal data
    "password", "credit card", "ssn", "address",
]

func moderate(input: String, age_band: AgeBand) -> ModerationResult:
    # Step 1: Keyword filter (fast)
    var keyword_result := _check_keywords(input)
    if keyword_result != ModerationResult.SAFE:
        emit_signal("moderation_complete", keyword_result, input, {"method": "keyword"})
        return keyword_result
    
    # Step 2: Ollama moderation (if enabled)
    if use_ollama:
        var ollama_result := _moderate_with_ollama(input)
        if ollama_result != ModerationResult.ERROR:
            emit_signal("moderation_complete", ollama_result, input, {"method": "ollama"})
            return ollama_result
    
    # Step 3: Fallback to keyword only
    if fallback_to_rules:
        emit_signal("moderation_complete", keyword_result, input, {"method": "fallback"})
        return keyword_result
    
    emit_signal("moderation_complete", ModerationResult.ERROR, input, {"method": "none"})
    return ModerationResult.ERROR

func _check_keywords(input: String) -> ModerationResult:
    var lower_input = input.to_lower()
    for keyword in _keyword_filters:
        if lower_input.contains(keyword):
            return ModerationResult.UNSAFE
    return ModerationResult.SAFE

func _moderate_with_ollama(input: String) -> ModerationResult:
    var http = HTTPRequest.new()
    add_child(http)
    defer http.queue_free()
    
    var prompt = _build_moderation_prompt(input)
    var payload = {
        "model": ollama_model,
        "prompt": prompt,
        "stream": false,
        "options": {"temperature": 0.0, "num_predict": 10}
    }
    
    var headers = ["Content-Type: application/json"]
    var error = http.request(ollama_url, headers, true, HTTPClient.METHOD_POST, JSON.stringify(payload))
    
    if error != OK:
        return ModerationResult.ERROR
    
    # Set timeout
    var timeout = await _wait_with_timeout(http.request_completed, 5.0)
    
    if timeout:
        http.abort_request()
        return ModerationResult.ERROR
    
    if http.request_result != HTTPRequest.RESULT_SUCCESS:
        return ModerationResult.ERROR
    
    var response = http.get_response_body_string()
    var json = JSON.new()
    var parse_result = json.parse(response)
    
    if parse_result != OK:
        return ModerationResult.ERROR
    
    var result_text = json.data.get("response", "").strip_edges().to_upper()
    
    if result_text == "SAFE":
        return ModerationResult.SAFE
    elif result_text == "UNSAFE":
        return ModerationResult.UNSAFE
    else:
        return ModerationResult.NEEDS_REVIEW

func _build_moderation_prompt(input: String) -> String:
    return """
You are a content safety classifier for a children's game (age 6-12).
Respond ONLY with the word "SAFE" or "UNSAFE".

Classify the following content:
- UNSAFE if: violence, hate speech, sexual content, self-harm, illegal activity, personal data, profanity
- SAFE otherwise

Content: %s

Response:
""" % [input.replace("\n", " ").replace('"', "")]

func _wait_with_timeout(signal: Signal, timeout_seconds: float) -> bool:
    var timer = get_tree().create_timer(timeout_seconds)
    var timed_out = false
    
    signal.connect(_on_signal_completed.bind(timer))
    timer.timeout.connect(_on_timeout.bind(timer))
    
    await signal
    await timer.timeout
    
    return timed_out

func _on_signal_completed(timer: Timer):
    timer.queue_free()

func _on_timeout(timer: Timer):
    timed_out = true
```

### 3. Output Moderator Implementation

```gdscript
# output_moderator.gd
class_name OutputModerator
extends Node

# Similar structure to InputModerator but with additional checks

enum OutputCheck {
    TEXT,
    IMAGE,
    AUDIO,
    CODE
}

func moderate_output(content: Variant, content_type: OutputCheck, age_band: AgeBand) -> ModerationResult:
    match content_type:
        OutputCheck.TEXT:
            return _moderate_text(content as String, age_band)
        OutputCheck.IMAGE:
            return _moderate_image(content as Texture2D, age_band)
        OutputCheck.CODE:
            return _moderate_code(content as String, age_band)
    return ModerationResult.ERROR

func _moderate_text(text: String, age_band: AgeBand) -> ModerationResult:
    # Check for unsafe content
    var keyword_result := _check_keywords(text)
    if keyword_result != ModerationResult.SAFE:
        return keyword_result
    
    # Check for age-appropriateness
    if not _is_age_appropriate(text, age_band):
        return ModerationResult.UNSAFE
    
    return ModerationResult.SAFE

func _is_age_appropriate(text: String, age_band: AgeBand) -> bool:
    # Age-specific filters
    if age_band == AgeBand.CHILD_6_8:
        # Stricter filters for younger children
        var restricted = ["scary", "monster", "ghost", "dark", "blood"]
        for word in restricted:
            if text.to_lower().contains(word):
                return false
    
    return true
```

### 4. Parent Approval Service

```gdscript
# parent_approval_service.gd
class_name ParentApprovalService
extends Node

signal approval_requested(request_id: String, details: Dictionary)
signal approval_granted(request_id: String)
signal approval_denied(request_id: String)
signal approval_expired(request_id: String)

@export var approval_timeout: float = 300.0  # 5 minutes

var _pending_requests: Dictionary = {}

func request_approval(actor: PlayerProfile, action: String, details: Dictionary) -> String:
    # Generate unique request ID
    var request_id = _generate_request_id()
    
    # Check if actor is parent
    if actor.is_parent:
        # Auto-approve for parents
        _pending_requests[request_id] = {
            "status": "approved",
            "actor": actor.profile_id,
            "action": action,
            "details": details,
            "timestamp": Time.get_unix_time_from_system(),
            "approved_by": actor.profile_id,
            "approved_at": Time.get_unix_time_from_system()
        }
        approval_granted.emit(request_id)
        return request_id
    
    # For children, require parent approval
    _pending_requests[request_id] = {
        "status": "pending",
        "actor": actor.profile_id,
        "action": action,
        "details": details,
        "timestamp": Time.get_unix_time_from_system(),
        "parent_id": actor.parent_profile_id
    }
    
    # Notify parent
    approval_requested.emit(request_id, details)
    
    # Start timeout timer
    var timer = get_tree().create_timer(approval_timeout)
    timer.timeout.connect(_on_approval_timeout.bind(request_id))
    _pending_requests[request_id]["timer"] = timer
    
    return request_id

func approve(request_id: String, parent_profile: PlayerProfile) -> bool:
    if not _pending_requests.has(request_id):
        return false
    
    var request = _pending_requests[request_id]
    
    # Verify parent is authorized
    if request["parent_id"] != parent_profile.profile_id:
        return false
    
    # Only approve pending requests
    if request["status"] != "pending":
        return false
    
    # Update request
    request["status"] = "approved"
    request["approved_by"] = parent_profile.profile_id
    request["approved_at"] = Time.get_unix_time_from_system()
    
    # Clear timeout timer
    if request.has("timer"):
        request["timer"].queue_free()
        request.erase("timer")
    
    approval_granted.emit(request_id)
    return true

func deny(request_id: String, parent_profile: PlayerProfile, reason: String = "") -> bool:
    if not _pending_requests.has(request_id):
        return false
    
    var request = _pending_requests[request_id]
    
    if request["parent_id"] != parent_profile.profile_id:
        return false
    
    if request["status"] != "pending":
        return false
    
    request["status"] = "denied"
    request["denied_by"] = parent_profile.profile_id
    request["denied_at"] = Time.get_unix_time_from_system()
    request["deny_reason"] = reason
    
    if request.has("timer"):
        request["timer"].queue_free()
        request.erase("timer")
    
    approval_denied.emit(request_id)
    return true

func _on_approval_timeout(request_id: String) -> void:
    if _pending_requests.has(request_id):
        var request = _pending_requests[request_id]
        if request["status"] == "pending":
            request["status"] = "expired"
            approval_expired.emit(request_id)

func is_approved(request_id: String) -> bool:
    return _pending_requests.get(request_id, {}).get("status", "") == "approved"

func get_request_status(request_id: String) -> String:
    return _pending_requests.get(request_id, {}).get("status", "unknown")
```

### 5. Cancellable Async HTTP Client

```gdscript
# async_http_client.gd
class_name AsyncHTTPClient
extends Node

signal request_complete(success: bool, response: Dictionary)
signal request_failed(error: String)

var _http: HTTPRequest
var _cancelled: bool = false
var _timeout_timer: Timer

func _ready() -> void:
    _http = HTTPRequest.new()
    add_child(_http)
    _http.request_completed.connect(_on_request_completed)

func request(url: String, method: int = HTTPClient.METHOD_GET, headers: Array = [], body: String = "", timeout: float = 10.0) -> String:
    _cancelled = false
    
    # Clean up previous timer
    if _timeout_timer:
        _timeout_timer.queue_free()
    
    var request_id = _generate_id()
    
    # Set up timeout
    _timeout_timer = get_tree().create_timer(timeout)
    _timeout_timer.timeout.connect(_on_timeout.bind(request_id))
    
    var error = _http.request(url, headers, true, method, body)
    
    if error != OK:
        push_error("HTTP request failed: %s" % [HTTPClient.get_error_name(error)])
        request_failed.emit("Request setup error: %s" % HTTPClient.get_error_name(error))
        return request_id
    
    return request_id

func cancel() -> void:
    _cancelled = true
    if _timeout_timer:
        _timeout_timer.queue_free()
        _timeout_timer = null
    if _http:
        _http.abort_request()

func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
    if _cancelled:
        return
    
    if _timeout_timer:
        _timeout_timer.queue_free()
        _timeout_timer = null
    
    if result != HTTPRequest.RESULT_SUCCESS:
        request_failed.emit("Request failed: %s" % HTTPClient.get_error_name(result))
        return
    
    var response = {
        "code": response_code,
        "headers": headers,
        "body": body.get_string_from_utf8()
    }
    
    request_complete.emit(true, response)

func _on_timeout(request_id: String) -> void:
    if _cancelled:
        return
    
    _http.abort_request()
    request_failed.emit("Request timed out after %s seconds" % str(_timeout_timer.wait_time))

func _generate_id() -> String:
    return "req_%s_%s" % [Time.get_unix_time_from_system(), randi()]
```

### 6. Audit Event System

```gdscript
# audit_event_system.gd
class_name AuditEventSystem
extends Node

signal event_recorded(event: Dictionary)

@export var log_file: String = "user://audit_log.jsonl"
@export var max_events: int = 10000  # Rotate after this many events

var _event_count: int = 0
var _event_log: Array = []

func record_event(event: Dictionary) -> String:
    # Add metadata
    event["event_id"] = _generate_event_id()
    event["timestamp"] = Time.get_unix_time_from_system()
    event["session_id"] = get_tree().get_meta("session_id", "unknown")
    
    # Store in memory
    _event_log.append(event)
    _event_count += 1
    
    # Write to disk
    _write_to_disk(event)
    
    # Rotate if needed
    if _event_count >= max_events:
        _rotate_log()
    
    event_recorded.emit(event)
    return event["event_id"]

func _write_to_disk(event: Dictionary) -> void:
    var file = FileAccess.open(log_file, FileAccess.WRITE)
    if file:
        file.store_line(JSON.stringify(event))
        file.close()

func _rotate_log() -> void:
    var backup_file = "%s.%s" % [log_file, Time.get_unix_time_from_system()]
    if FileAccess.file_exists(log_file):
        FileAccess.rename(log_file, backup_file)
    _event_count = 0

func query_events(filter: Dictionary = {}) -> Array:
    var results = []
    for event in _event_log:
        var match = true
        for key in filter:
            if event.get(key) != filter[key]:
                match = false
                break
        if match:
            results.append(event)
    return results

func replay_events_from(to_event_id: String) -> bool:
    # Find the event
    var index = -1
    for i in range(_event_log.size()):
        if _event_log[i]["event_id"] == to_event_id:
            index = i
            break
    
    if index == -1:
        return false
    
    # Reset state and replay
    EventBus.emit_signal("audit_replay_started")
    
    for i in range(0, index + 1):
        var event = _event_log[i]
        # Emit replay event
        EventBus.emit_signal("audit_event_replay", event)
    
    EventBus.emit_signal("audit_replay_completed", to_event_id)
    return true
```

---

## Code Samples & Patterns

### 1. Complete AI Request Pipeline

```gdscript
# ai_request_pipeline.gd
class_name AIRequestPipeline
extends Node

@export var input_moderator: InputModerator
@export var output_moderator: OutputModerator
@export var parent_approval: ParentApprovalService
@export var audit_system: AuditEventSystem

signal request_started(request_id: String)
signal request_completed(request_id: String, result: Dictionary)
signal request_failed(request_id: String, error: String)

func process_request(actor: PlayerProfile, intent: String, context: Dictionary = {}) -> String:
    var request_id = _generate_request_id()
    
    # Step 1: Input moderation
    request_started.emit(request_id)
    audit_system.record_event({
        "type": "ai_request_started",
        "request_id": request_id,
        "actor": actor.profile_id,
        "intent": intent,
        "context": context
    })
    
    var input_result = input_moderator.moderate(intent, actor.age_band)
    
    if input_result == InputModerator.ModerationResult.UNSAFE:
        audit_system.record_event({
            "type": "ai_request_blocked_input",
            "request_id": request_id,
            "reason": "input_moderation_failed"
        })
        request_failed.emit(request_id, "Input moderation failed")
        return request_id
    
    # Step 2: Check if approval needed
    if _requires_approval(intent, actor):
        var approval_id = parent_approval.request_approval(actor, intent, context)
        
        # Wait for approval
        var approved = await _wait_for_approval(approval_id, 30.0)
        
        if not approved:
            audit_system.record_event({
                "type": "ai_request_denied",
                "request_id": request_id,
                "reason": "parent_approval_denied_or_timeout"
            })
            request_failed.emit(request_id, "Parent approval denied or timed out")
            return request_id
        
        audit_system.record_event({
            "type": "ai_request_approved",
            "request_id": request_id,
            "approval_id": approval_id
        })
    
    # Step 3: Send to LLM
    var llm_result = await _call_llm(intent, context, actor)
    
    if llm_result["error"]:
        audit_system.record_event({
            "type": "ai_request_llm_error",
            "request_id": request_id,
            "error": llm_result["error"]
        })
        request_failed.emit(request_id, llm_result["error"])
        return request_id
    
    # Step 4: Output moderation
    var output_result = output_moderator.moderate_output(
        llm_result["response"],
        OutputModerator.OutputCheck.TEXT,
        actor.age_band
    )
    
    if output_result == OutputModerator.ModerationResult.UNSAFE:
        audit_system.record_event({
            "type": "ai_request_blocked_output",
            "request_id": request_id,
            "reason": "output_moderation_failed"
        })
        request_failed.emit(request_id, "Output moderation failed")
        return request_id
    
    # Step 5: Complete
    audit_system.record_event({
        "type": "ai_request_completed",
        "request_id": request_id,
        "response": llm_result["response"]
    })
    
    request_completed.emit(request_id, llm_result)
    return request_id

func _requires_approval(intent: String, actor: PlayerProfile) -> bool:
    # High-impact actions require approval for children
    if actor.age_band == AgeBand.ADULT:
        return false
    
    var high_impact_actions = [
        "delete", "remove", "replace", "overwrite",
        "publish", "share", "export", "upload"
    ]
    
    for action in high_impact_actions:
        if intent.to_lower().contains(action):
            return true
    
    return false

func _call_llm(intent: String, context: Dictionary, actor: PlayerProfile) -> Dictionary:
    # Call appropriate LLM adapter based on configuration
    if Config.get("ai.use_ollama", true):
        return _call_ollama(intent, context)
    else:
        return _call_cloud_llm(intent, context)
```

### 2. Parent Consent UI Flow

```gdscript
# parent_consent_flow.gd
class_name ParentConsentFlow
extends Control

signal consent_granted
signal consent_denied
signal flow_cancelled

@onready var age_input = $AgeGate/AgeInput
@onready var age_submit = $AgeGate/SubmitButton
@onready var parent_email_input = $ParentConsent/EmailInput
@onready var parent_verify_button = $ParentConsent/SendVerification
@onready var verification_code_input = $Verification/CodeInput
@onready var verification_submit = $Verification/SubmitButton

@export var min_age_without_consent: int = 13
@export var verification_service: VerificationService

var _pending_verification: String = ""
var _request_id: String = ""

func _ready() -> void:
    age_submit.pressed.connect(_on_age_submit)
    parent_verify_button.pressed.connect(_on_send_verification)
    verification_submit.pressed.connect(_on_verify_code)

func show_age_gate() -> void:
    $AgeGate.visible = true
    $ParentConsent.visible = false
    $Verification.visible = false

func show_parent_consent() -> void:
    $AgeGate.visible = false
    $ParentConsent.visible = true
    $Verification.visible = false

func show_verification() -> void:
    $AgeGate.visible = false
    $ParentConsent.visible = false
    $Verification.visible = true

func _on_age_submit() -> void:
    var age = age_input.text.to_int()
    
    if age >= min_age_without_consent:
        # No consent needed
        consent_granted.emit()
        return
    
    # Show parent consent flow
    show_parent_consent()

func _on_send_verification() -> void:
    var email = parent_email_input.text
    
    if not _is_valid_email(email):
        _show_error("Please enter a valid email address")
        return
    
    # Request verification
    _request_id = verification_service.request_verification(email)
    _pending_verification = email
    
    show_verification()
    verification_code_input.text = ""
    verification_code_input.grab_focus()

func _on_verify_code() -> void:
    var code = verification_code_input.text
    
    if code.is_empty():
        _show_error("Please enter the verification code")
        return
    
    # Verify code
    var success = verification_service.verify_code(_request_id, code)
    
    if success:
        consent_granted.emit()
    else:
        _show_error("Invalid verification code")

func _is_valid_email(email: String) -> bool:
    # Simple email validation
    return email.contains("@") and email.contains(".")

func _show_error(message: String) -> void:
    # Show error to user
    print("Error: ", message)
    # In real implementation, show in UI
```

### 3. Offline Fallback System

```gdscript
# offline_fallback_system.gd
class_name OfflineFallbackSystem
extends Node

signal fallback_activated(reason: String)
signal online_restored()

@export var offline_mode_enabled: bool = true
@export var max_retry_attempts: int = 3
@export var retry_delay: float = 2.0

var _online: bool = true
var _retry_count: int = 0

func check_online() -> bool:
    return _online

func set_online(status: bool) -> void:
    if _online == status:
        return
    
    _online = status
    
    if _online:
        _retry_count = 0
        online_restored.emit()
    else:
        fallback_activated.emit("Network offline")

func handle_request(request_func: Callable) -> Variant:
    if _online:
        try:
            return request_func.call()
        except:
            # Network error
            set_online(false)
            return _get_fallback_response(request_func)
    else:
        return _get_fallback_response(request_func)

func async_handle_request(request_func: Callable) -> Variant:
    if _online:
        var retry_count = 0
        while retry_count < max_retry_attempts:
            try:
                return await request_func.call()
            except:
                retry_count += 1
                if retry_count < max_retry_attempts:
                    await get_tree().create_timer(retry_delay).timeout
        
        # All retries failed
        set_online(false)
        return _get_fallback_response(request_func)
    else:
        return _get_fallback_response(request_func)

func _get_fallback_response(request_func: Callable) -> Variant:
    # Analyze what was requested and provide appropriate fallback
    var request_name = request_func.get_function()
    
    if "moderate" in request_name:
        # Fallback: Allow with warning
        return {"result": "SAFE", "warning": "Offline mode - moderation limited"}
    
    elif "generate" in request_name or "create" in request_name:
        # Fallback: Use rule-based generation
        return _rule_based_generation()
    
    elif "translate" in request_name:
        # Fallback: No translation
        return {"translation": "[Translation unavailable offline]", "original": ""}
    
    else:
        # Generic fallback
        return null

func _rule_based_generation() -> Dictionary:
    # Simple rule-based content generation
    var templates = [
        "I'm sorry, I can't help with that right now. Try something else!",
        "That sounds interesting! What else would you like to do?",
        "Let's try a different activity."
    ]
    
    return {
        "response": templates[randi() % templates.size()],
        "is_fallback": true
    }
```

---

## Security & Compliance

### 1. SSL Certificate Verification

**Godot 4 Behavior:**
- HTTPRequest verifies SSL certificates by default
- Protects against man-in-the-middle attacks
- Uses system CA store or custom certificates

**Configuration:**
```
Project Settings > Network > SSL > Certificates:
- Add custom .crt files for self-signed certificates
- For Let's Encrypt: no configuration needed
- For development: can use self-signed but NOT for production
```

**Key Resources:**
- **[Godot SSL Documentation](https://docs.godotengine.org/en/stable/tutorials/networking/ssl_certificates.html)**
- **[GitHub Issue: SSL Verification](https://github.com/godotengine/godot/issues/99460)**

### 2. Data Protection

**Minimal Data Collection:**
- Only collect what's necessary for safety/audit
- Store locally by default
- Encrypt sensitive data
- Allow parent deletion

**Data Types:**

| Data Type | Collection | Storage | Deletion |
|-----------|-----------|---------|----------|
| Prompts | Yes (audit) | Local, encrypted | Parent can delete |
| Responses | Yes (audit) | Local, encrypted | Parent can delete |
| Moderation decisions | Yes (audit) | Local, encrypted | Parent can delete |
| Email (parent) | Only for consent | Hashed, server | On request |
| Child personal data | NEVER | N/A | N/A |

### 3. COPPA Compliance Checklist

- [ ] **Clear privacy policy** explaining data collection
- [ ] **Age gate** before data collection
- [ ] **Parental consent flow** for under-13 users
- [ ] **Verifiable parental consent** mechanism
- [ ] **Parental access** to child's data
- [ ] **Deletion mechanism** for parent-requested deletion
- [ ] **Data retention limits** (no indefinite storage)
- [ ] **No behavioral advertising** to children
- [ ] **Security measures** (encryption, access controls)
- [ ] **Staff training** on COPPA requirements

**Resources:**
- **[FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/children-s-online-privacy-protection-rule)**
- **[COPPA Compliance Template](https://termsbox.com/blog/coppa-kids-app-privacy-policy)**

### 4. GDPR Compliance (EU Users)

- [ ] **Lawful basis** for processing (consent)
- [ ] **Age of consent** (16 in most EU countries, 13 in some)
- [ ] **Parental consent** for under-age users
- [ ] **Data subject rights** implementation
- [ ] **Data protection officer** (if processing at scale)
- [ ] **Data breach notification** within 72 hours

---

## Learning Resources

### Godot-Specific Resources

#### AI & Moderation
1. **[Godot + Ollama Integration](https://web.lumintu.workers.dev/ykbmck/running-local-llms-in-game-engines-heres-my-journey-with-godot-ollama-4hhd)** - Local LLM guide
2. **[Gopilot Utils Plugin](https://godotengine.org/asset-library/asset/3504)** - AI integration helpers
3. **[Markaicode Tutorial](https://markaicode.com/godot-gdscript-ai-integration/)** - 20-minute AI setup
4. **[Haystack Moderation](https://haystack.deepset.ai/cookbook/safety_moderation_open_lms)** - Moderation patterns

#### HTTP & Networking
1. **[Godot HTTPRequest Docs](https://docs.godotengine.org/en/stable/tutorials/networking/http_request.html)** - Official guide
2. **[SSL Certificates](https://docs.godotengine.org/en/stable/tutorials/networking/ssl_certificates.html)** - Security setup
3. **[WebSocket Client](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html)** - Real-time communication

#### Safety & Compliance
1. **[FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/children-s-online-privacy-protection-rule)** - Official regulation
2. **[COPPA Compliance 2025](https://blog.promise.legal/startup-central/coppa-compliance-in-2025-a-practical-guide-for-tech-edtech-and-kids-apps/)** - Practical guide
3. **[Safe Child LLM Evaluation](https://github.com/The-Responsible-AI-Initiative/Safe_Child_LLM_Evaluation)** - Safety testing framework

#### Event Sourcing & State Management
1. **[Godot Rollback Netcode](https://godotengine.org/asset-library/asset/2450)** - State save/load for rollback
2. **[Event Sourcing vs Audit Log](https://www.kurrent.io/blog/event-sourcing-audit)** - Pattern comparison
3. **[Snopek Games Tutorial](https://www.snopekgames.com/course/rollback-netcode-godot/)** - Godot rollback implementation
4. **[GDQuest Event Bus](https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/)** - Event-driven architecture

---

## Implementation Checklist

### Phase 1: Input Moderation
- [ ] Create `InputModerator.gd` with keyword filtering
- [ ] Add Ollama integration for LLM-based moderation
- [ ] Implement age-band specific filters
- [ ] Add fallback to keyword-only mode
- [ ] Unit tests for moderation edge cases

### Phase 2: Output Moderation
- [ ] Create `OutputModerator.gd` for text/image/audio
- [ ] Implement content type-specific checks
- [ ] Add age-appropriateness filters
- [ ] Unit tests for output moderation

### Phase 3: Parent Approval System
- [ ] Create `ParentApprovalService.gd`
- [ ] Implement approval request/response workflow
- [ ] Add timeout handling
- [ ] Create parent consent UI flow
- [ ] Test with child and parent profiles

### Phase 4: Audit Event System
- [ ] Create `AuditEventSystem.gd`
- [ ] Implement event recording with metadata
- [ ] Add log rotation for disk storage
- [ ] Create query interface for events
- [ ] Implement replay capability

### Phase 5: Async HTTP Client
- [ ] Create `AsyncHTTPClient.gd`
- [ ] Implement timeout handling
- [ ] Add cancellation support
- [ ] SSL certificate verification
- [ ] Retry logic with exponential backoff

### Phase 6: AI Request Pipeline
- [ ] Create `AIRequestPipeline.gd`
- [ ] Integrate all components (moderation, approval, audit)
- [ ] Add fallback for offline mode
- [ ] Implement error handling and recovery
- [ ] Add performance monitoring

### Phase 7: COPPA Compliance
- [ ] Create age gate UI
- [ ] Implement parent consent flow
- [ ] Add privacy policy display
- [ ] Create parent data access/delete UI
- [ ] Document compliance measures

### Phase 8: Testing & Validation
- [ ] Unit tests for all moderation scenarios
- [ ] Integration tests for full pipeline
- [ ] Security audit of data flows
- [ ] Compliance review (COPPA, GDPR)
- [ ] Performance testing (100+ concurrent requests)

### Phase 9: Polish & Documentation
- [ ] Child-friendly error messages
- [ ] Parent dashboard for oversight
- [ ] Audit log viewer
- [ ] Configuration options (enable/disable features)
- [ ] Developer documentation

---

## Child-Safety Constraints

### Must Implement

1. **Default Deny:** All AI requests must fail-safe (deny if uncertain)
2. **Audit Everything:** All prompts, responses, decisions logged
3. **Parent Override:** Parents can view and delete child's AI interactions
4. **Offline Safety:** Moderation works in offline mode (rule-based fallback)
5. **Timeouts:** All network requests have timeouts (max 10 seconds)
6. **Cancellation:** Users can cancel pending AI requests

### Must Avoid

1. **No unmoderated AI output** to children
2. **No data collection** without explicit consent
3. **No bypass mechanisms** for safety checks
4. **No persistent storage** of child personal data
5. **No third-party sharing** of child data without parent consent

### Age-Specific Rules

| Age Band | Moderation Level | Features Allowed | Parental Consent Required |
|----------|-----------------|-----------------|---------------------------|
| CHILD_6_8 | Strict | Basic generation, filtered | YES for all AI features |
| CHILD_9_12 | Moderate | Most generation, strict moderation | YES for high-impact |
| TEEN_13_17 | Light | Full generation, light moderation | NO (but age gate required) |
| ADULT | Minimal | All features | NO |

---

## References

### Internal Files
- `src/application/request_ai_creation_help_service.gd` - Current AI service
- `src/application/approve_ai_patch_service.gd` - Current approval service
- `src/adapters/outbound/local_stt_adapter.gd` - Current STT adapter
- `PLAN.md` - Vertical slice requirements
- `.ai/tasks/backlog.yaml` - Task definitions
- `.codex/skills/ai-safety/references/policy-matrix.md` - Safety policies

### External Links

#### Godot Documentation
- [HTTPRequest](https://docs.godotengine.org/en/stable/tutorials/networking/http_request.html)
- [SSL Certificates](https://docs.godotengine.org/en/stable/tutorials/networking/ssl_certificates.html)
- [WebSocket](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html)
- [JSON Parsing](https://docs.godotengine.org/en/stable/classes/class_json.html)

#### AI & Moderation
- [Safe Child LLM Evaluation](https://github.com/The-Responsible-AI-Initiative/Safe_Child_LLM_Evaluation)
- [Haystack AI Guardrails](https://haystack.deepset.ai/cookbook/safety_moderation_open_lms)
- [Guardrailing LLMs](https://bhargavaparv.medium.com/guardrailing-large-language-models-llms-ensuring-safe-and-responsible-ai-a72791ea6a37)
- [Input/Output Filtering](https://blog.bluedot.org/p/input-output-filtering)

#### Ollama Integration
- [Ollama GitHub](https://github.com/ollama/ollama)
- [Ollama Models](https://ollama.com/library)
- [Godot + Ollama Guide](https://web.lumintu.workers.dev/ykbmck/running-local-llms-in-game-engines-heres-my-journey-with-godot-ollama-4hhd)
- [Gopilot Utils](https://godotengine.org/asset-library/asset/3504)

#### COPPA & GDPR Compliance
- [FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/children-s-online-privacy-protection-rule)
- [COPPA Compliance 2025](https://blog.promise.legal/startup-central/coppa-compliance-in-2025-a-practical-guide-for-tech-edtech-and-kids-apps/)
- [Godot Privacy Policy](https://godotengine.org/privacy-policy/)
- [COPPA Privacy Policy Template](https://termsbox.com/blog/coppa-kids-app-privacy-policy)

#### Event Sourcing & Rollback
- [Godot Rollback Netcode](https://godotengine.org/asset-library/asset/2450)
- [Event Sourcing vs Audit Log](https://www.kurrent.io/blog/event-sourcing-audit)
- [Snopek Games Rollback](https://www.snopekgames.com/course/rollback-netcode-godot/)
- [GDQuest Event Bus](https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/)

#### Async & Cancellation
- [Cancelable Coroutines Proposal](https://github.com/godotengine/godot-proposals/issues/8838)
- [Await Keyword Guide](https://dev.to/ziva/gdscripts-await-keyword-is-the-underused-way-to-kill-callback-hell-in-godot-1oei)
- [Godot Forum: Cancel Await](https://forum.godotengine.org/t/is-there-a-best-way-to-cancel-an-await/104392)

---

## Document Metadata

- **Created:** 2026-07-18
- **Author:** Mistral Vibe (Codex)
- **Project:** Choyce Engine
- **Branch:** fix/adventure-thin-slice-combat-first-run
- **Version:** 1.0
- **Size:** ~XX KB

---

*This research compendium is part of the Choyce Engine project. For questions or contributions, refer to the project's AGENTS.md and CONTRIBUTING.md files.*
