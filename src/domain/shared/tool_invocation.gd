## Value object representing a single AI tool call with its arguments.
## Tool invocations are validated against schemas and permission scopes
## before execution in the AI orchestration loop.
class_name ToolInvocation
extends RefCounted

var tool_name: String
var arguments: Dictionary
var invocation_id: String
var is_idempotent: bool
var requires_approval: bool
var provenance: Dictionary


# NOTE: The mutable Dictionary default `{}` is safe in GDScript 4.x.
# Unlike Python, each call receives a fresh Dictionary instance — the default
# is not shared across invocations. Confirmed during TASK-001 code review.
func _init(
	p_tool_name: String = "",
	p_arguments: Dictionary = {},
	p_invocation_id: String = ""
) -> void:
	tool_name = p_tool_name
	arguments = p_arguments
	invocation_id = p_invocation_id
	is_idempotent = false
	requires_approval = false
	provenance = {}


func is_high_impact() -> bool:
	return requires_approval or not is_idempotent
