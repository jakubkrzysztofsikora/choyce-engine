## Application service: creates a new project from a template.
## Orchestrates template loading, domain entity creation, and persistence
## through outbound ports. Decoupled from UI and storage implementations.
class_name CreateProjectService
extends CreateProjectFromTemplatePort

var _project_store: ProjectStorePort
var _clock: ClockPort


func setup(project_store: ProjectStorePort, clock: ClockPort) -> CreateProjectService:
	_project_store = project_store
	_clock = clock
	return self


func execute(template_id: String, owner: PlayerProfile) -> Project:
	var now := _clock.now_iso()

	var project := Project.new()
	project.project_id = "%s_%s" % [owner.profile_id, template_id]
	project.title = template_id
	project.template_id = template_id
	project.owner_profile_id = owner.profile_id
	project.created_at = now
	project.updated_at = now

	var default_world := World.new()
	default_world.world_id = "%s_world_1" % project.project_id
	default_world.name = template_id
	project.add_world(default_world)

	_project_store.save_project(project)
	return project
