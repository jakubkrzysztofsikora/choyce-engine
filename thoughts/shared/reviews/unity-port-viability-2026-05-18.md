---
date: 2026-05-18
reviewer: unity-port
commit: 68d73a3
status: complete
---
# Review: Unity Port Viability

## Summary
The hexagonal architecture provides a structurally sound skeleton for porting: domain types extend `RefCounted` (not `Node`), ports are pure interfaces, and adapters isolate engine APIs. However, Unity porting would require replacing every Godot primitive type used in domain/application code (`Vector3`, `PackedByteArray`, `Callable`, `Dictionary`, `HMACContext`, `Time`, `JSON`, `String.sha256_text()`), rewriting the entire DI/composition-root mechanism (Godot-specific `preload`, `@onready`, `call_deferred`, `WorkerThreadPool`), and extracting 5 application services that bypass ports and call Godot filesystem APIs directly. The single sharpest finding: cryptographic primitives (`HMACContext`, `AESContext`, `HashingContext`, `.sha256_text()`) are deeply embedded in domain types (`ManifestSignature`, `RoleToken`, `AuditRecord`) and cannot be swapped without touching those files.

## Findings (severity-ranked)

### Critical (blocks porting entirely)

- **C-01: Cryptographic Godot APIs baked into domain types.** `ManifestSignature` (domain/shared), `RoleToken` (domain/identity_safety), and `AuditRecord` (domain/shared) directly instantiate `HMACContext`, call `.sha256_text()`, and reference `HashingContext.HASH_SHA256`. These are Godot class singletons with no Unity/C# equivalent in the standard library. A Unity port would need to either (a) introduce a `CryptoPort` abstraction and refactor every domain type to depend on it, or (b) rewrite all crypto in pure C# and lose GDScript parity. Three domain files affected, 112 `push_error`/`push_warning` calls across ports+domain also have no Unity equivalent.
  - `src/domain/shared/manifest_signature.gd:72-82` — `HMACContext.new()`, `HashingContext.HASH_SHA256`
  - `src/domain/identity_safety/role_token.gd:118-119` — same pattern
  - `src/domain/shared/audit_record.gd:49` — `JSON.stringify()`, `String.sha256_text()`
  - `src/domain/shared/provenance_data.gd:29` — `Time.get_unix_time_from_system()` in constructor

- **C-02: `Vector3` used as a first-class domain type in `SceneNode`.** The `SceneNode` entity stores `position: Vector3`, `rotation: Vector3`, `scale: Vector3`. Unity has `Vector3` too, but the Godot coordinate system (Y-up, right-handed) differs from Unity (Y-up, left-handed). Direct serialization of `Vector3` via `str()` or dict round-trips will produce wrong coordinates on Unity. The domain comment says "Framework-agnostic: uses Vector3 as a basic math type" but this is false — `Vector3.ZERO`, `Vector3.ONE` are Godot class constants, not pure math.
  - `src/domain/world_authoring/scene_node.gd:20-22,33-35`

- **C-03: `Callable` is Godot-specific and used in the `LLMPort` contract.** The `complete()` method signature takes `Callable` parameters for `on_token` and `on_done`. C# has `Action<T>` / `Func<T>` but these are not structurally equivalent. Every port method that accepts `Callable` would need a C# delegate equivalent, and every application service that constructs lambdas via `func():` syntax needs rewriting. The `EventBus` also stores `Array[Callable]` for subscribers.
  - `src/ports/outbound/llm_port.gd:28-29`
  - `src/domain/events/event_bus.gd:7,24,42,52,66`

### High (significant porting effort, architecture-level)

- **H-01: Five application services bypass ports and call Godot filesystem APIs directly.** `BrowseContentService` opens `DirAccess.open("res://data/templates/")` and iterates files. `CloneWorldService` uses `Time.get_ticks_msec()` and `randi()` for ID generation. `TemplateLoader` calls `FileAccess.open()`. `AIRateLimiter` uses `Time.get_ticks_msec()`. `UsabilityKPIReportingService` calls `Time.get_date_string_from_system()`. These bypass the port layer and would silently break in Unity.
  - `src/application/browse_content_service.gd:24-30`
  - `src/application/clone_world_service.gd:86,91,96`
  - `src/application/template_loader.gd:16`
  - `src/application/ai_rate_limiter.gd:20,32`
  - `src/application/usability_kpi_reporting_service.gd:14`

- **H-02: Composition root is entirely Godot-specific.** `main.gd` uses `extends Control`, `@onready`, `preload()`, `signal`, `$NodePath` syntax, `call_deferred()`, `WorkerThreadPool.add_task()`, `StyleBoxFlat`, `Tween`, `create_tween()`, `ProjectSettings.globalize_path()`, `DirAccess.make_dir_recursive_absolute()`, `FileAccess.open()`, `Crypto.new()`, `OS.has_feature()`, `OS.crash()`, `Engine.get_main_loop()`, and `NOTIFICATION_WM_CLOSE_REQUEST`. The entire 960-line file must be rewritten from scratch for Unity. This is expected (composition root is an adapter), but the sheer density means the port has a single point of failure.
  - `src/adapters/inbound/main.gd` (entire file)

