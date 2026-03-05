## Value object capturing the outcome of a content moderation check.
## Used in both input moderation (before LLM call) and output moderation
## (before rendering or applying content). Carries safe alternatives
## when content is blocked.
class_name ModerationResult
extends RefCounted

enum Verdict { PASS, BLOCK, WARN }

var verdict: Verdict
var reason: String
var category: String
var confidence: float
var safe_alternative: String


func _init(p_verdict: Verdict = Verdict.PASS, p_reason: String = "") -> void:
	verdict = p_verdict
	reason = p_reason
	category = ""
	confidence = 1.0
	safe_alternative = ""


func is_blocked() -> bool:
	return verdict == Verdict.BLOCK


func is_warning() -> bool:
	return verdict == Verdict.WARN
