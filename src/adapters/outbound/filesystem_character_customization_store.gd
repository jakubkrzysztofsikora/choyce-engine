## Filesystem-backed store for character customization. Complies with hexagonal
## architecture domain isolation constraints.
class_name FilesystemCharacterCustomizationStore
extends RefCounted

const PERSIST_PATH := "user://character_customization.json"


static func load_customization() -> CharacterCustomization:
	if not FileAccess.file_exists(PERSIST_PATH):
		return CharacterCustomization.new().clamp_in_place()
	var file := FileAccess.open(PERSIST_PATH, FileAccess.READ)
	if file == null:
		return CharacterCustomization.new().clamp_in_place()
	var raw := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return CharacterCustomization.new().clamp_in_place()
	return CharacterCustomization.from_dict(parsed as Dictionary)


static func save_customization(customization: CharacterCustomization) -> bool:
	if customization == null:
		return false
	var file := FileAccess.open(PERSIST_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(customization.to_dict(), "  "))
	file.close()
	return true
