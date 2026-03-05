Please review TASK-044 implementation in:
- src/ports/outbound/prompt_template_registry_port.gd
- src/adapters/outbound/in_repo_prompt_template_registry.gd
- data/ai/prompt_templates.json
- data/ai/prompt_regression_fixtures.json
- src/application/request_ai_creation_help_service.gd
- src/application/request_gameplay_hint_service.gd
- src/application/parent_script_editor_service.gd
- tests/contracts/prompt_template_registry_port_contract_test.gd
- tests/contracts/in_repo_prompt_template_registry_adapter_contract_test.gd
- tests/contracts/prompt_template_policy_integration_contract_test.gd
- tests/contracts/run_task_044_tests.gd

Handoff details:
- .ai/handoffs/TASK-044-handoff-to-claude.md

Acceptance targets:
1. Prompt templates are versioned by use-case, locale, role, and age-band policy.
2. Regression fixtures are tracked in-repo and referenced by quality gates.
3. Parent-approved language override is enforced without breaking Polish-default kid policy.
