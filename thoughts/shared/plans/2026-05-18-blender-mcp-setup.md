---
date: 2026-05-18
commit: 6d2590ed0687779532b44cc5ba7265e27c311ad6
branch: main
ticket: n/a
status: in_progress
---
# Plan: Enable Official Blender MCP Server for choyce-engine

## Summary
Install the official `lab/blender_mcp` toolchain on this macOS dev box and wire its MCP server into the choyce-engine repo as a Claude Code project-scoped MCP server (`.mcp.json`), so Claude Code running in this folder can drive a live Blender 5.1+ session.

## Source of Truth
- Landing page: https://www.blender.org/lab/mcp-server/
- Repo (Gitea): https://projects.blender.org/lab/blender_mcp
- Releases (add-on zip + .mcpb): https://projects.blender.org/lab/blender_mcp/releases
- Add-on zip (v1.0.0): https://projects.blender.org/lab/blender_mcp/releases/download/v1.0.0/mcp-1.0.0.zip
- Setup wiki: https://projects.blender.org/lab/blender_mcp/wiki/Setup
- llama.cpp wiring (reference): https://projects.blender.org/lab/blender_mcp/wiki/Llama.cpp

## Architecture (corrected from release inspection, 2026-05-18)
Three independent components:
1. **Blender add-on** (`mcp-1.0.0.zip`, 16 KB) — runs inside Blender 5.1+, binds a TCP socket on `localhost:9876` by default. Implements the Blender side of the Blender↔bridge protocol; **not** an MCP-speaking process.
2. **MCP stdio bridge** (`blender-1.0.0.mcpb`, 5.5 MB) — uv-runnable Python package `blmcp` with console script `blender-mcp = "blmcp:main"` (deps: `mcp[cli]>=1.2.0`, `docutils`, `pyyaml`). Speaks MCP over stdio to the client and TCP to the add-on. Env vars: `BLENDER_MCP_HOST` (default `localhost`), `BLENDER_MCP_PORT` (default `9876`), `BLENDER_PATH` (default `blender`). Defined in `blmcp/tools_helpers/connection.py`.
3. **LLM client** — Claude Code; spawns the bridge via stdio per `.mcp.json`.

`Claude Code  --stdio MCP-->  uvx blender-mcp  --TCP :9877-->  Blender add-on`

Original plan assumed the git repo `pyproject.toml` was the MCP server; in reality the `.mcpb` bundle IS the stdio MCP bridge and is the supported install artifact (includes a prebuilt `data/api/**/*.rst` corpus of the Blender Python API docs). No `git clone` needed.

Security: the server executes LLM-generated Python inside Blender with no sandbox. Don't open production `.blend` files; isolate to a scratch directory.

## Current Environment Findings
- `which blender` returns `/opt/homebrew/bin/blender`, but the symlink targets `/Applications/Blender.app/Contents/MacOS/Blender` which **does not exist**. The current install is broken.
- `uv` and `uvx` already present at `/Users/jakubsikora/.local/bin/{uv,uvx}`.
- No `.mcp.json` exists in repo. No prior Blender MCP plan or research doc.
- `thoughts/shared/plans/` exists with one prior plan.

---

## Phase 1: Install Blender 5.1+

### Changes
Reinstall Blender via Homebrew cask (existing brew shim dangling):
```bash
brew uninstall --cask --force blender 2>/dev/null
brew install --cask blender
/Applications/Blender.app/Contents/MacOS/Blender --version  # must report >= 5.1
```
If brew cask still ships a pre-5.1 build, fall back to the official `.dmg`: https://www.blender.org/download/

### Success Criteria
**Automated**
- [x] `/Applications/Blender.app/Contents/MacOS/Blender --version` prints `Blender 5.1.x` or higher — got **5.1.1**
- [x] `/opt/homebrew/bin/blender --version` succeeds (symlink resolves)

**Manual**
- [ ] Blender opens to a default scene without errors *(awaiting user verification)*

### Dependencies
- Requires: nothing
- Blocks: Phase 2, Phase 3

### Status: ✅ AUTOMATED CHECKS PASS — Blender 5.1.1 installed via brew cask (replaced dangling 5.0.0 shim).

