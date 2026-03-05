## Value object wrapping an AI prompt with safety and localization metadata.
## Passed through the AI Orchestration context to ensure every LLM call
## carries age band, language policy, and permitted tool scopes.
class_name PromptEnvelope
extends RefCounted

var prompt_text: String
var language: String
var age_band: AgeBand
var context_tags: Array[String]
var max_tokens: int
var permitted_tools: Array[String]
var session_id: String


func _init(
	p_text: String = "",
	p_language: String = "pl-PL",
	p_age_band: AgeBand = null
) -> void:
	prompt_text = p_text
	language = p_language
	age_band = p_age_band if p_age_band else AgeBand.new()
	context_tags = []
	max_tokens = 512
	permitted_tools = []
	session_id = ""


func is_polish() -> bool:
	return language.begins_with("pl")
