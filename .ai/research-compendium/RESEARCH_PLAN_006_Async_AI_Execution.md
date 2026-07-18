# RESEARCH_PLAN_006: Async AI Execution with Cancellation and Safety

**Source**: PLAN.md Gate 5 - "Replace synchronous AI tool shim with cancellable async execution"
**Title**: Asynchronous AI Tool Execution with Cancellation, Preview, and Safety Controls
**Specialty**: ai-integration, async-programming, safety-engineering
**Status**: todo
**Owner**: codex
**Complexity**: HIGH

---

## Table of Contents
1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research Summary](#online-research-summary)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Code Samples](#code-samples)
6. [Asset Packages and Tools](#asset-packages-and-tools)
7. [Learning Resources](#learning-resources)
8. [Implementation Checklist](#implementation-checklist)
9. [Child-Safety Constraints](#child-safety-constraints)
10. [References](#references)

---

## Task Overview

### Objective
Replace the current **synchronous AI tool shim** with a **cancellable, asynchronous execution system** that supports **preview**, **apply**, **undo** workflow, **parent approval gates** for high-impact changes, **input/output moderation**, **structured audit events**, and **safe rollback** on failure or cancellation.

### Acceptance Criteria (from PLAN.md Gate 5)
1. **Async Execution**: AI tools run asynchronously without blocking the main thread
2. **Cancellation Support**: AI operations can be cancelled at any time
3. **Preview Mode**: Show AI-generated changes before applying
4. **Apply/Undo**: Atomic apply and undo operations
5. **Parent Approval**: High-impact changes require parent approval
6. **Input/Output Moderation**: Filter unsafe inputs and outputs
7. **Structured Audit**: All AI operations are logged
8. **Safe Rollback**: System returns to safe state on error/cancellation

### Key Requirements
- **Non-Blocking**: No UI freezes during AI operations
- **Deterministic**: Same inputs produce same outputs
- **Reversible**: All AI changes can be undone
- **Safe by Default**: AI operates in safe mode for children
- **Parent Control**: Parents have full control over AI features
- **Audit Trail**: Complete history of AI operations
- **Error Handling**: Graceful degradation on errors

---

## Current Implementation Analysis

### Existing Infrastructure
From the codebase:
- `src/adapters/outbound/ollama_tool_adapter.gd` - Current synchronous shim
- `src/ports/outbound/ai_tool_port.gd` - AI tool interface
- `src/domain/ai/` - AI domain types (likely exists)
- VS-009: Governed AI Flows (RESEARCH_VS-009_Governed_AI_Flows.md)
- VS-007: Tauri Sidecar (RESEARCH_VS-007_Tauri_Sidecar_Part1-3.md)
- `.ai/tasks/backlog.yaml` - Task definitions

### Current Synchronous Shim Problem
```gdscript
# Current synchronous shim (PROBLEMATIC)
func execute_tool(tool: String, args: Dictionary) -> Dictionary:
    # BLOCKS the main thread
    var start_time = Time.get_unix_time_from_system()
    var result = call_ollama(tool, args)  # Can take 5-30+ seconds
    var end_time = Time.get_unix_time_from_system()
    
    # If this takes too long, UI freezes
    # No way to cancel
    # No preview before apply
    # No parent approval
    
    return result
```

### Required Async Architecture
```
┌─────────────────────────────────────────────────────────┐
│                   Godot Engine                            │
│  ┌─────────────────────────────────────────────────────┐│
│  │              AI Execution Manager                    ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ││
│  │  │ AI Tool      │  │ Async        │  │ Preview      │  ││
│  │  │  Registry    │  │  Executor    │  │  Manager     │  ││
│  │  └─────────────┘  └────────┬────────┘  └──────────┘  ││
│  │                              │                        ││
│  └──────────────────────────────────────┼───────────────┘│
│                                      │                     │
│                                     ▼                     │
│  ┌─────────────────────────────────────────────────────┐│
│  │              Tauri Shell (Rust)                     ││
│  │  ┌───────────────────────────────────────────────┐  ││
│  │  │              AI Service                       │  ││
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │  ││
│  │  │  │ Async Task   │  │ Cancellation  │  │  Result  │  │  ││
│  │  │  │   Queue      │──▶│   Token      │──▶│  Cache   │  │  ││
│  │  │  └─────────────┘  └─────────────┘  └─────────┘  │  ││
│  │  └───────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Responsibility | Location |
|-----------|---------------|----------|
| AIToolRegistry | Register and discover AI tools | `src/domain/ai/` |
| AsyncExecutor | Execute AI tools asynchronously | `src/adapters/outbound/` |
| PreviewManager | Manage preview/apply/undo workflow | `src/adapters/outbound/` |
| SafetyFilter | Input/output moderation | `src/domain/safety/` |
| AuditLogger | Structured audit event logging | `src/domain/audit/` |
| ApprovalGate | Parent approval for high-impact | `src/domain/safety/` |
| Cancellation | Cancel running AI operations | `src/domain/ai/` |

---

## Online Research Summary

### 1. Async Patterns in Godot

**Godot 4.x Async Options**:

| Method | Description | Use Case | Threading |
|--------|-------------|----------|-----------|
| `await` | Async/await syntax | Simple async | Main thread |
| `yield()` | Coroutine yield | Cooperative multitasking | Main thread |
| `OS.execute_string()` | Shell command | External processes | Separate process |
| `Thread` | Godot Thread class | CPU-bound work | Separate thread |
| Tauri IPC | Tauri command | Heavy computation | Shell process |
| `HTTPRequest` | Async HTTP | Network calls | Network thread |

**Recommended Approach**: **Tauri IPC + Godot Thread**
- CPU-heavy AI: Tauri Rust (separate process)
- Network AI: Tauri or Godot HTTPRequest
- Light processing: Godot Thread

**Godot await Example**:
```gdscript
func async_operation():
    var result
    var task = start_async_task()
    
    # Yield until task completes
    yield(task, "completed")
    result = task.result
    
    # Or with timeout
    var timeout = 10.0  # seconds
    var start = Time.get_unix_time_from_system()
    while task.is_active():
        yield(get_tree().create_timer(0.1), "timeout")
        if Time.get_unix_time_from_system() - start > timeout:
            task.cancel()
            return ERROR_TIMEOUT
    
    return task.result
```

**Godot Thread Example**:
```gdscript
func _ready():
    var thread = Thread.new()
    thread.start(Callable(self, "_thread_function"))

func _thread_function(userdata: Variant):
    # Run in background thread
    var result = heavy_computation()
    
    # Return result (will be emitted as signal)
    return result

func _on_thread_completed(result: Variant):
    # Handle result on main thread
    process_result(result)
```

### 2. Asynchronous Patterns

**Future/Promise Pattern**:
```gdscript
# Promise.gd - Simple promise implementation
class_name Promise

signal completed(result: Variant)
signal failed(error: Variant)

var is_pending: bool = true
var is_fulfilled: bool = false
var is_rejected: bool = false
var result: Variant
var error: Variant

func _init(executor: Callable):
    # Start async operation
    var thread = Thread.new()
    thread.start(executor)
    thread.connect("thread_exited", Callable(self, "_on_thread_exited"))

func _on_thread_exited(result: Variant):
    if result is Array and result.size() >= 2:
        var success = result[0]
        var data = result[1]
        if success:
            is_fulfilled = true
            is_pending = false
            completed.emit(data)
        else:
            is_rejected = true
            is_pending = false
            failed.emit(data)
    else:
        is_fulfilled = true
        is_pending = false
        completed.emit(result)

func then(callback: Callable) -> Promise:
    var new_promise = Promise.new(Callable(self, "_noop"))
    connect("completed", callback)
    return new_promise

func catch(callback: Callable) -> Promise:
    connect("failed", callback)
    return self

func finally(callback: Callable) -> Promise:
    connect("completed", callback)
    connect("failed", callback)
    return self
```

**Cancellation Token Pattern**:
```gdscript
# CancellationToken.gd
class_name CancellationToken

var is_cancelled: bool = false
var on_cancel: Callable

func cancel():
    is_cancelled = true
    if on_cancel:
        on_cancel.call()

func throw_if_cancelled():
    if is_cancelled:
        push_error("Operation cancelled")
        return true
    return false
```

**Async/Await with Cancellation**:
```gdscript
func async_with_cancellation(cancellation_token: CancellationToken):
    var steps = [
        Callable(self, "step1"),
        Callable(self, "step2"),
        Callable(self, "step3")
    ]
    
    for step in steps:
        if cancellation_token.throw_if_cancelled():
            return
        
        var result = step.call()
        if result is Promise:
            yield(result, "completed")
            if cancellation_token.throw_if_cancelled():
                return
    
    return "completed"
```

### 3. Rust Async for Tauri

**Rust Async Ecosystem**:

| Crate | Description | Stars | Async Runtime |
|-------|-------------|-------|---------------|
| **tokio** | Async runtime | 18k | Tokio |
| **async-std** | Async std lib | 4k | async-std |
| **futures** | Future combinators | 7k | Any |
| **reqwest** | Async HTTP | 15k | Tokio/async-std |
| **tauri-plugin-async** | Tauri async plugin | [tauri-async](https://github.com/tauri-apps/plugins/workflows/async) | Any |

**Tokio Example**:
```rust
use tokio::time::{sleep, Duration};

#[tauri::command]
async fn async_ai_tool(
    tool: String,
    args: serde_json::Value,
    state: tauri::State<'_, AppState>,
) -> Result<String, String> {
    // Spawn async task
    tokio::spawn(async move {
        // Do async work
        sleep(Duration::from_secs(1)).await;
        
        // Call AI tool
        let result = call_ai_tool(&tool, &args).await?;
        
        Ok(result)
    }).await?
}

async fn call_ai_tool(tool: &str, args: &serde_json::Value) -> Result<String, String> {
    // Make async HTTP request
    let client = reqwest::Client::new();
    let response = client
        .post("http://localhost:11434/api/generate")
        .json(&serde_json::json!({
            "model": "llama3",
            "prompt": format!("Tool: {}, Args: {}", tool, args),
            "stream": false
        }))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    
    response.text().await.map_err(|e| e.to_string())
}
```

**Cancellation in Rust**:
```rust
use tokio::sync::mpsc;
use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Debug)]
pub struct CancellableTask {
    cancel_tx: Option<mpsc::Sender<()>>,
}

impl CancellableTask {
    pub fn new<F, Fut>(future: F) -> Self
    where
        F: FnOnce(mpsc::Receiver<()>) -> Fut + Send + 'static,
        Fut: std::future::Future<Output = ()> + Send + 'static,
    {
        let (cancel_tx, cancel_rx) = mpsc::channel(1);
        
        tokio::spawn(async move {
            future(cancel_rx).await;
        });
        
        Self { cancel_tx: Some(cancel_tx) }
    }
    
    pub fn cancel(&mut self) {
        if let Some(tx) = self.cancel_tx.take() {
            let _ = tx.send(()).await;
        }
    }
}

#[tauri::command]
async fn start_cancellable_task(
    tool: String,
    state: tauri::State<'_, Arc<Mutex<Vec<CancellableTask>>>>,
) -> Result<(), String> {
    let mut tasks = state.lock().await;
    
    let task = CancellableTask::new(move |cancel_rx| async move {
        // Check for cancellation periodically
        let mut rx = cancel_rx;
        for i in 0..10 {
            tokio::select! {
                _ = tokio::time::sleep(tokio::time::Duration::from_secs(1)) => {
                    // Do work
                }
                _ = rx.recv() => {
                    // Cancelled
                    return;
                }
            }
        }
    });
    
    tasks.push(task);
    Ok(())
}

#[tauri::command]
async fn cancel_all_tasks(
    state: tauri::State<'_, Arc<Mutex<Vec<CancellableTask>>>>,
) -> Result<(), String> {
    let mut tasks = state.lock().await;
    for task in tasks.iter_mut() {
        task.cancel();
    }
    tasks.clear();
    Ok(())
}
```

### 4. Preview/Apply/Undo Pattern

**Command Pattern**:
```gdscript
# AICommand.gd - Command pattern for AI operations
class_name AICommand

signal completed(result: Dictionary)
signal failed(error: String)
signal cancelled()

var name: String
var description: String
var can_undo: bool = true
var is_high_impact: bool = false

var state: String = "pending"
var result: Dictionary
var error: String
var undo_data: Dictionary

func execute():
    state = "executing"
    
    # Check if parent approval needed
    if is_high_impact and not has_parent_approval():
        request_parent_approval()
        return
    
    # Execute async
    var thread = Thread.new()
    thread.start(Callable(self, "_execute_async"))

func _execute_async():
    try:
        # Do the work
        result = _do_execute()
        
        # Create undo data
        undo_data = _create_undo_data(result)
        
        state = "completed"
        completed.emit(result)
    except error as String:
        state = "failed"
        self.error = error
        failed.emit(error)

func _do_execute() -> Dictionary:
    # Override in subclasses
    return {}

func _create_undo_data(result: Dictionary) -> Dictionary:
    # Override in subclasses
    return {}

func undo():
    if not can_undo:
        return FAILED
    
    if state != "completed":
        return FAILED
    
    # Apply undo
    _do_undo(undo_data)
    state = "undone"
    undo_data.clear()
    return OK

func _do_undo(undo_data: Dictionary):
    # Override in subclasses
    pass

func cancel():
    if state == "executing":
        state = "cancelled"
        cancelled.emit()

func request_parent_approval():
    var approval_service = ApprovalService.get_singleton()
    approval_service.request_approval(
        self,
        name,
        description,
        Callable(self, "on_approval_granted"),
        Callable(self, "on_approval_denied")
    )

func on_approval_granted():
    execute()

func on_approval_denied():
    state = "denied"
    error = "Parent approval denied"
    failed.emit(error)

func has_parent_approval() -> bool:
    var approval_service = ApprovalService.get_singleton()
    return approval_service.has_approval(name)
```

**Preview Manager**:
```gdscript
# PreviewManager.gd - Manage preview/apply/undo workflow
class_name PreviewManager
export var approval_gate: ApprovalGate

var pending_commands: Array = []
var active_preview: AICommand = null
var history: Array = []
var max_history: int = 100

func preview_command(command: AICommand):
    # Cancel any active preview
    if active_preview:
        active_preview.cancel()
    
    # Start preview
    active_preview = command
    command.connect("completed", Callable(self, "_on_preview_completed"))
    command.connect("failed", Callable(self, "_on_preview_failed"))
    command.connect("cancelled", Callable(self, "_on_preview_cancelled"))
    
    command.execute()

func _on_preview_completed(result: Dictionary):
    # Show preview to user
    show_preview(result)

func _on_preview_failed(error: String):
    show_error(error)
    active_preview = null

func _on_preview_cancelled():
    active_preview = null

func apply_preview():
    if active_preview and active_preview.state == "completed":
        # Apply the changes
        apply_changes(active_preview.result)
        
        # Add to history
        history.push_front({
            "command": active_preview,
            "timestamp": Time.get_unix_time_from_system(),
            "result": active_preview.result
        })
        
        # Trim history
        if history.size() > max_history:
            history.pop_back()
        
        active_preview = null

func undo_last():
    if history.size() > 0:
        var last = history[0]
        last.command.undo()
        history.pop_front()

func undo_all():
    while history.size() > 0:
        undo_last()

func show_preview(result: Dictionary):
    # Display preview UI
    var preview_dialog = PreviewDialog.new()
    preview_dialog.result = result
    preview_dialog.connect("apply", Callable(self, "apply_preview"))
    preview_dialog.connect("cancel", Callable(self, "cancel_preview"))
    get_tree().root.add_child(preview_dialog)

func cancel_preview():
    if active_preview:
        active_preview.cancel()
        active_preview = null
```

### 5. Input/Output Moderation

**Safety Filter Pipeline**:
```gdscript
# SafetyPipeline.gd - Input/output moderation pipeline
class_name SafetyPipeline

@export var input_filters: Array = []
@export var output_filters: Array = []

var audit_logger: AuditLogger

func _init():
    audit_logger = AuditLogger.get_singleton()
    
    # Add default filters
    input_filters.append(ProfanityFilter.new())
    input_filters.append(SensitiveTopicFilter.new())
    input_filters.append(LengthFilter.new(2048))
    
    output_filters.append(ProfanityFilter.new())
    output_filters.append(SafetyFilter.new())
    output_filters.append(HateSpeechFilter.new())

func filter_input(input: Dictionary) -> Dictionary:
    var filtered = input.duplicate()
    
    for filter in input_filters:
        filtered = filter.filter(filtered)
        if filtered == null:
            # Input rejected
            audit_logger.log_rejection("input", input, filter.name)
            return null
    
    audit_logger.log_input(input, filtered)
    return filtered

func filter_output(output: Dictionary) -> Dictionary:
    var filtered = output.duplicate()
    
    for filter in output_filters:
        filtered = filter.filter(filtered)
        if filtered == null:
            # Output rejected
            audit_logger.log_rejection("output", output, filter.name)
            return null
    
    audit_logger.log_output(output, filtered)
    return filtered

func validate_ai_prompt(prompt: String) -> bool:
    # Check prompt safety
    var filters = [
        ProfanityFilter.new(),
        SensitiveTopicFilter.new(),
        LengthFilter.new(500),
        PersonalInfoFilter.new()
    ]
    
    for filter in filters:
        if not filter.is_valid(prompt):
            audit_logger.log_rejection("prompt", {"prompt": prompt}, filter.name)
            return false
    
    return true

func sanitize_ai_response(response: String) -> String:
    # Sanitize AI response
    var sanitized = response
    
    # Remove code execution attempts
    sanitized = sanitized.replace("```", "")
    sanitized = sanitized.replace("$", "")
    sanitized = sanitized.replace(";", ",")
    
    # Apply filters
    for filter in output_filters:
        if filter is StringFilter:
            sanitized = filter.filter_string(sanitized)
    
    return sanitized
```

### 6. Structured Audit Logging

**Audit Event Types**:
```gdscript
# AuditEvent.gd
class_name AuditEvent

@export_enum(
    "AI_EXECUTION_STARTED",
    "AI_EXECUTION_COMPLETED",
    "AI_EXECUTION_FAILED",
    "AI_EXECUTION_CANCELLED",
    "INPUT_ACCEPTED",
    "INPUT_REJECTED",
    "OUTPUT_ACCEPTED",
    "OUTPUT_REJECTED",
    "PARENT_APPROVAL_REQUESTED",
    "PARENT_APPROVAL_GRANTED",
    "PARENT_APPROVAL_DENIED",
    "UNDO_PERFORMED",
    "PREVIEW_SHOWN",
    "PREVIEW_APPLIED"
)
enum EventType {
    AI_EXECUTION_STARTED,
    AI_EXECUTION_COMPLETED,
    AI_EXECUTION_FAILED,
    AI_EXECUTION_CANCELLED,
    INPUT_ACCEPTED,
    INPUT_REJECTED,
    OUTPUT_ACCEPTED,
    OUTPUT_REJECTED,
    PARENT_APPROVAL_REQUESTED,
    PARENT_APPROVAL_GRANTED,
    PARENT_APPROVAL_DENIED,
    UNDO_PERFORMED,
    PREVIEW_SHOWN,
    PREVIEW_APPLIED
}

var timestamp: float
var event_type: EventType
var user_id: String
var session_id: String
var tool_name: String
var input_data: Dictionary
var output_data: Dictionary
var metadata: Dictionary
var ip_address: String
var device_info: Dictionary

func to_dict() -> Dictionary:
    return {
        "timestamp": timestamp,
        "event_type": event_type,
        "user_id": user_id,
        "session_id": session_id,
        "tool_name": tool_name,
        "input_data": input_data,
        "output_data": output_data,
        "metadata": metadata,
        "ip_address": ip_address,
        "device_info": device_info
    }
```

**Audit Logger**:
```gdscript
# AuditLogger.gd - Structured audit event logging
class_name AuditLogger

@export var log_path: String = "user://audit/ai_events.jsonl"
@export var max_file_size: int = 10 * 1024 * 1024  # 10MB
@export var max_files: int = 5

var log_queue: Array = []
var is_flushing: bool = false

func _ready():
    # Ensure log directory exists
    var dir = Directory.new()
    if not dir.dir_exists(log_path.get_base_dir()):
        dir.make_dir_recursive(log_path.get_base_dir())

func log_event(event: AuditEvent):
    # Add to queue
    log_queue.append(event)
    
    # Flush if queue is getting large
    if log_queue.size() >= 100:
        flush_queue()

func log_ai_execution(
    tool: String,
    input: Dictionary,
    output: Dictionary,
    duration: float,
    status: String
):
    var event = AuditEvent.new()
    event.timestamp = Time.get_unix_time_from_system()
    event.event_type = AuditEvent.EventType.AI_EXECUTION_COMPLETED
    event.tool_name = tool
    event.input_data = input
    event.output_data = output
    event.metadata = {
        "duration": duration,
        "status": status,
        "user_age_band": PlayerProfile.get_singleton().age_band
    }
    
    log_event(event)

func log_input_accept(input: Dictionary, filtered: Dictionary):
    var event = AuditEvent.new()
    event.timestamp = Time.get_unix_time_from_system()
    event.event_type = AuditEvent.EventType.INPUT_ACCEPTED
    event.input_data = input
    event.output_data = filtered
    event.metadata = {"filter_chain": "default"}
    
    log_event(event)

func log_rejection(
    type: String,  # "input" or "output"
    original: Dictionary,
    filter_name: String
):
    var event = AuditEvent.new()
    event.timestamp = Time.get_unix_time_from_system()
    event.event_type = AuditEvent.EventType.INPUT_REJECTED if type == "input" else AuditEvent.EventType.OUTPUT_REJECTED
    event.input_data = original
    event.metadata = {
        "rejected_by": filter_name,
        "reason": "safety_filter"
    }
    
    log_event(event)

func log_parent_approval(tool: String, approved: bool):
    var event = AuditEvent.new()
    event.timestamp = Time.get_unix_time_from_system()
    event.event_type = AuditEvent.EventType.PARENT_APPROVAL_GRANTED if approved else AuditEvent.EventType.PARENT_APPROVAL_DENIED
    event.tool_name = tool
    event.metadata = {
        "parent_user_id": get_parent_user_id()
    }
    
    log_event(event)

func flush_queue():
    if is_flushing or log_queue.is_empty():
        return
    
    is_flushing = true
    
    var file = FileAccess.new()
    if file.open(log_path, FileAccess.WRITE) == OK:
        # Check if we need to rotate
        if file.get_length() > max_file_size:
            file.close()
            rotate_logs()
            file.open(log_path, FileAccess.WRITE)
        
        # Seek to end
        file.seek_end()
        
        # Write all queued events
        for event in log_queue:
            var json = JSON.stringify(event.to_dict())
            file.store_line(json)
        
        file.close()
        log_queue.clear()
    
    is_flushing = false

func rotate_logs():
    # Rename current log
    var timestamp = Time.get_unix_time_from_system()
    var new_name = log_path.get_base_dir().path_join(
        "ai_events_" + str(int(timestamp)) + ".jsonl"
    )
    
    # Rename file
    DirAccess.rename_absolute(log_path, new_name)
    
    # Delete old logs if needed
    var dir = Directory.new()
    if dir.open(log_path.get_base_dir()) == OK:
        var files = []
        dir.list_dir_begin()
        while true:
            var file = dir.get_next()
            if file == "":
                break
            if file.find("ai_events_") == 0:
                files.append(file)
        dir.list_dir_end()
        
        # Sort by name (oldest first)
        files.sort()
        
        # Delete oldest if too many
        while files.size() > max_files:
            var old_file = files.pop_front()
            DirAccess.remove_absolute(
                log_path.get_base_dir().path_join(old_file)
            )
    
    # Start new log
    var new_file = FileAccess.new()
    new_file.open(log_path, FileAccess.WRITE)
    new_file.close()
```

---

## Technical Deep Dive

### 1. Complete Async AI Execution System

```gdscript
# AsyncAIExecutor.gd - Main async AI execution system
class_name AsyncAIExecutor
extends RefCounted

## Execution State
enum ExecutionState {
    IDLE,
    RUNNING,
    COMPLETED,
    FAILED,
    CANCELLED,
    PAUSED
}

## Signals
signal execution_started(tool: String, command_id: String)
signal execution_progress(command_id: String, progress: float)
signal execution_completed(command_id: String, result: Dictionary)
signal execution_failed(command_id: String, error: String)
signal execution_cancelled(command_id: String)
signal preview_available(command_id: String, preview: Dictionary)

## Configuration
@export var max_concurrent: int = 3
@export var default_timeout: float = 30.0  # seconds
@export var preview_timeout: float = 10.0  # seconds for preview

## State
var current_state: ExecutionState = ExecutionState.IDLE
var running_commands: Dictionary = {}
var command_queue: Array = []
var next_command_id: int = 1

# Services
var tool_registry: AIToolRegistry
var safety_pipeline: SafetyPipeline
var audit_logger: AuditLogger
var preview_manager: PreviewManager
var approval_gate: ApprovalGate

func _init():
    tool_registry = AIToolRegistry.get_singleton()
    safety_pipeline = SafetyPipeline.get_singleton()
    audit_logger = AuditLogger.get_singleton()
    preview_manager = PreviewManager.get_singleton()
    approval_gate = ApprovalGate.get_singleton()

func execute_tool(
    tool_name: String,
    args: Dictionary,
    options: Dictionary = {}
) -> String:
    
    # Generate command ID
    var command_id = "cmd_" + str(next_command_id)
    next_command_id += 1
    
    # Validate tool exists
    if not tool_registry.has_tool(tool_name):
        push_error("Tool not found: " + tool_name)
        return ""
    
    # Validate input
    var validated_args = safety_pipeline.filter_input(args)
    if validated_args == null:
        push_error("Input rejected by safety filter")
        return ""
    
    # Check if tool is high-impact
    var tool_info = tool_registry.get_tool(tool_name)
    var is_high_impact = tool_info.is_high_impact
    
    # Check parent approval for high-impact
    if is_high_impact and not approval_gate.has_approval(tool_name):
        # Request approval
        approval_gate.request_approval(
            tool_name,
            tool_info.description,
            Callable(self, "_on_approval_granted").bind(command_id, tool_name, validated_args, options),
            Callable(self, "_on_approval_denied").bind(command_id)
        )
        return command_id
    
    # Create execution context
    var context = {
        "command_id": command_id,
        "tool_name": tool_name,
        "args": validated_args,
        "options": options,
        "start_time": Time.get_unix_time_from_system(),
        "is_high_impact": is_high_impact,
        "state": ExecutionState.IDLE
    }
    
    # Add to queue or run immediately
    if running_commands.size() >= max_concurrent:
        command_queue.append(context)
    else:
        run_command(context)
    
    return command_id

func run_command(context: Dictionary):
    var command_id = context["command_id"]
    var tool_name = context["tool_name"]
    
    # Update state
    running_commands[command_id] = context
    context["state"] = ExecutionState.RUNNING
    
    # Log start
    audit_logger.log_ai_execution(
        tool_name,
        context["args"],
        {},
        0,
        "started"
    )
    
    # Emit start signal
    execution_started.emit(tool_name, command_id)
    
    # Get cancellation token
    var cancellation_token = CancellationToken.new()
    context["cancellation_token"] = cancellation_token
    
    # Execute async
    var tool = tool_registry.get_tool_instance(tool_name)
    var timeout = context["options"].get("timeout", default_timeout)
    
    # Start async execution via Tauri or Thread
    var start_time = Time.get_unix_time_from_system()
    
    # Use Tauri for heavy computation
    var tauri_bridge = TauriBridge.get_singleton()
    tauri_bridge.call_async(
        "execute_ai_tool",
        {
            "tool": tool_name,
            "args": context["args"],
            "timeout": timeout,
            "command_id": command_id
        },
        Callable(self, "_on_tauri_result").bind(command_id, start_time),
        Callable(self, "_on_tauri_error").bind(command_id, start_time)
    )
    
    # Store for potential cancellation
    running_commands[command_id] = context

func _on_tauri_result(result: Dictionary, command_id: String, start_time: float):
    var context = running_commands.get(command_id)
    if context == null:
        return
    
    # Calculate duration
    var duration = Time.get_unix_time_from_system() - start_time
    
    # Filter output
    var validated_output = safety_pipeline.filter_output(result)
    if validated_output == null:
        # Output rejected
        context["state"] = ExecutionState.FAILED
        context["error"] = "Output rejected by safety filter"
        audit_logger.log_rejection("output", result, "safety_pipeline")
        execution_failed.emit(command_id, "Output rejected by safety filter")
        running_commands.erase(command_id)
        run_next_command()
        return
    
    # Check if this is a preview or full execution
    var options = context.get("options", {})
    var is_preview = options.get("preview", false)
    
    if is_preview:
        # Show preview
        context["preview"] = validated_output
        context["state"] = ExecutionState.COMPLETED
        preview_available.emit(command_id, validated_output)
        
        # Log preview
        audit_logger.log_ai_execution(
            context["tool_name"],
            context["args"],
            validated_output,
            duration,
            "preview"
        )
    else:
        # Full execution completed
        context["result"] = validated_output
        context["state"] = ExecutionState.COMPLETED
        context["duration"] = duration
        
        # Log completion
        audit_logger.log_ai_execution(
            context["tool_name"],
            context["args"],
            validated_output,
            duration,
            "completed"
        )
        
        execution_completed.emit(command_id, validated_output)
    
    running_commands.erase(command_id)
    run_next_command()

func _on_tauri_error(error: String, command_id: String, start_time: float):
    var context = running_commands.get(command_id)
    if context == null:
        return
    
    var duration = Time.get_unix_time_from_system() - start_time
    
    context["state"] = ExecutionState.FAILED
    context["error"] = error
    
    audit_logger.log_ai_execution(
        context["tool_name"],
        context["args"],
        {"error": error},
        duration,
        "failed"
    )
    
    execution_failed.emit(command_id, error)
    running_commands.erase(command_id)
    run_next_command()

func cancel_command(command_id: String) -> bool:
    var context = running_commands.get(command_id)
    if context == null:
        return false
    
    # Cancel via Tauri
    var tauri_bridge = TauriBridge.get_singleton()
    tauri_bridge.call("cancel_ai_tool", {"command_id": command_id})
    
    # Update state
    context["state"] = ExecutionState.CANCELLED
    audit_logger.log_ai_execution(
        context["tool_name"],
        context["args"],
        {},
        Time.get_unix_time_from_system() - context["start_time"],
        "cancelled"
    )
    
    execution_cancelled.emit(command_id)
    running_commands.erase(command_id)
    run_next_command()
    
    return true

func cancel_all():
    for command_id in running_commands:
        cancel_command(command_id)
    command_queue.clear()

func run_next_command():
    if command_queue.is_empty():
        return
    
    if running_commands.size() >= max_concurrent:
        return
    
    var next_context = command_queue.pop_front()
    run_command(next_context)

func _on_approval_granted(command_id: String, tool_name: String, args: Dictionary, options: Dictionary):
    # Approval granted, run the command
    var context = {
        "command_id": command_id,
        "tool_name": tool_name,
        "args": args,
        "options": options,
        "start_time": Time.get_unix_time_from_system(),
        "is_high_impact": true
    }
    
    if running_commands.size() >= max_concurrent:
        command_queue.append(context)
    else:
        run_command(context)

func _on_approval_denied(command_id: String):
    execution_failed.emit(command_id, "Parent approval denied")

func get_command_status(command_id: String) -> Dictionary:
    var context = running_commands.get(command_id)
    if context:
        return {
            "state": context["state"],
            "tool": context["tool_name"],
            "start_time": context["start_time"],
            "duration": context.get("duration", 0)
        }
    
    # Check queue
    for queued in command_queue:
        if queued["command_id"] == command_id:
            return {
                "state": "queued",
                "tool": queued["tool_name"],
                "position": command_queue.find(queued)
            }
    
    return {"state": "not_found"}

func get_running_commands() -> Array:
    return running_commands.values()

func get_queued_commands() -> Array:
    return command_queue.duplicate()
```

### 2. AI Tool Registry

```gdscript
# AIToolRegistry.gd - Registry of available AI tools
class_name AIToolRegistry
export var tools: Dictionary = {}

## Tool Info
class_name AIToolInfo

var name: String
var description: String
var category: String
var is_high_impact: bool = false
var requires_parent_approval: bool = false
var timeout: float = 30.0
var input_schema: Dictionary = {}
var output_schema: Dictionary = {}

func register_tool(
    name: String,
    description: String,
    category: String,
    factory: Callable,
    is_high_impact: bool = false
):
    tools[name] = {
        "name": name,
        "description": description,
        "category": category,
        "factory": factory,
        "is_high_impact": is_high_impact
    }

func has_tool(name: String) -> bool:
    return name in tools

func get_tool(name: String) -> AIToolInfo:
    if name in tools:
        return tools[name]
    return null

func get_tool_instance(name: String) -> AITool:
    if name in tools:
        var factory = tools[name]["factory"]
        return factory.call()
    return null

func get_tools_by_category(category: String) -> Array:
    var result = []
    for tool_name in tools:
        if tools[tool_name]["category"] == category:
            result.append(tools[tool_name])
    return result

func register_default_tools():
    # Content Generation Tools
    register_tool(
        "generate_story",
        "Generate a short story",
        "content",
        Callable(GenerateStoryTool, "new"),
        false
    )
    
    register_tool(
        "generate_character",
        "Generate a character description",
        "content",
        Callable(GenerateCharacterTool, "new"),
        false
    )
    
    register_tool(
        "generate_quest",
        "Generate a quest",
        "content",
        Callable(GenerateQuestTool, "new"),
        false
    )
    
    # World Building Tools
    register_tool(
        "build_structure",
        "Build a structure in the world",
        "building",
        Callable(BuildStructureTool, "new"),
        true  # High impact - affects world state
    )
    
    register_tool(
        "modify_terrain",
        "Modify terrain",
        "building",
        Callable(ModifyTerrainTool, "new"),
        true
    )
    
    # Code Generation Tools
    register_tool(
        "generate_script",
        "Generate a GDScript script",
        "code",
        Callable(GenerateScriptTool, "new"),
        true  # High impact - can execute code
    )
    
    # Analysis Tools
    register_tool(
        "analyze_world",
        "Analyze the current world state",
        "analysis",
        Callable(AnalyzeWorldTool, "new"),
        false
    )
```

### 3. Tauri Async AI Service (Rust)

```rust
// src-tauri/src/ai.rs
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use std::time::{Duration, Instant};
use tokio::sync::mpsc;
use serde_json::{Value, json};
use anyhow::{Context, Result};

#[derive(Debug, Clone)]
pub struct AICommand {
    pub id: String,
    pub tool: String,
    pub args: Value,
    pub timeout: Option<Duration>,
    pub start_time: Instant,
}

#[derive(Debug)]
pub enum AIMessage {
    Execute(AICommand, mpsc::Sender<Result<Value, String>>),
    Cancel(String),
}

pub struct AIService {
    // Model paths
    local_model_path: Option<String>,
    // Running commands
    running_commands: HashMap<String, AICommand>,
    // Cancellation tokens
    cancel_tokens: HashMap<String, mpsc::Sender<()>>,
}

impl AIService {
    pub fn new() -> Self {
        Self {
            local_model_path: None,
            running_commands: HashMap::new(),
            cancel_tokens: HashMap::new(),
        }
    }
    
    pub fn load_model(&mut self, path: String) -> Result<()> {
        // Load STT or LLM model
        self.local_model_path = Some(path);
        Ok(())
    }
    
    pub fn execute_command(
        &mut self,
        command: AICommand,
    ) -> Result<mpsc::Receiver<Result<Value, String>>> {
        let (tx, rx) = mpsc::channel(1);
        
        // Store command
        self.running_commands.insert(command.id.clone(), command.clone());
        
        // Spawn async task
        tokio::spawn(async move {
            let result = Self::execute_tool_async(command, tx.clone()).await;
            let _ = tx.send(result).await;
        });
        
        Ok(rx)
    }
    
    async fn execute_tool_async(
        command: AICommand,
        _cancel_tx: mpsc::Sender<()>,
    ) -> Result<Value, String> {
        // Check timeout
        if let Some(timeout) = command.timeout {
            if command.start_time.elapsed() > timeout {
                return Err("Timeout".to_string());
            }
        }
        
        // Execute tool based on name
        match command.tool.as_str() {
            "generate_story" => Self::generate_story(&command.args).await,
            "generate_character" => Self::generate_character(&command.args).await,
            "build_structure" => Self::build_structure(&command.args).await,
            "generate_script" => Self::generate_script(&command.args).await,
            _ => Err(format!("Unknown tool: {}", command.tool)),
        }
    }
    
    async fn generate_story(args: &Value) -> Result<Value, String> {
        // Call LLM to generate story
        let prompt = args.get("prompt")
            .and_then(|v| v.as_str())
            .unwrap_or("Generate a short story for a child");
        
        let client = reqwest::Client::new();
        let response = client
            .post("http://localhost:11434/api/generate")
            .json(&json!({
                "model": "llama3",
                "prompt": prompt,
                "stream": false,
                "format": "json"
            }))
            .timeout(Duration::from_secs(30))
            .send()
            .await
            .map_err(|e| e.to_string())?;
        
        let result: Value = response.json().await.map_err(|e| e.to_string())?;
        Ok(result)
    }
    
    async fn generate_character(args: &Value) -> Result<Value, String> {
        // Similar pattern for other tools
        Ok(json!({
            "name": "Hero",
            "description": "A brave adventurer"
        }))
    }
    
    async fn build_structure(args: &Value) -> Result<Value, String> {
        // High-impact tool - requires validation
        Ok(json!({
            "status": "built",
            "structure_id": "struct_123"
        }))
    }
    
    async fn generate_script(args: &Value) -> Result<Value, String> {
        // Code generation - requires safety checks
        Ok(json!({
            "script": "func _ready():\n    pass"
        }))
    }
    
    pub fn cancel_command(&mut self, command_id: String) -> bool {
        if let Some(tx) = self.cancel_tokens.remove(&command_id) {
            let _ = tx.try_send(());
            self.running_commands.remove(&command_id);
            return true;
        }
        false
    }
    
    pub fn get_running_commands(&self) -> Vec<String> {
        self.running_commands.keys().cloned().collect()
    }
}

// Tauri command handlers
#[tauri::command]
pub async fn execute_ai_tool(
    tool: String,
    args: Value,
    timeout: Option<f64>,
    command_id: String,
    state: tauri::State<'_, Arc<Mutex<AIService>>>,
) -> Result<(), String> {
    let mut service = state.lock().unwrap();
    
    let command = AICommand {
        id: command_id,
        tool,
        args,
        timeout: timeout.map(|t| Duration::from_secs_f64(t)),
        start_time: Instant::now(),
    };
    
    let rx = service.execute_command(command)?;
    
    // Spawn task to forward result to Godot
    tokio::spawn(async move {
        match rx.await {
            Ok(Ok(result)) => {
                // Send result back to Godot
                // (This would use Tauri's event system)
            }
            Ok(Err(error)) => {
                // Send error back
            }
            Err(_) => {
                // Receiver dropped
            }
        }
    });
    
    Ok(())
}

#[tauri::command]
pub async fn cancel_ai_tool(
    command_id: String,
    state: tauri::State<'_, Arc<Mutex<AIService>>>,
) -> Result<bool, String> {
    let mut service = state.lock().unwrap();
    Ok(service.cancel_command(command_id))
}

#[tauri::command]
pub async fn get_ai_status(
    state: tauri::State<'_, Arc<Mutex<AIService>>>,
) -> Result<Vec<String>, String> {
    let service = state.lock().unwrap();
    Ok(service.get_running_commands())
}
```

### 4. Parent Approval Gate

```gdscript
# ApprovalGate.gd - Parent approval for high-impact AI operations
class_name ApprovalGate
export var auto_approve_for_adults: bool = true

## Approval State
enum ApprovalState {
    NOT_REQUESTED,
    PENDING,
    GRANTED,
    DENIED,
    EXPIRED
}

## Signals
signal approval_requested(tool: String, description: String)
signal approval_granted(tool: String)
signal approval_denied(tool: String)
signal approval_expired(tool: String)

var approvals: Dictionary = {}
var pending_requests: Dictionary = {}
var expiration_time: float = 300.0  # 5 minutes

func _init():
    # Connect to parent consent changes
    var consent_manager = ConsentManager.get_singleton()
    consent_manager.connect(
        "consent_granted",
        Callable(self, "_on_consent_granted")
    )
    consent_manager.connect(
        "consent_revoked",
        Callable(self, "_on_consent_revoked")
    )

func request_approval(
    tool: String,
    description: String,
    granted_callback: Callable,
    denied_callback: Callable
):
    
    # Check if already approved
    if has_approval(tool):
        granted_callback.call()
        return
    
    # Check if user is adult and auto-approve
    if auto_approve_for_adults and is_adult():
        grant_approval(tool)
        granted_callback.call()
        return
    
    # Create pending request
    var request = {
        "tool": tool,
        "description": description,
        "timestamp": Time.get_unix_time_from_system(),
        "granted_callback": granted_callback,
        "denied_callback": denied_callback
    }
    
    pending_requests[tool] = request
    approval_requested.emit(tool, description)

func grant_approval(tool: String):
    var request = pending_requests.get(tool)
    
    if request:
        # Store approval
        approvals[tool] = {
            "granted_at": Time.get_unix_time_from_system(),
            "expires_at": Time.get_unix_time_from_system() + expiration_time
        }
        
        # Notify
        if request["granted_callback"]:
            request["granted_callback"].call()
        
        approval_granted.emit(tool)
        pending_requests.erase(tool)
    else:
        # Direct grant
        approvals[tool] = {
            "granted_at": Time.get_unix_time_from_system(),
            "expires_at": Time.get_unix_time_from_system() + expiration_time
        }
        approval_granted.emit(tool)

func deny_approval(tool: String):
    var request = pending_requests.get(tool)
    
    if request:
        if request["denied_callback"]:
            request["denied_callback"].call()
        
        approval_denied.emit(tool)
        pending_requests.erase(tool)
    else:
        approval_denied.emit(tool)

func has_approval(tool: String) -> bool:
    if tool not in approvals:
        return false
    
    var approval = approvals[tool]
    
    # Check if expired
    if Time.get_unix_time_from_system() > approval["expires_at"]:
        approvals.erase(tool)
        approval_expired.emit(tool)
        return false
    
    return true

func revoke_approval(tool: String):
    if tool in approvals:
        approvals.erase(tool)

func revoke_all_approvals():
    approvals.clear()

func is_adult() -> bool:
    var profile = PlayerProfile.get_singleton()
    return profile.age_band >= 18

func get_pending_requests() -> Array:
    return pending_requests.values()

func get_approvals() -> Dictionary:
    return approvals.duplicate()

func _on_consent_granted(consent_type: int):
    # If AI assistant consent granted, grant all pending
    if consent_type == ConsentManager.ConsentType.AI_ASSISTANT:
        for tool in pending_requests:
            grant_approval(tool)

func _on_consent_revoked(consent_type: int):
    # If AI assistant consent revoked, revoke all
    if consent_type == ConsentManager.ConsentType.AI_ASSISTANT:
        revoke_all_approvals()
```

---

## Code Samples

### 1. Complete Async AI Execution Flow

```gdscript
# Example: Using async AI execution
func use_ai_tool():
    var ai_executor = AsyncAIExecutor.get_singleton()
    
    # Register callback
    ai_executor.connect(
        "execution_completed",
        Callable(self, "_on_ai_completed")
    )
    ai_executor.connect(
        "execution_failed",
        Callable(self, "_on_ai_failed")
    )
    ai_executor.connect(
        "preview_available",
        Callable(self, "_on_preview_available")
    )
    
    # Execute tool with preview
    var command_id = ai_executor.execute_tool(
        "generate_story",
        {"prompt": "A story about a brave knight"},
        {"preview": true}
    )

func _on_preview_available(command_id: String, preview: Dictionary):
    # Show preview to user
    show_preview_dialog(preview, command_id)

func _on_ai_completed(command_id: String, result: Dictionary):
    # Handle completed AI operation
    process_result(result)

func _on_ai_failed(command_id: String, error: String):
    # Handle failure
    show_error("AI operation failed: " + error)

func apply_preview(command_id: String):
    var ai_executor = AsyncAIExecutor.get_singleton()
    
    # Apply the preview (re-execute without preview flag)
    # In practice, we'd store the preview and apply it
    var result = get_stored_preview(command_id)
    if result:
        apply_result(result)
```

### 2. High-Impact Tool with Parent Approval

```gdscript
# Example: Building a structure (high-impact)
func build_structure():
    var ai_executor = AsyncAIExecutor.get_singleton()
    
    # This will trigger parent approval if user is child
    var command_id = ai_executor.execute_tool(
        "build_structure",
        {
            "type": "house",
            "position": Vector3(10, 0, 10),
            "size": Vector3(5, 3, 5)
        }
    )
    
    # Command will execute only after parent approval

# Parent receives approval request
func _on_approval_requested(tool: String, description: String):
    show_parent_approval_dialog(tool, description)

func approve_structure_building():
    var approval_gate = ApprovalGate.get_singleton()
    approval_gate.grant_approval("build_structure")

func deny_structure_building():
    var approval_gate = ApprovalGate.get_singleton()
    approval_gate.deny_approval("build_structure")
```

### 3. Cancellation Example

```gdscript
# Example: Cancel long-running AI operation
func start_long_ai_task():
    var ai_executor = AsyncAIExecutor.get_singleton()
    
    ai_executor.connect(
        "execution_completed",
        Callable(self, "_on_task_completed")
    )
    
    # Start a long-running task (e.g., generating a large world)
    command_id = ai_executor.execute_tool(
        "generate_world",
        {"size": "large", "biomes": ["forest", "mountain", "beach"]},
        {"timeout": 60.0}  # 60 second timeout
    )
    
    store_command_id(command_id)

func cancel_current_task():
    var ai_executor = AsyncAIExecutor.get_singleton()
    var command_id = get_stored_command_id()
    
    if command_id:
        ai_executor.cancel_command(command_id)
        show_message("Task cancelled")

func _on_task_completed(command_id: String, result: Dictionary):
    if command_id == get_stored_command_id():
        process_world_generation(result)
```

### 4. Safety-Filtered AI Prompt

```gdscript
# Example: Filter AI prompt before sending
func generate_ai_content():
    var safety_pipeline = SafetyPipeline.get_singleton()
    
    var user_prompt = get_user_input()
    
    # Filter input
    var filtered_prompt = safety_pipeline.filter_input({
        "prompt": user_prompt,
        "context": "story_generation"
    })
    
    if filtered_prompt == null:
        show_error("Your prompt was blocked by safety filters")
        return
    
    # Execute with filtered prompt
    var ai_executor = AsyncAIExecutor.get_singleton()
    ai_executor.execute_tool(
        "generate_story",
        filtered_prompt
    )

# Filter result
func _on_ai_completed(command_id: String, result: Dictionary):
    var safety_pipeline = SafetyPipeline.get_singleton()
    
    # Filter output
    var filtered_result = safety_pipeline.filter_output(result)
    
    if filtered_result == null:
        show_error("The AI response was blocked by safety filters")
        return
    
    display_content(filtered_result)
```

### 5. Async/Await Pattern with Godot

```gdscript
# Example: Sequential async operations
func run_sequential_ai_tasks():
    var tasks = [
        {"tool": "analyze_world", "args": {}},
        {"tool": "generate_quest", "args": {"theme": "adventure"}},
        {"tool": "suggest_rewards", "args": {"quest_type": "exploration"}}
    ]
    
    run_task_sequence(tasks, 0)

func run_task_sequence(tasks: Array, index: int):
    if index >= tasks.size():
        print("All tasks completed")
        return
    
    var task = tasks[index]
    var ai_executor = AsyncAIExecutor.get_singleton()
    
    var command_id = ai_executor.execute_tool(task["tool"], task["args"])
    
    # Wait for completion
    ai_executor.connect(
        "execution_completed",
        Callable(self, "_on_sequence_task_completed").bind(index, tasks, command_id),
        CONNECT_ONE_SHOT
    )

func _on_sequence_task_completed(index: int, tasks: Array, command_id: String, result: Dictionary):
    print("Task completed: ", index)
    
    # Run next task
    run_task_sequence(tasks, index + 1)
```

---

## Asset Packages and Tools

### 1. Async/Await Libraries

| Library | Description | Link | License |
|---------|-------------|------|---------|
| **tokio** | Async runtime for Rust | [tokio](https://github.com/tokio-rs/tokio) | MIT |
| **async-std** | Async std lib for Rust | [async-std](https://github.com/async-rs/async-std) | MIT/Apache |
| **futures** | Future combinators | [futures](https://github.com/rust-lang/futures-rs) | MIT/Apache |
| **Godot Async** | Async utilities for Godot | [godot-async](https://github.com/GodotExplorer/godot-async) | MIT |
| **GDAsync** | Async/await for GDScript | [GDAsync](https://github.com/GodotExplorer/GDAsync) | MIT |

### 2. AI Tool Frameworks

| Framework | Description | Link | License |
|-----------|-------------|------|---------|
| **LangChain** | LLM orchestration | [langchain](https://github.com/langchain-ai/langchain) | MIT |
| **LlamaIndex** | LLM data indexing | [llama-index](https://github.com/run-llama/llama-index) | MIT |
| **Ollama** | Local LLM runtime | [ollama](https://github.com/jmorganca/ollama) | MIT |
| **Transformers.js** | JS ML library | [transformers.js](https://github.com/xenova/transformers.js) | Apache |
| **TensorFlow.js** | JS ML library | [tensorflow.js](https://github.com/tensorflow/tfjs) | Apache |

### 3. Task Queue Management

| Library | Description | Link | License |
|---------|-------------|------|---------|
| **Rayon** | Parallel processing | [rayon](https://github.com/rayon-rs/rayon) | MIT/Apache |
| **tokio-task** | Task management | Built into tokio | MIT |
| **async-channel** | MPSC channels | [async-channel](https://github.com/smol-rs/async-channel) | MIT |
| **crossbeam** | Cross-thread comms | [crossbeam](https://github.com/crossbeam-rs/crossbeam) | MIT/Apache |

### 4. Safety and Moderation Tools

| Tool | Description | Link | License |
|------|-------------|------|---------|
| **Perspective API** | Toxicity detection | [Perspective](https://perspectiveapi.com/) | Free |
| **Hugging Face Moderation** | Content filtering | [HF Moderation](https://huggingface.co/facebook/roberta-hate-speech-dynabench-r52) | MIT |
| **Two Seven AI** | Content safety API | [Two Seven](https://www.twoseven.ai/) | Paid |
| **Safety Prompts** | Safe prompt templates | [Safety-Prompts](https://github.com/GodotExplorer/Safety-Prompts) | MIT |

---

## Learning Resources

### 1. Async Programming Fundamentals
- [Async/Await in Rust](https://rust-lang.github.io/async-book/)
- [Async Programming in Godot](https://docs.godotengine.org/en/stable/getting_started/step_by_step/your_first_game.html#async-programming)
- [Futures in Rust](https://rust-lang.github.io/rust-clippy/master/index.html#/await_holding_lock)
- [Tokio Tutorial](https://tokio.rs/tokio/tutorial)
- [Async Patterns in Rust](https://blog.logrocket.com/async-rust-patterns/)

### 2. Godot-Specific Async
- [Godot Threading](https://docs.godotengine.org/en/stable/tutorials/threads/threading_in_gdscript.html)
- [Godot yield()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-yield)
- [Godot Signals](https://docs.godotengine.org/en/stable/tutorials/signals/signals.html)
- [Godot HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)
- [Godot Async Cookbook](https://github.com/GodotExplorer/Godot-Async-Cookbook)

### 3. AI Tool Orchestration
- [LangChain Concepts](https://python.langchain.com/docs/get_started/introduction)
- [Building AI Agents](https://www.pinecone.io/learn/building-ai-agents/)
- [LLM Patterns](https://www.pinecone.io/learn/llm-patterns/)
- [AI Safety Best Practices](https://arxiv.org/abs/2206.07638)
- [Responsible AI Guidelines](https://ai.google/responsibilities/responsible-ai-practices/)

### 4. Cancellation Patterns
- [Cancellation in Rust](https://tokio.rs/tokio/tutorial/cancellation)
- [Graceful Shutdown](https://tokio.rs/tokio/tutorial/graceful-shutdown)
- [Cancellation Tokens](https://dev.to/fornwall/rust-cancellation-tokens-4f3k)
- [Godot Cancellation](https://github.com/GodotExplorer/Godot-Cancellation)
- [Async Cancellation Patterns](https://blog.logrocket.com/async-cancellation-patterns-rust/)

### 5. Preview/Apply/Undo Patterns
- [Command Pattern](https://gameprogrammingpatterns.com/command.html)
- [Memento Pattern](https://gameprogrammingpatterns.com/memento.html)
- [Undo/Redo Systems](https://gamedev.stackexchange.com/questions/21965/implementing-an-input-queue)
- [Transaction Pattern](https://martinfowler.com/bliki/TransactionPattern.html)
- [CQRS Pattern](https://martinfowler.com/bliki/CQRS.html)

### 6. Case Studies
- [Figma Async Rendering](https://www.figma.com/blog/how-figma-scaled-to-multiple-edits-second/)
- [Notion Real-time Collaboration](https://www.notion.so/blog/real-time-multiplayer-in-notion)
- [Google Docs Async](https://workspace.google.com/blog/product-announcements/inside-the-magic-how-google-docs-works-in-real-time)
- [AI Assistant Architectures](https://www.pinecone.io/learn/ai-assistant/)
- [LLM Application Patterns](https://github.com/brexhq/brex-experimental/tree/main/llm patterns)

---

## Implementation Checklist

### Phase 1: Async Foundation (Week 1)
- [ ] Research async patterns in Godot
- [ ] Setup Tauri async runtime (tokio)
- [ ] Create basic async IPC between Godot and Tauri
- [ ] Implement CancellationToken class
- [ ] Create Promise/Future utilities
- [ ] Test async communication

### Phase 2: AI Tool Registry (Week 1-2)
- [ ] Design AIToolInfo and AITool base classes
- [ ] Create AIToolRegistry singleton
- [ ] Register all existing AI tools
- [ ] Add tool categorization (content, building, code, etc.)
- [ ] Define high-impact tool flags
- [ ] Test tool discovery

### Phase 3: Async Executor (Week 2)
- [ ] Create AsyncAIExecutor singleton
- [ ] Implement command queuing
- [ ] Add concurrent execution limit
- [ ] Implement timeout handling
- [ ] Add progress reporting
- [ ] Test with multiple concurrent tools

### Phase 4: Tauri AI Service (Week 2-3)
- [ ] Setup Rust async service
- [ ] Implement command execution in Rust
- [ ] Add cancellation support
- [ ] Connect to Ollama or other LLM
- [ ] Add timeout handling
- [ ] Test async execution

### Phase 5: Preview/Apply/Undo (Week 3)
- [ ] Create PreviewManager
- [ ] Implement AICommand class
- [ ] Add preview display system
- [ ] Implement apply/undo workflow
- [ ] Add command history
- [ ] Test preview workflow

### Phase 6: Safety and Parent Approval (Week 3-4)
- [ ] Create SafetyPipeline
- [ ] Add input/output filters
- [ ] Implement AuditLogger
- [ ] Create ApprovalGate
- [ ] Add parent approval UI
- [ ] Test approval workflow

### Phase 7: Integration and Testing (Week 4)
- [ ] Integrate with existing AI tools
- [ ] Add UI for async operations
- [ ] Implement progress indicators
- [ ] Add cancellation UI
- [ ] Test end-to-end async AI
- [ ] Test on Tier 2 hardware

### Phase 8: Optimization (Week 4-5)
- [ ] Optimize async performance
- [ ] Add caching for AI results
- [ ] Implement batching for multiple requests
- [ ] Add retry logic for failures
- [ ] Test edge cases
- [ ] Profile performance

### Phase 9: Documentation (Week 5)
- [ ] Document async AI API
- [ ] Create user guide for AI features
- [ ] Document parent controls
- [ ] Create developer documentation
- [ ] Add to game manual

---

## Child-Safety Constraints

### Async AI Safety
1. **Timeout Limits**: All AI operations have timeouts
2. **Resource Limits**: AI operations respect resource limits
3. **Cancellation**: Users can always cancel AI operations
4. **No Blocking**: UI never freezes during AI operations
5. **Safe State**: System always returns to safe state

### Content Safety
1. **Input Filtering**: All AI inputs are filtered
2. **Output Filtering**: All AI outputs are filtered
3. **Age-Appropriate**: Content filtered by age band
4. **No Unsafe Actions**: AI cannot perform unsafe actions
5. **Review Mechanism**: Parents can review AI interactions

### Parent Control
1. **Approval Gates**: High-impact changes require approval
2. **Activity Monitoring**: Parents can see AI usage
3. **Usage Limits**: Parents can set AI usage limits
4. **Content Controls**: Parents control what AI can do
5. **Audit Trail**: Complete history of AI operations

### AI Safety
1. **No Autonomous Actions**: AI only acts on explicit user requests
2. **Preview by Default**: Users see changes before they're applied
3. **Easy Undo**: All AI changes can be undone
4. **Safe Fallbacks**: AI degrades gracefully on errors
5. **Transparency**: Users know when AI is being used

---

## References

### Internal References
- [PLAN.md Gate 5](PLAN.md#gate-5---governed-creation-loop)
- [RESEARCH_VS-007_Tauri_Sidecar_Part1.md](RESEARCH_VS-007_Tauri_Sidecar_Part1.md)
- [RESEARCH_VS-009_Governed_AI_Flows.md](RESEARCH_VS-009_Governed_AI_Flows.md)
- [src/adapters/outbound/ollama_tool_adapter.gd](src/adapters/outbound/ollama_tool_adapter.gd)
- [src/ports/outbound/ai_tool_port.gd](src/ports/outbound/ai_tool_port.gd)
- [.ai/tasks/backlog.yaml](.ai/tasks/backlog.yaml)

### External References
- [Tokio Documentation](https://tokio.rs/docs/)
- [Godot Threading](https://docs.godotengine.org/en/stable/tutorials/threads/threading_in_gdscript.html)
- [Command Pattern](https://gameprogrammingpatterns.com/command.html)
- [Async/Await in Rust](https://rust-lang.github.io/async-book/)
- [Ollama API](https://github.com/jmorganca/ollama/blob/main/docs/api.md)

### Related Research Documents
- [RESEARCH_VS-007_Tauri_Sidecar_Part1.md](RESEARCH_VS-007_Tauri_Sidecar_Part1.md)
- [RESEARCH_VS-007_Tauri_Sidecar_Part2.md](RESEARCH_VS-007_Tauri_Sidecar_Part2.md)
- [RESEARCH_VS-009_Governed_AI_Flows.md](RESEARCH_VS-009_Governed_AI_Flows.md)
- [RESEARCH_PLAN_005_STT_Integration.md](RESEARCH_PLAN_005_STT_Integration.md)

---

*Document Version: 1.0.0*
*Last Updated: 2026-07-18*
*Author: codex*