- **H-03: `EncryptedStoragePort` signature uses `PackedByteArray` — no C# equivalent.** The port interface itself uses `PackedByteArray` for key and data parameters. Unity/C# would use `byte[]`, but this means every port that touches binary data (`AssetRepositoryPort`, `EncryptedStoragePort`) has a Godot type in its signature. Porting requires changing the port interface, which breaks every adapter.
  - `src/ports/outbound/encrypted_storage_port.gd:11-13,20-22`
  - `src/ports/outbound/asset_repository_port.gd:12`

- **H-04: OllamaLLMAdapter creates a hidden Godot Node (`_OllamaHelperNode`).** The adapter spawns a `Node` subclass at runtime (`_OllamaHelperNode extends Node`) to own an `HTTPRequest` node. Unity's equivalent would be a `MonoBehaviour` or `GameObject`, but the adapter does this lazily and attaches to the scene root as a side effect. The entire HTTP transport layer is Godot-specific.
  - `src/adapters/outbound/ollama_llm_adapter.gd:690-764`

- **H-05: `push_error()` / `push_warning()` used 112 times in ports+domain as error reporting.** Unity has `Debug.LogError()` but these are scattered throughout every base class default implementation. A systematic replacement is needed.
  - All port files use `push_error()` in default method bodies.

### Medium (porting effort, non-architectural)

- **M-01: `.hash()` used for ID generation in 7 application services.** `String.hash()` in Godot returns a non-cryptographic 32-bit FNV-1a hash. Unity's `string.GetHashCode()` is different and not stable across .NET versions. All generated IDs (`"world_%s_%d" % [Time.get_ticks_msec(), randi()]`, `"mut_%d" % absi(seed.hash())`) would produce different values on Unity, breaking any cross-platform data compatibility.
  - `src/application/clone_world_service.gd:86,91,96`
  - `src/application/ai_failsafe_controller.gd:41`
  - `src/application/parent_script_editor_service.gd:229`
  - `src/application/audio_governance_service.gd:321,374`
  - `src/application/ai_memory_layer_service.gd:198`
  - `src/application/visual_asset_generation_service.gd:117,271,303,363`
  - `src/application/deterministic_tool_execution_gateway.gd:148`
  - `src/application/voice_input_moderation_service.gd:120`

- **M-02: `Dictionary` and `Array` are Godot-typed containers, not C# `Dictionary<TKey,TValue>` / `List<T>`.** GDScript `Dictionary` is untyped and can hold mixed values. C# `Dictionary<string, object>` would work but loses the GDScript interop layer. Every domain event, port method, and adapter uses `Dictionary` as a universal data bag. Porting would need to decide: keep untyped dicts (fragile) or define typed DTOs (massive effort).
  - Every file in `src/domain/events/`, every port method with `Dictionary` params.

- **M-03: `RefCounted` as base class has no Unity equivalent.** All domain types, ports, and application services extend `RefCounted`. Unity/C# has `IDisposable` / reference semantics but no reference-counted base. This is cosmetic (C# classes are reference types by default), but the `extends RefCounted` declaration appears 70+ times and every one must be removed.
  - All files in `src/domain/`, `src/application/`, `src/ports/`

- **M-04: Duck-typing via `has_method()` in 14 call sites.** `main.gd` calls `port.has_method("flush_if_due")` and `port.has_method("flush")` instead of checking against a `Flushable` interface. Unity/C# has no `has_method` — you'd need actual interface checks (`is IFlushable`) or null-pattern. The `RequestAICreationHelpService` calls `_llm.has_method("complete_with_tools_sync")` — a type check that should be on the port contract.
  - `src/adapters/inbound/main.gd:94,103,105`
  - `src/application/request_ai_creation_help_service.gd:200`
  - `src/application/parent_script_editor_service.gd:288`
  - `src/application/request_gameplay_hint_service.gd:294`
  - `src/application/visual_asset_generation_service.gd:236`

- **M-05: `JSON.stringify()` / `JSON.parse_string()` used for all serialization.** Unity has `JsonUtility` or Newtonsoft.Json, but the API surface differs. Every `to_dict()` / `from_dict()` pattern would need rewriting.
  - `src/domain/shared/audit_record.gd:49,115`
  - `src/domain/shared/plugin_manifest.gd:43`
  - `src/application/feature_flag_service.gd:49`
  - `src/application/template_loader.gd:24`

- **M-06: `AuditRecord._extract_payload()` uses `get_property_list()` reflection.** Godot's `Object.get_property_list()` returns runtime property metadata. Unity's C# reflection (`GetType().GetProperties()`) is structurally different. The payload extraction logic must be rewritten per-event-type.
  - `src/domain/shared/audit_record.gd:76-96`

