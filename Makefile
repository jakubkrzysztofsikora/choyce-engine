# choyce-engine top-level Makefile.
#
# Currently exposes only the first-run asset bulk-download target. Other
# project workflows (Godot run, tests, lints) continue to live under
# scripts/ and are not wrapped here yet.

SHELL := /bin/sh

.PHONY: assets assets-dry-run assets-force help

help:
	@echo "Targets:"
	@echo "  assets         - download + extract free-asset packs (scripts/assets/manifest.yaml)"
	@echo "  assets-dry-run - list what 'assets' WOULD download without touching disk"
	@echo "  assets-force   - re-download every pack even if already marked complete"

assets:
	@scripts/assets/fetch_free_assets.sh

assets-dry-run:
	@scripts/assets/fetch_free_assets.sh --dry-run

assets-force:
	@scripts/assets/fetch_free_assets.sh --force
