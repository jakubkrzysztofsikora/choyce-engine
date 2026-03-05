class_name PluginSDKTest
extends ApplicationTest

## Shared signing key for tests.
var _test_key: PackedByteArray


func _reset() -> void:
	_checks_run = 0
	_failures = []
	_test_key = "test-signing-key-for-plugin-sdk!".to_utf8_buffer()


func _make_signed_manifest(
	plugin_id: String,
	p_name: String,
	version: String,
	ports: Array[String],
	tools: Array[String]
) -> PluginManifest:
	var manifest := PluginManifest.new(plugin_id, p_name, version, ports, tools)
	manifest.sign_manifest(_test_key, "test-signer")
	return manifest


func run() -> Dictionary:
	_reset()
	test_register_valid_plugin()
	test_register_unsigned_plugin()
	test_register_duplicate_plugin()
	test_port_access_control()
	test_tool_registration_control()
	test_unregistered_plugin_access()
	test_get_registered_plugins()
	test_tampered_manifest_rejected()
	test_wrong_key_rejected()
	return _build_result("PluginSDK")


func test_register_valid_plugin() -> void:
	var sdk := PluginSDK.new().setup(_test_key)
	var manifest := _make_signed_manifest(
		"test_plugin", "Test Plugin", "1.0.0", ["LLMPort"], ["scene_editor"]
	)
	var result := sdk.register_plugin(manifest)
	_assert_true(result, "Signed plugin should register successfully")
	_assert_eq(sdk.get_registered_plugins().size(), 1, "Registered plugin count should be 1")


func test_register_unsigned_plugin() -> void:
	var sdk := PluginSDK.new().setup(_test_key)
	var manifest := PluginManifest.new(
		"unsigned_plugin", "Unsigned Plugin", "1.0.0", ["LLMPort"], ["scene_editor"]
	)
	var result := sdk.register_plugin(manifest)
	_assert_false(result, "Unsigned plugin should be rejected")
	_assert_eq(sdk.get_registered_plugins().size(), 0, "Unsigned plugin should not be registered")


func test_register_duplicate_plugin() -> void:
	var sdk := PluginSDK.new().setup(_test_key)
	var manifest1 := _make_signed_manifest(
		"dup_plugin", "Dup Plugin", "1.0.0", ["LLMPort"], ["scene_editor"]
	)
	var manifest2 := _make_signed_manifest(
		"dup_plugin", "Dup Plugin 2", "1.0.0", ["AssetRepositoryPort"], ["asset_importer"]
	)

	_assert_true(sdk.register_plugin(manifest1), "First registration should succeed")
	_assert_false(sdk.register_plugin(manifest2), "Duplicate plugin IDs should be rejected")


func test_port_access_control() -> void:
	var sdk := PluginSDK.new().setup(_test_key)
	var manifest := _make_signed_manifest(
		"access_plugin", "Access Plugin", "1.0.0", ["LLMPort"], ["scene_editor"]
	)
	_assert_true(sdk.register_plugin(manifest), "Plugin should register")
	_assert_true(sdk.can_access_port("access_plugin", "LLMPort"), "Declared port access should be allowed")
	_assert_false(
		sdk.can_access_port("access_plugin", "AssetRepositoryPort"),
		"Undeclared port access should be denied"
	)


func test_tool_registration_control() -> void:
	var sdk := PluginSDK.new().setup(_test_key)
	var manifest := _make_signed_manifest(
		"tool_plugin", "Tool Plugin", "1.0.0", ["LLMPort"], ["scene_editor"]
	)
	_assert_true(sdk.register_plugin(manifest), "Plugin should register")
	_assert_true(
		sdk.can_register_tool("tool_plugin", "scene_editor"),
		"Declared tool registration should be allowed"
	)
	_assert_false(
		sdk.can_register_tool("tool_plugin", "asset_importer"),
		"Undeclared tool registration should be denied"
	)


func test_unregistered_plugin_access() -> void:
	var sdk := PluginSDK.new().setup(_test_key)
	_assert_false(sdk.can_access_port("nonexistent", "LLMPort"), "Unregistered plugins cannot access ports")
	_assert_false(sdk.can_register_tool("nonexistent", "scene_editor"), "Unregistered plugins cannot register tools")


func test_get_registered_plugins() -> void:
	var sdk := PluginSDK.new().setup(_test_key)
	var manifest1 := _make_signed_manifest(
		"plugin1", "Plugin 1", "1.0.0", ["LLMPort"], ["tool1"]
	)
	var manifest2 := _make_signed_manifest(
		"plugin2", "Plugin 2", "1.0.0", ["AssetRepositoryPort"], ["tool2"]
	)

	_assert_true(sdk.register_plugin(manifest1), "First plugin should register")
	_assert_true(sdk.register_plugin(manifest2), "Second plugin should register")

	var plugins := sdk.get_registered_plugins()
	_assert_eq(plugins.size(), 2, "Should return all registered plugins")
	_assert_true(plugins[0] is PluginManifest, "Returned entries should be PluginManifest")
	_assert_true(plugins[1] is PluginManifest, "Returned entries should be PluginManifest")


func test_tampered_manifest_rejected() -> void:
	var sdk := PluginSDK.new().setup(_test_key)
	var manifest := _make_signed_manifest(
		"tamper_plugin", "Tamper Plugin", "1.0.0", ["LLMPort"], ["scene_editor"]
	)
	# Tamper after signing
	manifest.declared_ports.append("AssetRepositoryPort")
	var result := sdk.register_plugin(manifest)
	_assert_false(result, "Tampered manifest should be rejected")


func test_wrong_key_rejected() -> void:
	var wrong_key := "wrong-key-that-does-not-match!!".to_utf8_buffer()
	var sdk := PluginSDK.new().setup(wrong_key)
	var manifest := _make_signed_manifest(
		"wrongkey_plugin", "Wrong Key Plugin", "1.0.0", ["LLMPort"], ["scene_editor"]
	)
	var result := sdk.register_plugin(manifest)
	_assert_false(result, "Manifest signed with different key should be rejected")
