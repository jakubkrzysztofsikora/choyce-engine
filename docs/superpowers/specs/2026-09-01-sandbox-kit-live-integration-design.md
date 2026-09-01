# Sandbox Kit Live Integration Design

## Goal

Make the migrated rpg-asserts sandbox visibly playable from the normal Choyce launch flow, fix its actual mouse-look route, and prove the player is in the enhanced graphics and mechanics runtime.

## Problem Statement

The project contains two runnable third-person stacks.

| Stack | Entry condition | Player controller | Player-visible state |
| --- | --- | --- | --- |
| Adventure | Any non-`sandbox_kit` world | `src/adapters/inbound/gameplay/player_controller.gd` | Existing Adventure renderer, NPC/crafting/combat stack |
| Sandbox Kit | A world whose `theme == "sandbox_kit"` | `gameplay/player/sandbox_player.gd` | Shared World3D, graphics tiers, stylized props, build modes, grab/throw, FX pool |

`GameplayRuntime.start_session()` chooses the Sandbox Kit only at `world.theme == SANDBOX_KIT_THEME`. The seeded kit project is named `starter_sandbox_kit` and titled `Piaskownica`, but the Play shell does not make its enhanced mechanics visually distinct or make it the default play destination. A player entering Adventure will therefore see none of the kit's rendering and gameplay systems.

The previous mouse recapture fix changed the Adventure controller. The Sandbox Kit player owns the active mouse route for the enhanced world and currently rotates only while `Input.mouse_mode == Input.MOUSE_MODE_CAPTURED`; after Escape releases capture, no empty-world click recaptures it. This is the live cause of mouse look failing in the Kit route.

## User Experience

The default child-facing play action opens **Piaskownica: Buduj i Baw Się** when a starter Sandbox Kit world exists. The opening frame must clearly communicate the active mode with a compact HUD ribbon that lists the three player-visible mechanics: `Buduj`, `Chwyć`, and `Rzuć`. This replaces ambiguity with proof that the enhanced route is running without hiding the existing Adventure, Farm, or City worlds.

Escape releases the cursor for the visible `Wróć` button. A left click on empty 3D space recaptures the cursor and resumes look; that first click cannot place, grab, throw, or attack. GUI controls keep normal priority because only events reaching `_unhandled_input` are treated as world input.

The initial sandbox scene retains its authored procedural sky, AGX tone mapping, glow, SSAO, fog, directional shadows, and graphics tier profile. Its HUD should expose the current quality tier and active player count in a non-debug, child-readable form rather than a technical setting panel.

## Architecture

Keep `GameplayRuntime` as the composition root. It already owns the safe mount and teardown contract for the Kit: `SplitScreenManager`, `SandboxKitBridge`, `SandboxPersistenceService`, event-bus updates, player limits, build budgets, and session end. The work must not bypass that bridge or introduce a second save format.

`PlayShell` remains the world picker. It selects the Sandbox Kit project by default only when the active world has not been chosen by the user; explicit selection of Adventure/Farm/City always wins. A small template-specific presentation model supplies the card title, icon, primary status, and feature ribbon, avoiding theme-specific conditionals scattered across controls.

`SandboxPlayer` receives a local input state transition only. Its P1 mouse button handler captures the cursor when visible and returns before any gameplay action. Mouse motion then follows its existing yaw/pitch logic. Gamepad-controlled players continue to ignore raw mouse input.

## Boundaries and Safety

- The Kit continues to persist only through `SandboxKitBridge` and `SandboxPersistenceService`; `SaveSystem` remains an internal Kit implementation detail.
- Apply existing parental player and block caps before joining players. No new free-form AI, chat, or network path is introduced.
- Do not make the kit's build, grab, or throw actions destructive outside its existing physics/world masks.
- The first recapture click must be inert. HUD controls consume input before player `_unhandled_input` runs.
- Adventure's NPC, crafting, gathering, combat, vehicle, and save paths remain unchanged in this integration slice.

## Acceptance Criteria

1. A first-run or unselected Play session chooses the seeded Sandbox Kit world as its primary play target, while all starter worlds remain selectable.
2. The active Kit session visibly shows a mode ribbon and its player count/quality presentation, and renders through its existing graphics profile.
3. In a real windowed Godot session, Escape then a left click on empty Kit world space recaptures the pointer, subsequent mouse motion changes Kit camera yaw, and the recapture click has no gameplay side effect.
4. Keyboard and controller Kit controls keep their existing per-device isolation; P2 and later players cannot receive P1 raw mouse input.
5. Existing `SandboxKitBridge` persistence, roster cap, block cap, and clean teardown regressions remain green.
6. Adventure remains reachable and its separate gameplay loop is not changed by selecting the Kit as the default entry.

## Verification

- Deterministic headless tests cover default world selection, Kit presentation model, inert recapture transition, player-device isolation, and bridge persistence.
- A windowed Godot integration test covers actual OS pointer capture and camera yaw, since the headless backend cannot capture the macOS cursor.
- A focused live smoke run starts the default Play action, records the active world theme, verifies the Kit stage and graphics profile nodes exist, then returns through the visible exit button.
- Cross-agent review checks the input ordering, safety caps, save boundary, and child-facing affordances before merge.

## Non-Goals

- Replacing Adventure's NPC/crafting/combat/vehicle systems with Kit equivalents.
- Moving graphics settings into a persistent parent-facing configuration UI.
- Adding new remote AI, online multiplayer, or unbounded user-generated content.