---

## Phase 2: Install the Blender MCP Add-on

### Changes
1. Download the add-on zip:
   ```bash
   mkdir -p ~/Downloads/blender-mcp
   curl -L -o ~/Downloads/blender-mcp/mcp-1.0.0.zip \
     "https://projects.blender.org/lab/blender_mcp/releases/download/v1.0.0/mcp-1.0.0.zip"
   ```
2. Install inside Blender (one-time, GUI):
   - `Edit → Preferences → Get Extensions → ▾ menu → Install from Disk…`
   - Pick `~/Downloads/blender-mcp/mcp-1.0.0.zip`
   - Enable the **MCP** extension checkbox
   - Save preferences

   Alternative (drag-and-drop): drop the zip onto the Blender window **twice** — first call adds the Blender Lab repository, second call installs the add-on. This path also enables auto-update notifications.

3. **Change the add-on port to `9877`** in the extension preferences pane (avoids collision with TASK-062 `TestBridgeAdapter` which holds 9876 in the engine repo).

### Status: zip downloaded ✅ — GUI install pending user action.

Steps awaiting user:
- Open Blender, drag `~/Downloads/blender-mcp/mcp-1.0.0.zip` onto the window twice, OR use `Edit → Preferences → Get Extensions → ▾ → Install from Disk…`.
- Enable the **MCP** extension.
- In the MCP add-on preferences, set port to **9877** and click "Start Server" (or whatever the toggle is labelled).

### Success Criteria
**Automated**
- [ ] Add-on file present under `~/Library/Application Support/Blender/5.1/extensions/`
- [ ] `lsof -nP -iTCP:9877 -sTCP:LISTEN` shows Blender listening once the add-on server is on

**Manual**
- [ ] In Blender, the MCP add-on appears under `Preferences → Get Extensions` with status **Enabled**
- [ ] The add-on panel shows "Server running" on port 9877

### Dependencies
- Requires: Phase 1
- Blocks: Phase 4 *(only for end-to-end tool calls; `.mcp.json` file itself can be written without the add-on running)*

---

## Phase 3: Install the MCP stdio bridge from the `.mcpb` bundle  ✅ DONE

### Why .mcpb (not git clone)
`blender-1.0.0.mcpb` is a zip-packed `uv`-runnable Python project (`pyproject.toml` + `blmcp/` + prebuilt `data/api/**/*.rst` Blender Python API corpus). Cloning the git repo would require building that corpus from upstream Blender sources. The `.mcpb` is the published install artifact.

### Changes (executed 2026-05-18)
1. Downloaded `blender-1.0.0.mcpb` via `curl` from `projects.blender.org/lab/blender_mcp/releases/download/v1.0.0/blender-1.0.0.mcpb` (5.5 MB).
2. Unzipped to `~/Tools/blender-mcp/` (contents: `blmcp/`, `pyproject.toml`, `requirements.txt`, `uv.lock`, `manifest.json`, etc.).
3. Smoke-tested:
   ```bash
   uvx --from ~/Tools/blender-mcp blender-mcp --help
   ```
   uv built the project, installed 39 packages (incl. `pydantic-core`, `mcp[cli]>=1.2.0`), and printed usage with `--transport {stdio,http}` (default **stdio**). Exit 0.

