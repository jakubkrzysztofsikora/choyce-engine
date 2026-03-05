class_name ShellNavigator
extends RefCounted

signal shell_changed(shell_id: String)

var _shells: Dictionary = {}
var _active_shell_id: String = ""


func register_shell(shell_id: String, shell_control: Control) -> void:
	_shells[shell_id] = shell_control


func show_shell(shell_id: String) -> void:
	if not _shells.has(shell_id):
		return

	for key in _shells.keys():
		var shell_control: Control = _shells[key]
		shell_control.visible = key == shell_id

	_active_shell_id = shell_id
	shell_changed.emit(shell_id)


func get_active_shell_id() -> String:
	return _active_shell_id
