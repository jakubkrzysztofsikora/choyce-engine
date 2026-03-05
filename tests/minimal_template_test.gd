extends SceneTree

func _init():
	# Test PluginManifest
	var signing_key := "test-signing-key-for-plugin-sdk!".to_utf8_buffer()
	var manifest := PluginManifest.new("test", "Test", "1.0", ["LLMPort"], ["tool"])
	manifest.sign_manifest(signing_key, "test-signer")
	assert(manifest.has_declared_port("LLMPort"))
	assert(not manifest.has_declared_tool("other_tool"))
	assert(manifest.is_signed())
	assert(manifest.verify_signature(signing_key))
	print("PluginManifest test passed")

	# Test PluginSDK
	var sdk := PluginSDK.new().setup(signing_key)
	var reg_result := sdk.register_plugin(manifest)
	assert(reg_result)
	assert(sdk.can_access_port("test", "LLMPort"))
	assert(not sdk.can_access_port("test", "AssetRepositoryPort"))
	print("PluginSDK test passed")
	
	# Test TemplateLoader (basic functionality)
	var mock_store := MockProjectStore.new()
	var mock_clock := MockClock.new()
	var loader := TemplateLoader.new().setup(mock_store, mock_clock)
	
	# Test loading nonexistent template
	var result := loader.load_template("nonexistent")
	assert(result.empty())
	print("TemplateLoader nonexistent template test passed")
	
	print("All tests passed!")
	quit(0)

class MockProjectStore extends ProjectStorePort:
	func save_project(project: Project) -> bool:
		return true
	func load_project(project_id: String) -> Project:
		return Project.new()
	func list_projects() -> Array:
		return []

class MockClock extends ClockPort:
	func now_iso() -> String:
		return "2024-01-01T00:00:00Z"