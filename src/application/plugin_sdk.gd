## Plugin SDK service.
## Validates plugin manifests and enforces declared port/tool boundaries.
## Requires manifests to be cryptographically signed with a trusted key.
class_name PluginSDK
extends RefCounted

var _declared_plugins: Dictionary = {}
var _signing_key: PackedByteArray


func setup(signing_key: PackedByteArray = PackedByteArray()) -> PluginSDK:
	_signing_key = signing_key
	_declared_plugins = {}
	return self


func register_plugin(manifest: PluginManifest) -> bool:
	if manifest == null:
		push_error("Plugin manifest cannot be null")
		return false

	if _declared_plugins.has(manifest.plugin_id):
		push_error("Plugin already registered: %s" % manifest.plugin_id)
		return false

	# Reject unsigned or tampered manifests
	if _signing_key.is_empty():
		push_error("PluginSDK: no signing key configured, cannot verify manifest: %s" % manifest.plugin_id)
		return false

	if not manifest.is_signed():
		push_error("Plugin manifest must be signed: %s" % manifest.plugin_id)
		return false

	if not manifest.verify_signature(_signing_key):
		push_error("Plugin manifest signature verification failed: %s" % manifest.plugin_id)
		return false

	_declared_plugins[manifest.plugin_id] = manifest
	return true

func can_access_port(plugin_id: String, port_name: String) -> bool:
	if not _declared_plugins.has(plugin_id):
		push_error("Plugin not registered: %s" % plugin_id)
		return false

	var manifest_variant: Variant = _declared_plugins[plugin_id]
	if not (manifest_variant is PluginManifest):
		push_error("Registered plugin manifest has invalid type: %s" % plugin_id)
		return false
	var manifest: PluginManifest = manifest_variant
	if not manifest.has_declared_port(port_name):
		push_error("Plugin %s cannot access undeclared port: %s" % [plugin_id, port_name])
		return false

	return true

func can_register_tool(plugin_id: String, tool_name: String) -> bool:
	if not _declared_plugins.has(plugin_id):
		push_error("Plugin not registered: %s" % plugin_id)
		return false

	var manifest_variant: Variant = _declared_plugins[plugin_id]
	if not (manifest_variant is PluginManifest):
		push_error("Registered plugin manifest has invalid type: %s" % plugin_id)
		return false
	var manifest: PluginManifest = manifest_variant
	if not manifest.has_declared_tool(tool_name):
		push_error("Plugin %s cannot register undeclared tool: %s" % [plugin_id, tool_name])
		return false

	return true

func get_registered_plugins() -> Array[PluginManifest]:
	var plugins: Array[PluginManifest] = []
	for plugin_id in _declared_plugins:
		var manifest_variant: Variant = _declared_plugins[plugin_id]
		if manifest_variant is PluginManifest:
			plugins.append(manifest_variant)
	return plugins