### Verified
- ✅ `uvx --from ~/Tools/blender-mcp blender-mcp --help` exits 0 with usage
- ✅ Default transport = stdio (matches Claude Code's MCP client expectations)
- ✅ Bridge→Blender connection knobs are env vars `BLENDER_MCP_HOST`, `BLENDER_MCP_PORT` (source: `blmcp/tools_helpers/connection.py:20-28`)

### Dependencies
- Requires: nothing beyond `uvx` already on PATH
- Blocks: Phase 4 (config writing)

---

## Phase 4: Wire MCP Server into choyce-engine via `.mcp.json`

### Changes

**File:** `/Users/jakubsikora/Repos/choyce-engine/.mcp.json` (CREATE)
- **What:** project-scoped Claude Code MCP server config so any Claude Code session opened in this folder gets the Blender MCP tools.
- **Rationale:** user picked Claude Code project scope, not Claude Desktop / `.mcpb`.
- **Final config** (verified env var names against `blmcp/tools_helpers/connection.py`):
  ```json
  {
    "mcpServers": {
      "blender": {
        "command": "uvx",
        "args": ["--from", "/Users/jakubsikora/Tools/blender-mcp", "blender-mcp"],
        "env": {
          "BLENDER_MCP_HOST": "localhost",
          "BLENDER_MCP_PORT": "9877"
        }
      }
    }
  }
  ```

**File:** `.gitignore` (MODIFY, optional)
- Default: **commit** `.mcp.json` so teammates share the wiring. The file contains no secrets.

**File:** `CLAUDE.md` (MODIFY, optional follow-up)
- Add a short "Blender MCP" subsection pointing at the Setup wiki and noting the prerequisite: open Blender and toggle the add-on Server on before invoking blender tools.

### Success Criteria
**Automated**
- [ ] `claude mcp list` (in this folder) shows `blender` with status connected after starting Blender and the add-on server
- [ ] A trivial tool call (e.g., list scene objects) round-trips successfully

**Manual**
- [ ] In a fresh Claude Code session in `choyce-engine`, the model can call a Blender MCP tool against a scratch `.blend` file and read back results
- [ ] Disabling the add-on server makes the tool fail cleanly with a connection error (proves the wiring is real, not cached)

### Dependencies
- Requires: Phase 2, Phase 3
- Blocks: nothing

---

## Phase 5: Smoke Test & Documentation

### Changes
- Run one of the documented example prompts from blender.org/lab/mcp-server against a Blender benchmark scene (Classroom or Scattering Pebbles) end-to-end inside this Claude Code session.
- Optionally record the launch sequence in `thoughts/shared/notes/blender-mcp-quickstart.md`.

### Success Criteria
**Manual**
- [ ] At least one official example prompt produces the expected output
- [ ] Quickstart note exists if created

### Dependencies
- Requires: Phase 4

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Brew cask Blender < 5.1 | Med | High | Fallback to manual `.dmg` from blender.org |
| Gitea 403s prevent reading Setup wiki programmatically | High | Med | Open wiki in browser before Phase 3; record exact launch command before Phase 4 |
| Add-on TCP port collision (TASK-062 TestBridgeAdapter uses 9876) | Low | Med | Pick a non-9876 port in add-on prefs; document in `.mcp.json` env |
| LLM-generated Python deletes production `.blend` data | Med | High | Point Blender at a scratch directory only; never open production assets while server is running |
| `.mcp.json` committed with developer-specific absolute path | High | Low | Use `${HOME}` or document the path requirement in CLAUDE.md; alternatively gitignore `.mcp.json` and ship `.mcp.json.example` |

## Rollback Strategy
- Disable the add-on in Blender Preferences (instant, reversible).
- Remove the `blender` block from `.mcp.json` (or delete the file).
- `brew uninstall --cask blender` reverts Phase 1.
- `rm -rf ~/Tools/blender_mcp ~/Downloads/blender-mcp` cleans tool copies.

## File Ownership Summary
| File | Phase | Change |
|------|-------|--------|
| `/Applications/Blender.app` | 1 | Install (system) |
| `~/Library/Application Support/Blender/<ver>/extensions/mcp/` | 2 | Install (Blender) |
| `~/Tools/blender_mcp/` | 3 | Clone |
| `/Users/jakubsikora/Repos/choyce-engine/.mcp.json` | 4 | Create |
| `/Users/jakubsikora/Repos/choyce-engine/CLAUDE.md` | 4 | Modify (optional) |
| `/Users/jakubsikora/Repos/choyce-engine/thoughts/shared/notes/blender-mcp-quickstart.md` | 5 | Create (optional) |

## Open Questions for Reviewer
1. Commit `.mcp.json` (team-wide) or gitignore and ship `.mcp.json.example`?
2. Pick the add-on TCP port — anything other than 9876 (reserved by `TestBridgeAdapter`).
3. Scratch `.blend` workspace acceptable, or dedicated VM per the blender.org security warning?
