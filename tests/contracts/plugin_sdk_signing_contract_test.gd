class_name PluginSDKSigningContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	var key := "plugin-signing-key-32-bytes!!!!".to_utf8_buffer()
	var wrong_key := "wrong-signing-key-for-testing!!".to_utf8_buffer()

	# 1. Signed manifest registers successfully
	var sdk := PluginSDK.new().setup(key)
	var manifest := PluginManifest.new(
		"signed-plugin", "Safe Plugin", "1.0.0",
		["LLMPort", "ModerationPort"], ["scene_editor"]
	)
	manifest.sign_manifest(key, "engine", "2026-03-02T19:00:00Z")
	_assert_true(
		sdk.register_plugin(manifest),
		"Properly signed manifest should register"
	)

	# 2. Unsigned manifest rejected
	var sdk2 := PluginSDK.new().setup(key)
	var unsigned := PluginManifest.new(
		"unsigned-plugin", "Unsafe Plugin", "1.0.0",
		["LLMPort"], ["scene_editor"]
	)
	_assert_true(
		not sdk2.register_plugin(unsigned),
		"Unsigned manifest should be rejected"
	)

	# 3. Manifest signed with wrong key rejected
	var sdk3 := PluginSDK.new().setup(key)
	var wrong_signed := PluginManifest.new(
		"wrong-key-plugin", "Wrong Key", "1.0.0",
		["LLMPort"], ["scene_editor"]
	)
	wrong_signed.sign_manifest(wrong_key, "attacker")
	_assert_true(
		not sdk3.register_plugin(wrong_signed),
		"Manifest signed with wrong key should be rejected"
	)

	# 4. Tampered manifest rejected (ports changed after signing)
	var sdk4 := PluginSDK.new().setup(key)
	var tampered := PluginManifest.new(
		"tampered-plugin", "Tampered", "1.0.0",
		["LLMPort"], ["scene_editor"]
	)
	tampered.sign_manifest(key, "engine")
	tampered.declared_ports.append("AssetRepositoryPort")
	_assert_true(
		not sdk4.register_plugin(tampered),
		"Tampered manifest should be rejected"
	)

	# 5. Tampered manifest rejected (tools changed after signing)
	var sdk5 := PluginSDK.new().setup(key)
	var tool_tamper := PluginManifest.new(
		"tool-tamper-plugin", "Tool Tamper", "1.0.0",
		["LLMPort"], ["scene_editor"]
	)
	tool_tamper.sign_manifest(key, "engine")
	tool_tamper.declared_tools.append("dangerous_tool")
	_assert_true(
		not sdk5.register_plugin(tool_tamper),
		"Manifest with tampered tools should be rejected"
	)

	# 6. Tampered manifest rejected (name changed after signing)
	var sdk6 := PluginSDK.new().setup(key)
	var name_tamper := PluginManifest.new(
		"name-tamper-plugin", "Original Name", "1.0.0",
		["LLMPort"], ["scene_editor"]
	)
	name_tamper.sign_manifest(key, "engine")
	name_tamper.name = "Malicious Name"
	_assert_true(
		not sdk6.register_plugin(name_tamper),
		"Manifest with tampered name should be rejected"
	)

	# 7. SDK without signing key rejects all manifests
	var no_key_sdk := PluginSDK.new().setup(PackedByteArray())
	var good_manifest := PluginManifest.new(
		"good-plugin", "Good", "1.0.0",
		["LLMPort"], ["scene_editor"]
	)
	good_manifest.sign_manifest(key, "engine")
	_assert_true(
		not no_key_sdk.register_plugin(good_manifest),
		"SDK without signing key should reject all manifests"
	)

	# 8. Null manifest rejected
	var sdk8 := PluginSDK.new().setup(key)
	_assert_true(
		not sdk8.register_plugin(null),
		"Null manifest should be rejected"
	)

	# 9. Port access still works for properly signed plugin
	_assert_true(
		sdk.can_access_port("signed-plugin", "LLMPort"),
		"Signed plugin should access declared port"
	)
	_assert_true(
		sdk.can_access_port("signed-plugin", "ModerationPort"),
		"Signed plugin should access second declared port"
	)
	_assert_true(
		not sdk.can_access_port("signed-plugin", "AssetRepositoryPort"),
		"Signed plugin should not access undeclared port"
	)

	# 10. Tool registration still works for properly signed plugin
	_assert_true(
		sdk.can_register_tool("signed-plugin", "scene_editor"),
		"Signed plugin should register declared tool"
	)
	_assert_true(
		not sdk.can_register_tool("signed-plugin", "undeclared_tool"),
		"Signed plugin should not register undeclared tool"
	)

	# 11. PluginManifest.to_signable_json() is deterministic (port order)
	var m1 := PluginManifest.new("p", "N", "1.0", ["B", "A"], ["t"])
	var m2 := PluginManifest.new("p", "N", "1.0", ["A", "B"], ["t"])
	_assert_true(
		m1.to_signable_json() == m2.to_signable_json(),
		"Signable JSON should be deterministic regardless of port order"
	)

	# 12. PluginManifest.is_signed() / verify_signature() work
	var check_m := PluginManifest.new("c", "Check", "1.0", ["LLMPort"], ["t"])
	_assert_true(not check_m.is_signed(), "Unsigned manifest should report not signed")
	check_m.sign_manifest(key, "engine")
	_assert_true(check_m.is_signed(), "Signed manifest should report signed")
	_assert_true(
		check_m.verify_signature(key),
		"verify_signature should return true with correct key"
	)
	_assert_true(
		not check_m.verify_signature(wrong_key),
		"verify_signature should return false with wrong key"
	)

	return _build_result("PluginSDKSigning")
