class_name OSEnvironmentAdapter
extends EnvironmentPort

## Production adapter for EnvironmentPort.
## Wraps OS.get_environment() — the only place in src/ outside src/adapters/
## that may call this Godot singleton.

func get_env(key: String, default_value: String = "") -> String:
	var v := OS.get_environment(key)
	return v if not v.is_empty() else default_value
