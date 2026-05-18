class_name ShellNavigator
extends RefCounted

signal shell_changed(shell_id: String)
signal shell_changing(shell_id: String)

var _shells: Dictionary = {}
var _active_shell_id: String = ""
var _transition_callback: Callable


func register_shell(shell_id: String, shell_control: Control) -> void:
	_shells[shell_id] = shell_control


func set_transition_callback(callback: Callable) -> void:
	_transition_callback = callback


func show_shell(shell_id: String) -> void:
	if not _shells.has(shell_id):
		return

	shell_changing.emit(shell_id)

	if _transition_callback.is_valid():
		_transition_callback.call(_active_shell_id, shell_id)
	else:
		_instant_switch(shell_id)


func _instant_switch(shell_id: String) -> void:
	for key in _shells.keys():
		var shell_control: Control = _shells[key]
		shell_control.visible = key == shell_id

	_active_shell_id = shell_id
	shell_changed.emit(shell_id)


func get_active_shell_id() -> String:
	return _active_shell_id


func get_shell(shell_id: String) -> Control:
	return _shells.get(shell_id, null)
