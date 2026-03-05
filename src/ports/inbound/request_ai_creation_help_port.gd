## Inbound port: request AI assistance for world creation.
## Interprets a natural language prompt into a proposed AIAssistantAction
## with tool invocations. Enforces input moderation and age-band policy
## before calling the LLM.
class_name RequestAICreationHelpPort
extends RefCounted


func execute(session_id: String, prompt_text: String, actor: PlayerProfile, preview_only: bool = false) -> AIAssistantAction:
	push_error("RequestAICreationHelpPort.execute() not implemented")
	return null


func execute_pending_action(action: AIAssistantAction, actor: PlayerProfile) -> AIAssistantAction:
	push_error("RequestAICreationHelpPort.execute_pending_action() not implemented")
	return null
