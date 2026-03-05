## Filesystem adapter for AssetRepositoryPort.
## Stores binary assets under:
##   projects/{project_id}/assets/{asset_path}
## Asset ID formats:
##   "{project_id}/{asset_path}" (preferred)
##   "{project_id}:{asset_path}" (supported)
##   "{asset_path}" (stored in shared/assets/)
class_name FilesystemAssetRepository
extends AssetRepositoryPort

var _projects_root: String = "user://projects"


func _init(root_path: String = "user://projects") -> void:
	setup(root_path)


func setup(root_path: String = "user://projects") -> FilesystemAssetRepository:
	_projects_root = root_path.strip_edges()
	if _projects_root.is_empty():
		_projects_root = "user://projects"
	_ensure_dir(_projects_root)
	return self


func store(asset_id: String, data: PackedByteArray) -> bool:
	var path := _resolve_asset_path(asset_id)
	if path.is_empty():
		return false
	if not _ensure_dir(path.get_base_dir()):
		return false

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(data)
	return true


func load(asset_id: String) -> PackedByteArray:
	var path := _resolve_asset_path(asset_id)
	if path.is_empty() or not FileAccess.file_exists(path):
		return PackedByteArray()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	return file.get_buffer(file.get_length())


func exists(asset_id: String) -> bool:
	var path := _resolve_asset_path(asset_id)
	if path.is_empty():
		return false
	return FileAccess.file_exists(path)


func _resolve_asset_path(asset_id: String) -> String:
	var clean_id := asset_id.strip_edges().replace("\\", "/")
	if clean_id.is_empty():
		return ""
	if clean_id.contains(".."):
		return ""

	var project_id := "shared"
	var relative_path := clean_id

	if clean_id.contains("/"):
		project_id = clean_id.get_slice("/", 0).strip_edges()
		relative_path = clean_id.substr(project_id.length() + 1)
	elif clean_id.contains(":"):
		project_id = clean_id.get_slice(":", 0).strip_edges()
		relative_path = clean_id.substr(project_id.length() + 1)

	project_id = project_id.strip_edges()
	relative_path = relative_path.strip_edges()

	if project_id.is_empty() or relative_path.is_empty():
		return ""
	if relative_path.begins_with("/"):
		return ""
	if relative_path.contains(".."):
		return ""

	return "%s/%s/assets/%s" % [_projects_root, project_id, relative_path]


func _ensure_dir(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var result := DirAccess.make_dir_recursive_absolute(absolute)
	return result == OK or DirAccess.dir_exists_absolute(absolute)
