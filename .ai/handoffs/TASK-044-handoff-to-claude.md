# Handoff: TASK-044 -> Claude (Cross-Review)

## Summary
Implemented a versioned prompt template registry with in-repo fixtures and wired it into core AI prompt-building paths so templates resolve by use-case, locale, role, and age-band, while preserving Polish-first kid defaults and parent override behavior.

## Files created
- `src/ports/outbound/prompt_template_registry_port.gd`
- `src/adapters/outbound/in_repo_prompt_template_registry.gd`
- `data/ai/prompt_templates.json`
- `data/ai/prompt_regression_fixtures.json`
- `tests/contracts/prompt_template_registry_port_contract_test.gd`
- `tests/contracts/in_repo_prompt_template_registry_adapter_contract_test.gd`
- `tests/contracts/prompt_template_policy_integration_contract_test.gd`
- `tests/contracts/run_task_044_tests.gd`

## Files updated
- `src/application/request_ai_creation_help_service.gd`
- `src/application/request_gameplay_hint_service.gd`
- `src/application/parent_script_editor_service.gd`
- `tests/contracts/run_contract_tests.gd`
- `tests/contracts/README.md`
- `src/domain/CONTEXT_MAP.md`

## Implementation details
1. New prompt-registry outbound port
- `PromptTemplateRegistryPort` defines:
  - `resolve_template(use_case, locale, role, age_band, version="latest")`
  - `list_versions(use_case)`
  - `get_regression_fixtures(use_case="")`

2. In-repo adapter with versioned selection logic
- `InRepoPromptTemplateRegistry` loads templates + fixtures from JSON.
- Resolution logic:
  - scores candidates by locale/role/age-band compatibility,
  - chooses newest semantic version among best-compatible templates,
  - enforces Polish locale for kid/child age-band requests,
  - supports explicit version pinning.

3. Versioned prompt datasets + regression fixtures
- `data/ai/prompt_templates.json`
  - use-case templates for creation help, creation explain, gameplay hints, and parent script prompts,
  - locale variants (`pl-PL`, selected `en-US` parent templates),
  - versioned entries (including `1.1.0` kid creation template).
- `data/ai/prompt_regression_fixtures.json`
  - tracked fixtures for use by quality-gate suites.

4. Service integration
- `RequestAICreationHelpService` now optionally consumes registry templates for:
  - `ai_creation_help`
  - `ai_creation_explain`
- `RequestGameplayHintService` now optionally consumes registry templates for `gameplay_hint`.
- `ParentScriptEditorService` now optionally consumes registry templates for:
  - `parent_script_explain`
  - `parent_script_refactor`
- Existing behavior remains intact when registry is not injected (fallback prompts preserved).

5. Test coverage
- Added contracts for port + adapter behavior.
- Added integration contract verifying:
  - kid path remains Polish by default,
  - parent language override path uses non-Polish templates when policy allows,
  - prompt content reflects resolved templates.

## Validation
Executed focused suite:
```bash
godot4 --headless --path . --script tests/contracts/run_task_044_tests.gd
```
Result:
- `Tests: 3`
- `Checks: 27`
- `Failed tests: 0`

Regression check:
```bash
godot4 --headless --path . --script tests/contracts/run_task_032_tests.gd
```
Result:
- `Tests: 4`
- `Checks: 51`
- `Failed tests: 0`

## Acceptance mapping
1. Prompt templates versioned by use-case, locale, role, age-band:
- Implemented in `PromptTemplateRegistryPort` + `InRepoPromptTemplateRegistry` + `data/ai/prompt_templates.json`.

2. Regression fixtures tracked in repo and referenced by quality gates:
- Implemented in `data/ai/prompt_regression_fixtures.json` + `get_regression_fixtures(...)` + new contract coverage.

3. Parent-approved language override enforced without breaking Polish-default kid policy:
- Verified through integration contract (`PromptTemplatePolicyIntegration`) and service wiring through existing language-policy decisions.

## Review focus
1. Template resolution precedence (compatibility first, then newest version).
2. Kid Polish-default enforcement in adapter and integration behavior.
3. Backward compatibility for services when template registry is omitted.
4. Fixture structure suitability for future CI prompt-regression gates.
