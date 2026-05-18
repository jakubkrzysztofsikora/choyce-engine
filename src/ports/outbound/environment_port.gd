class_name EnvironmentPort
extends RefCounted

## Outbound port for reading process environment variables.
## Decouples application and domain layers from the OS singleton.
## Default implementation returns the supplied default_value — safe for tests.

func get_env(key: String, default_value: String = "") -> String:
	return default_value
