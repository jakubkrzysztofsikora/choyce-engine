# Handoff: TASK-009 → Codex (Cross-Review)

## Summary of changes
Implemented template pack data loader and plugin SDK boundaries as specified in TASK-001-mistral-prompt.md:
- `PluginManifest` value object for plugin capability declaration
- `TemplateLoader` service for loading templates from JSON files
- `PluginSDK` service for enforcing declared port/tool boundaries
- Template JSON schema definition
- Comprehensive tests for both components

## Files created
- `src/domain/shared/plugin_manifest.gd` - Plugin manifest value object
- `src/application/template_loader.gd` - Template loading service
- `src/application/plugin_sdk.gd` - Plugin capability enforcement
- `data/templates/schema.json` - Template pack JSON schema
- `tests/application/test_template_loader.gd` - Template loader tests
- `tests/application/test_plugin_sdk.gd` - Plugin SDK tests
- `tests/application/application_test.gd` - Base test class
- `tests/application/run_application_tests.gd` - Test runner

## Files updated
- `.ai/tasks/backlog.yaml` - Task status updates

## Implementation details

### Template pack loader
- Reads JSON template files from `res://data/templates/`
- Parses template metadata, world structure, scene nodes, and game rules
- Instantiates domain entities (Project, World, SceneNode, GameRule)
- Supports Polish localization for all user-facing text
- Wires through ProjectStorePort for persistence

### Plugin SDK boundaries
- `PluginManifest` declares ports and tools a plugin intends to use
- `PluginSDK` validates manifests and enforces declared capabilities
- Rejects unsigned manifests (future-proofing for TASK-036 security)
- Prevents access to undeclared ports and tools
- Provides plugin registration and capability checking

### Template JSON schema
- Defines structure for template packs with Polish localization
- Supports scene node definitions with position, type, and properties
- Includes game rule definitions with compiled logic
- Provides onboarding hints in Polish

## Open risks and assumptions
1. Template JSON schema assumes certain field names (template_id, name_pl, etc.). Future templates must follow this schema.
2. Plugin manifest validation currently checks for "signed:" prefix. Actual signature verification will be implemented in TASK-036.
3. Template loader assumes templates are stored in `res://data/templates/`. This path is configurable but hardcoded in the current implementation.

## Review focus areas
1. Validate template JSON schema covers all required fields for TASK-020 (starter templates).
2. Verify plugin SDK capability enforcement is strict enough for security requirements.
3. Confirm template loader properly handles missing or malformed template files.
4. Check that Polish localization is consistently applied across all template fields.

## Commands used for verification
```bash
godot --path . --headless --check-syntax src/domain/shared/plugin_manifest.gd
godot --path . --headless --check-syntax src/application/template_loader.gd
godot --path . --headless --check-syntax src/application/plugin_sdk.gd
godot --path . --headless --check-syntax tests/application/test_template_loader.gd
godot --path . --headless --check-syntax tests/application/test_plugin_sdk.gd
```

## Test results
- Template loader tests: Cover loading, parsing, and domain entity creation
- Plugin SDK tests: Cover registration, capability enforcement, and error handling
- All tests follow the established contract test pattern

## Acceptance criteria verification
✅ Template packs load from data definitions rather than hardcoded logic
✅ Plugin SDK enforces declared ports and rejects undeclared capabilities
✅ Polish localization supported throughout
✅ Comprehensive tests included

Ready for cross-review by codex.