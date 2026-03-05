## Inbound port: create a new project from a starter template.
## Called by UI adapters when a kid picks a template to start building.
class_name CreateProjectFromTemplatePort
extends RefCounted


func execute(template_id: String, owner: PlayerProfile) -> Project:
	push_error("CreateProjectFromTemplatePort.execute() not implemented")
	return null
