class_name ShellBridgePort
extends RefCounted

## Outbound port for the Tauri shell IPC bridge (research:
## thoughts/shared/research/shell-architecture-2026-05-21.md).
##
## The bridge lets the Tauri/WebView shell observe gameplay-side lifecycle
## events (session start/end, publish-state changes) and synchronously read
## kid-status read-model data while the Godot sidecar is alive. Adapters
## bind to 127.0.0.1 only and audit every accepted connection through
## AuditLedgerPort.
##
## Hexagonal rule: domain types are never leaked through this port — every
## argument is a primitive or plain Dictionary. The default implementation
## here is the safe no-op (production default, off-by-default).


## Notifies the shell that a play session just started for the given world.
## p_world_id: opaque world identifier (no PII).
## p_profile_id: opaque kid-profile identifier (anonymised session id).
func notify_session_started(p_world_id: String, p_profile_id: String) -> void:
	pass


## Notifies the shell that a play session has ended.
## p_stats: end-of-session telemetry (elapsed_seconds, items_collected, etc.).
##          Keys/values must be JSON-serialisable primitives.
func notify_session_ended(p_stats: Dictionary) -> void:
	pass


## Notifies the shell that a publish request transitioned to a new state.
## p_req_id: publish request identifier.
## p_state: one of "submitted" | "approved" | "rejected" | "published".
func notify_publish_state_changed(p_req_id: String, p_state: String) -> void:
	pass


## Synchronous read-model fetch for the kid-status panel rendered in the
## shell. Returns an empty Dictionary when the bridge is OFF or when no
## status data is available for the given profile/world tuple.
func request_kid_status(p_profile_id: String, p_world_id: String) -> Dictionary:
	return {}