- **M-07: `DeploymentConfig.from_environment()` falls back to `OSEnvironmentAdapter.new()` when passed null.** This couples the application config to a concrete adapter instead of requiring explicit injection. A Unity build would silently instantiate the Godot adapter.
  - `src/application/deployment_config.gd:26`

### Low / nits

- **L-01: 36 uses of Godot-specific String methods in domain layer.** `.strip_edges()`, `.is_empty()`, `.begins_with()`, `.to_lower()`, `.get_base_dir()`, `.path_join()`, `.hex_decode()`, `.to_utf8_buffer()` are Godot `String` methods. C# has equivalent methods but with different names (`Trim()`, `IsNullOrEmpty()`, `StartsWith()`, `ToLower()`, `Path.GetDirectoryName()`, `Path.Combine()`, etc.). Mechanical but tedious.

- **L-02: `preload()` in `main.gd` for `IconFont` and `ShellTransition`.** These are compile-time resource loads. Unity's equivalent is `Resources.Load<T>()` or addressable assets, but the `const` preload pattern is Godot-specific.
  - `src/adapters/inbound/main.gd:4-5`

- **L-03: `maxi()` used in `EventBus._init()`.** Godot global function, not available in C#. Replaceable with `max()`.
  - `src/domain/events/event_bus.gd:20`

- **L-04: No test coverage for Unity-equivalent serialization round-trips.** All `to_dict()` / `from_dict()` pairs are tested with GDScript `Dictionary` which preserves insertion order. C# `Dictionary<TKey,TValue>` does not guarantee order, which could break hash-chain integrity in `AuditRecord`.

- **L-05: `Color` and `Color8` used in `main.gd` theming.** Pure adapter concern, but the `Color(r,g,b,a)` constructor differs between engines.
  - `src/adapters/inbound/main.gd:83,810-814`

## Manual test log
- Code-level review only. No Godot runtime available in this worktree.
- Parsed 48 domain files, 42 application files, 49 port files, 65 adapter files.
- Grep-scanned for: `extends Node/Control`, `@onready`, Godot singleton APIs, `preload`, `Callable`, `signal`, `Vector3`, `PackedByteArray`, `HMACContext`, `AESContext`, `HashingContext`, `Crypto`, `FileAccess`, `DirAccess`, `OS.`, `Time.`, `JSON.`, `WorkerThreadPool`, `HTTPRequest`, `HTTPClient`, `Mutex`, `Thread`, `.hash()`, `.sha256_text()`, `randi()`, `has_method(`, `ProjectSettings`, `Engine.`, `push_error`, `push_warning`.
- Verification gap: no parse-clean check, no runtime boot, no E2E flow. All findings are static analysis.

## Recommendations (prioritized punch list)

1. **Introduce `CryptoPort`** (outbound) with `sha256(data: String) -> String`, `hmac_sha256(data, key) -> String`, `aes_encrypt(data, key, iv) -> bytes`, `aes_decrypt(data, key, iv) -> bytes`, `random_bytes(n) -> PackedByteArray`. Refactor `ManifestSignature`, `RoleToken`, `AuditRecord`, `EncryptedStoragePort`, `LocalEncryptedStorage` to use it. This is the single highest-value abstraction for engine portability.

2. **Extract filesystem access from application services.** Move `DirAccess`/`FileAccess` calls in `BrowseContentService` and `TemplateLoader` behind a `TemplateCatalogPort` (outbound). Move `Time.get_ticks_msec()` and `randi()` in `CloneWorldService` behind `ClockPort.now_msec()` and a `RandomPort` or `IdGeneratorPort`.

3. **Replace `Callable` in port signatures with an event/callback interface.** Define `OnTokenCallback` and `OnDoneCallback` as RefCounted classes (or just use Godot signals on the adapter side only). The port contract should not depend on `Callable` — it should define its own callback protocol.

4. **Introduce `MathVec3` value type** or just use three `float` fields (`pos_x`, `pos_y`, `pos_z`) in `SceneNode` instead of `Vector3`. This eliminates the engine-coordinate-system dependency in the domain layer.

5. **Replace `has_method()` duck-typing** with proper interfaces: `Flushable` port for `flush()`/`flush_if_due()`, `StreamingLLMPort` sub-interface for `complete_with_tools_sync()`.

6. **Replace `.hash()` with injected `IdGeneratorPort`** that produces stable, engine-agnostic IDs (UUID v4 or SHA-256-based). This also fixes the non-crypto-hash finding from prior reviews.

7. **Replace `PackedByteArray` in port signatures** with a wrapper type (`SecureBytes extends RefCounted`) that wraps a `PackedByteArray` internally. Unity adapters would wrap `byte[]` instead.

8. **Replace `push_error()`/`push_warning()`** with a `LoggerPort` (outbound) that adapters implement with `Debug.LogError` / `push_error` as appropriate.
