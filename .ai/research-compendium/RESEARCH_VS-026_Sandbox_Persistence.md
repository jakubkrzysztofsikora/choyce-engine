# RESEARCH_VS-026: Sandbox Persistence and Resume System

**Task ID**: VS-026  
**Title**: Persist and resume the active sandbox locally until explicit New Game  
**Specialty**: sandbox-persistence  
**Status**: in_progress  
**Owner**: codex  
**Cross-review**: claude  
**Dependencies**: [TASK-035]  
**Complexity**: HIGH

---

## Task Overview

This task implements **local sandbox persistence** for the Adventure gameplay mode. The system must save world state, player position, inventory, placed blocks, and progression without blocking the UI. Players should be able to resume their latest sandbox session by default, with an explicit "New Game" action to start fresh.

### Why This Matters

- **Player Experience**: Children expect their progress to be saved automatically
- **Safety**: No blocking modals - saves happen in the background
- **Flexibility**: Explicit New Game action with confirmation
- **Reliability**: Corrupt saves must fail gracefully to a new sandbox

### Key Requirements (from backlog.yaml lines 1463-1467)

1. World state, player position, inventory, placed blocks and progression save locally **without a blocking modal**
2. Relaunch **resumes the latest valid local sandbox state by default**
3. Explicit main-menu **New Game action clears only the selected local sandbox save after confirmation**
4. Corrupt or incomplete local save **safely falls back to a new playable sandbox**

---

## Current Implementation Analysis

### What Exists

From backlog.yaml (lines 1457-1461):
- `src/ports/outbound/session_progress_store_port.gd` - Outbound port interface
- `src/adapters/outbound/in_memory_session_progress_store.gd` - In-memory implementation (needs file-based persistence)
- `src/adapters/inbound/main.gd` - Main entry point
- `src/adapters/inbound/gameplay/gameplay_runtime.gd` - Gameplay orchestrator

### Existing Files Analysis

**session_progress_store_port.gd** (Expected structure):
```gdscript
# src/ports/outbound/session_progress_store_port.gd
class_name SessionProgressStorePort extends RefCounted

## Port interface for session progress persistence

# Save complete session state
func save_session(session_data: Dictionary) -> void:
    pass

# Load session state
func load_session() -> Dictionary:
    return {}

# Check if session exists
func has_session() -> bool:
    return false

# Delete current session
func delete_session() -> void:
    pass

# List available sessions
func list_sessions() -> Array:
    return []
```

**Current Implementation Gap**: The in-memory store doesn't persist to disk.

---

## Online Research Summary

### Godot File System Best Practices

1. **User Data Directory**
   - [OS.get_user_data_dir()](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-get-user-data-dir) - Returns `user://` path
   - Windows: `%APPDATA%\Godot\app_userdata\<project_name>\`
   - macOS: `~/Library/Application Support/Godot/app_userdata/<project_name>/`
   - Linux: `~/.local/share/godot/app_userdata/<project_name>/`
   - **Best Practice**: Use `ProjectSettings.get_setting("application/config/name")` for project name

2. **File Access Methods**
   - [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html) - Binary/text file I/O
   - [ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html) - INI-style configuration
   - [JSON](https://docs.godotengine.org/en/stable/classes/class_json.html) - JSON serialization
   - [ResourceSaver](https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html) - Save resources to `.res` files

3. **Recommended Save Format: JSON**
   - Human-readable for debugging
   - Easy to version and migrate
   - Works with Godot's built-in JSON class
   - Example structure:
```json
{
  "version": 1,
  "metadata": {
    "timestamp": 1718652800,
    "game_version": "0.1.0",
    "checksum": "sha256..."
  },
  "world": {
    "seed": 12345,
    "modified_chunks": [...]
  },
  "player": {
    "position": {"x": 100.0, "y": 0.0, "z": 200.0},
    "rotation": {"x": 0.0, "y": 1.0, "z": 0.0, "w": 0.0},
    "health": 100,
    "inventory": [...]
  },
  "progression": {
    "unlocks": [...],
    "stats": {...}
  }
}
```

4. **Compression for Large Saves**
   - Use [zlib](https://docs.godotengine.org/en/stable/classes/class_streampeer.html) for compression
   - Or [Gzip](https://github.com/GodotExplorer/Streaming) plugin for gzip support
   - Compress only if save > 1MB

### Save System Architecture Patterns

1. **Save Slots Pattern**
   ```
   saves/
   ├── auto_save_0.json
   ├── auto_save_0.json.backup
   ├── slot_1.json
   ├── slot_2.json
   └── slot_3.json
   ```

2. **Atomic Write Pattern**
   - Write to temporary file first
   - Verify checksum
   - Rename to final filename (atomic on most filesystems)

3. **Backup Rotation**
   - Keep last 3-5 auto-saves
   - Rotate on each save
   - Helps recover from corruption

4. **Version Migration**
   - Include version number in save file
   - Implement migration functions for old versions
   - Example: `migrate_v1_to_v2(data: Dictionary) -> Dictionary`

### Background Saving Strategies

1. **Threaded Saving**
   - Use [WorkerThreadPool](https://github.com/GodotExplorer/WorkerThreadPool)
   - Or Godot 4.6 native [MultiThreading](https://docs.godotengine.org/en/stable/tutorials/threads/multithreaded_cli.html)
   - Queue save operations to background thread

2. **Chunked Saving**
   - Break large saves into chunks
   - Save chunk per frame to avoid frame drops
   - Example: Save 100KB per frame

3. **Dirty Flag System**
   - Track what needs saving
   - Only save modified data
   - Reset dirty flags after save

---

## Technical Deep Dive

### 1. File-Based Session Store Implementation

**`file_session_progress_store.gd`** - Replaces in-memory implementation:
```gdscript
# src/adapters/outbound/file_session_progress_store.gd
class_name FileSessionProgressStore extends SessionProgressStorePort

const SAVE_DIR := "user://saves/"
const AUTO_SAVE_FILE := "auto_save.json"
const AUTO_SAVE_BACKUP := "auto_save.json.backup"
const SAVE_VERSION := 2

var save_timer: Timer
var is_saving: bool = false
var pending_save: Dictionary = null

func _init():
    DirAccess.make_dir_absolute(SAVE_DIR)
    save_timer = Timer.new()
    add_child(save_timer)
    save_timer.timeout.connect(_on_save_timeout)
    save_timer.one_shot = true

func save_session(session_data: Dictionary) -> void:
    # Add metadata
    var save_data = {
        "version": SAVE_VERSION,
        "timestamp": Time.get_unix_time_from_system(),
        "data": session_data
    }
    
    # Queue for background save
    pending_save = save_data
    
    # Start save timer (100ms delay to batch rapid saves)
    if not save_timer.is_stopped():
        save_timer.start(0.1)
    else:
        save_timer.start(0.1)

func _on_save_timeout():
    if pending_save:
        _perform_save(pending_save)
        pending_save = null

func _perform_save(save_data: Dictionary) -> void:
    is_saving = true
    
    # Create backup of current save
    if FileAccess.file_exists(SAVE_DIR + AUTO_SAVE_FILE):
        var src = FileAccess.open(SAVE_DIR + AUTO_SAVE_FILE, FileAccess.READ)
        var dst = FileAccess.open(SAVE_DIR + AUTO_SAVE_BACKUP, FileAccess.WRITE)
        dst.store_buffer(src.get_buffer(src.get_length()))
        src.close()
        dst.close()
    
    # Write to temp file first
    var temp_file = SAVE_DIR + "auto_save.tmp"
    var file = FileAccess.open(temp_file, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data))
    file.close()
    
    # Verify write
    if FileAccess.file_exists(temp_file):
        var verify_file = FileAccess.open(temp_file, FileAccess.READ)
        var content = verify_file.get_as_text()
        verify_file.close()
        
        if JSON.parse(content) != null:
            # Atomic rename
            DirAccess.rename_absolute(temp_file, SAVE_DIR + AUTO_SAVE_FILE)
    
    is_saving = false

func load_session() -> Dictionary:
    if FileAccess.file_exists(SAVE_DIR + AUTO_SAVE_FILE):
        var file = FileAccess.open(SAVE_DIR + AUTO_SAVE_FILE, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        
        var data = JSON.parse(content)
        if data != null:
            # Migrate if needed
            if data.get("version", 0) < SAVE_VERSION:
                data = _migrate_save(data)
            return data.get("data", {})
    
    # Try backup
    if FileAccess.file_exists(SAVE_DIR + AUTO_SAVE_BACKUP):
        var file = FileAccess.open(SAVE_DIR + AUTO_SAVE_BACKUP, FileAccess.READ)
        var content = file.get_as_text()
        file.close()
        var data = JSON.parse(content)
        if data != null:
            return data.get("data", {})
    
    return {}

func has_session() -> bool:
    return FileAccess.file_exists(SAVE_DIR + AUTO_SAVE_FILE)

func delete_session() -> void:
    if FileAccess.file_exists(SAVE_DIR + AUTO_SAVE_FILE):
        DirAccess.remove_absolute(SAVE_DIR + AUTO_SAVE_FILE)
    if FileAccess.file_exists(SAVE_DIR + AUTO_SAVE_BACKUP):
        DirAccess.remove_absolute(SAVE_DIR + AUTO_SAVE_BACKUP)

func _migrate_save(old_data: Dictionary) -> Dictionary:
    var version = old_data.get("version", 0)
    
    match version:
        0:
            # Migrate from unversioned save
            return {
                "version": SAVE_VERSION,
                "timestamp": Time.get_unix_time_from_system(),
                "data": old_data
            }
        1:
            # Migrate from v1 to v2
            var new_data = old_data.get("data", {})
            # Add any new fields with defaults
            if not new_data.has("progression"):
                new_data["progression"] = {"unlocks": [], "stats": {}}
            return {
                "version": SAVE_VERSION,
                "timestamp": Time.get_unix_time_from_system(),
                "data": new_data
            }
        _:
            return old_data
```

### 2. Session Data Structure

**`session_data.gd`** - Domain structure for session persistence:
```gdscript
# src/domain/gameplay/session_data.gd
class_name SessionData extends RefCounted

@export var version: int = 1
@export var timestamp: float = 0.0

# World state
@export var world_seed: int = 0
@export var world_version: String = ""
@export var modified_chunks: Array = []
@export var placed_objects: Array = []

# Player state
@export var player_position: Vector3 = Vector3.ZERO
@export var player_rotation: Quaternion = Quaternion.IDENTITY
@export var player_health: float = 100.0
@export var player_inventory: Array = []

# Progression
@export var unlocks: Array = []
@export var stats: Dictionary = {}
@export var achievements: Array = []

# Metadata
@export var playtime_seconds: float = 0.0
@export var session_id: String = ""

func to_dict() -> Dictionary:
    return {
        "version": version,
        "timestamp": timestamp,
        "world_seed": world_seed,
        "world_version": world_version,
        "modified_chunks": modified_chunks,
        "placed_objects": placed_objects,
        "player_position": {"x": player_position.x, "y": player_position.y, "z": player_position.z},
        "player_rotation": {"x": player_rotation.x, "y": player_rotation.y, "z": player_rotation.z, "w": player_rotation.w},
        "player_health": player_health,
        "player_inventory": player_inventory,
        "unlocks": unlocks,
        "stats": stats,
        "achievements": achievements,
        "playtime_seconds": playtime_seconds,
        "session_id": session_id
    }

func from_dict(data: Dictionary) -> void:
    version = data.get("version", 1)
    timestamp = data.get("timestamp", 0.0)
    world_seed = data.get("world_seed", 0)
    world_version = data.get("world_version", "")
    modified_chunks = data.get("modified_chunks", [])
    placed_objects = data.get("placed_objects", [])
    
    var pos = data.get("player_position", {})
    player_position = Vector3(pos.get("x", 0.0), pos.get("y", 0.0), pos.get("z", 0.0))
    
    var rot = data.get("player_rotation", {})
    player_rotation = Quaternion(rot.get("x", 0.0), rot.get("y", 0.0), rot.get("z", 0.0), rot.get("w", 1.0))
    
    player_health = data.get("player_health", 100.0)
    player_inventory = data.get("player_inventory", [])
    unlocks = data.get("unlocks", [])
    stats = data.get("stats", {})
    achievements = data.get("achievements", [])
    playtime_seconds = data.get("playtime_seconds", 0.0)
    session_id = data.get("session_id", "")
```

### 3. Auto-Save Manager

**`auto_save_manager.gd`** - Manages periodic and event-triggered saves:
```gdscript
# src/adapters/inbound/gameplay/auto_save_manager.gd
class_name AutoSaveManager extends Node

@export var save_interval: float = 30.0  # Auto-save every 30 seconds
@export var save_on_pause: bool = true
@export var save_on_quit: bool = true

signal save_started
signal save_completed(success: bool)
signal save_failed(error: String)

var save_timer: Timer
var session_store: SessionProgressStorePort
var is_saving: bool = false

func _ready():
    save_timer = Timer.new()
    add_child(save_timer)
    save_timer.timeout.connect(_on_auto_save_timeout)
    save_timer.wait_time = save_interval
    save_timer.start()
    
    # Get session store from dependency injection
    session_store = get_parent().get_node("SessionStore")
    if session_store == null:
        session_store = SessionProgressStorePort.new()

func start_game() -> void:
    # Load existing session on start
    if session_store.has_session():
        var session_data = session_store.load_session()
        apply_session_data(session_data)
    else:
        start_new_session()

func start_new_session() -> void:
    # Clear any existing session
    session_store.delete_session()
    # Create new session
    var new_session = create_empty_session()
    save_session(new_session)

func save_session(session_data: Dictionary) -> void:
    if is_saving:
        return  # Skip if already saving
    
    is_saving = true
    emit_signal("save_started")
    
    # Save in background
    session_store.save_session(session_data)
    
    is_saving = false
    emit_signal("save_completed", true)

func _on_auto_save_timeout():
    if not get_tree().paused:
        save_current_session()

func save_current_session() -> void:
    var session_data = collect_session_data()
    save_session(session_data)

func collect_session_data() -> Dictionary:
    var gameplay_runtime = get_node("/root/Main/GameplayRuntime")
    if gameplay_runtime:
        return gameplay_runtime.get_session_state()
    return {}

func apply_session_data(session_data: Dictionary) -> void:
    var gameplay_runtime = get_node("/root/Main/GameplayRuntime")
    if gameplay_runtime:
        gameplay_runtime.apply_session_state(session_data)

func create_empty_session() -> Dictionary:
    return {
        "world_seed": randi(),
        "player_position": Vector3(0, 0, 0),
        "player_health": 100.0,
        "inventory": [],
        "progression": {"unlocks": [], "stats": {}},
        "timestamp": Time.get_unix_time_from_system()
    }

func _notification(what: int):
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        if save_on_quit:
            save_current_session()
```

### 4. Gameplay Runtime Integration

**Modifications to `gameplay_runtime.gd`**:
```gdscript
# Add to src/adapters/inbound/gameplay/gameplay_runtime.gd

var session_data: SessionData = SessionData.new()

func get_session_state() -> Dictionary:
    # Collect all session-relevant data
    session_data.timestamp = Time.get_unix_time_from_system()
    session_data.player_position = player.global_transform.origin
    session_data.player_rotation = player.global_transform.basis.get_rotation_quaternion()
    session_data.player_health = player.health
    session_data.player_inventory = inventory.get_items()
    session_data.world_seed = world_renderer.world_seed
    session_data.modified_chunks = world_renderer.get_modified_chunks()
    session_data.placed_objects = build_grid.get_placed_objects()
    session_data.unlocks = progression_manager.get_unlocks()
    session_data.stats = progression_manager.get_stats()
    
    return session_data.to_dict()

func apply_session_state(data: Dictionary) -> void:
    session_data.from_dict(data)
    
    # Apply player state
    player.global_transform.origin = session_data.player_position
    player.global_transform.basis = Basis.from_euler(session_data.player_rotation.get_euler())
    player.health = session_data.player_health
    inventory.set_items(session_data.player_inventory)
    
    # Apply world state
    world_renderer.world_seed = session_data.world_seed
    world_renderer.restore_modified_chunks(session_data.modified_chunks)
    build_grid.restore_placed_objects(session_data.placed_objects)
    
    # Apply progression
    progression_manager.set_unlocks(session_data.unlocks)
    progression_manager.set_stats(session_data.stats)
```

---

## Godot-Specific Implementation Patterns

### 1. Binary Save Format (For Large Worlds)

For very large world states, use binary format:

```gdscript
# binary_session_store.gd
class_name BinarySessionStore extends SessionProgressStorePort

const MAGIC_NUMBER := 0x43484F59  # "CHOY" in hex
const FORMAT_VERSION := 1

func save_session(session_data: Dictionary) -> void:
    var buffer = PackedByteArray()
    
    # Write header
    buffer.append_32(MAGIC_NUMBER)
    buffer.append_32(FORMAT_VERSION)
    buffer.append_64(Time.get_unix_time_from_system())
    
    # Write JSON as UTF-8
    var json_str = JSON.stringify(session_data)
    var json_bytes = json_str.to_utf8_buffer()
    buffer.append_32(json_bytes.size())
    buffer.append_array(json_bytes)
    
    # Write checksum
    var hash = Crypto.new()
    hash.update(buffer)
    var checksum = hash.final()
    buffer.append_array(checksum)
    
    # Write to file
    var file = FileAccess.open("user://saves/session.bin", FileAccess.WRITE)
    file.store_buffer(buffer)
    file.close()

func load_session() -> Dictionary:
    var file = FileAccess.open("user://saves/session.bin", FileAccess.READ)
    if file == null:
        return {}
    
    var buffer = file.get_buffer(file.get_length())
    file.close()
    
    # Verify header
    var cursor = 0
    var magic = buffer.read_32(cursor)
    cursor += 4
    
    if magic != MAGIC_NUMBER:
        return {}  # Invalid file
    
    var version = buffer.read_32(cursor)
    cursor += 4
    
    if version != FORMAT_VERSION:
        return {}  # Unsupported version
    
    cursor += 8  # Skip timestamp
    
    # Read JSON size
    var json_size = buffer.read_32(cursor)
    cursor += 4
    
    # Read JSON
    var json_bytes = buffer.slice(cursor, cursor + json_size)
    cursor += json_size
    
    var json_str = json_bytes.get_string_from_utf8()
    return JSON.parse(json_str).result
```

### 2. Threaded Saving with WorkerThreads

```gdscript
# threaded_session_store.gd
class_name ThreadedSessionStore extends SessionProgressStorePort

var worker: WorkerThreadPool
var pending_saves: Queue = Queue.new()

func _init():
    worker = WorkerThreadPool.new()
    add_child(worker)
    worker.set_pool_size(1)

func save_session(session_data: Dictionary) -> void:
    pending_saves.push_back(session_data)
    
    if worker.get_active_threads() == 0:
        _process_next_save()

func _process_next_save():
    if pending_saves.size() > 0:
        var data = pending_saves.pop_front()
        worker.add_task(_save_task, data)

func _save_task(userdata: Variant, task_id: int) -> Variant:
    var session_data = userdata
    
    # Perform actual save
    var temp_file = "user://saves/auto_save_%d.tmp" % [task_id]
    var final_file = "user://saves/auto_save.json"
    
    var file = FileAccess.open(temp_file, FileAccess.WRITE)
    file.store_string(JSON.stringify(session_data))
    file.close()
    
    # Atomic rename
    if FileAccess.file_exists(temp_file):
        DirAccess.rename_absolute(temp_file, final_file)
    
    return OK

func _notification(what: int):
    if what == NOTIFICATION_POSTINITIALIZE:
        # Load any pending saves that didn't complete
        _recover_pending_saves()
```

### 3. Compression with Zlib

```gdscript
# compressed_session_store.gd
class_name CompressedSessionStore extends SessionProgressStorePort

func save_session(session_data: Dictionary) -> void:
    var json_str = JSON.stringify(session_data)
    var json_bytes = json_str.to_utf8_buffer()
    
    # Compress
    var compressed = StreamPeerBuffer.new()
    var compressor = StreamPeerGzip.new(compressed, COMPRESSION_GZIP)
    compressor.start(compression.MODE_COMPRESS)
    compressor.put_data(json_bytes)
    compressor.finish()
    
    # Write compressed data
    var file = FileAccess.open("user://saves/session.gz", FileAccess.WRITE)
    file.store_buffer(compressed.data.get_data_array())
    file.close()

func load_session() -> Dictionary:
    if not FileAccess.file_exists("user://saves/session.gz"):
        return {}
    
    var file = FileAccess.open("user://saves/session.gz", FileAccess.READ)
    var compressed = file.get_buffer(file.get_length())
    file.close()
    
    # Decompress
    var input = StreamPeerBuffer.new(compressed)
    var decompressor = StreamPeerGzip.new(input, COMPRESSION_GZIP)
    decompressor.start(compression.MODE_DECOMPRESS)
    var json_bytes = decompressor.get_data()
    decompressor.finish()
    
    var json_str = json_bytes.get_string_from_utf8()
    return JSON.parse(json_str).result
```

---

## Asset Packages & Tools

### Godot Addons for Persistence

| Addon | Purpose | Link |
|-------|---------|------|
| **SaveSystem** | Full save system with slots, compression, encryption | [GitHub](https://github.com/GodotExplorer/SaveSystem) |
| **EasySave** | Simple JSON-based save system | [AssetLib](https://godotengine.org/asset-library/asset/484) |
| **FileDialog** | Native file dialogs | [GitHub](https://github.com/GodotExplorer/FileDialog) |
| **SQLite** | SQL database for structured data | [GitHub](https://github.com/2shady4u/godot-sqlite) |

### Serialization Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **Godot JSON** | Built-in JSON support | [Docs](https://docs.godotengine.org/en/stable/classes/class_json.html) |
| **BSON** | Binary JSON | [GitHub](https://github.com/GodotExplorer/BSON) |
| **MessagePack** | Binary serialization | [GitHub](https://github.com/GodotExplorer/MessagePack) |

---

## Learning Resources

### Godot Persistence Tutorials

1. **Saving and Loading Games**
   - [Official Docs](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
   - [GDQuest Save System](https://gdquest.com/tutorial/godot-4-save-system/)
   - [HeartBeast Save System](https://www.heartbeast.co/godot-4-saving-loading/)

2. **Advanced Topics**
   - [FileSystem API](https://docs.godotengine.org/en/stable/classes/class_diraccess.html)
   - [User Data Management](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)
   - [Custom Resource Formats](https://docs.godotengine.org/en/stable/classes/class_resourceformatloader.html)

3. **Performance Considerations**
   - [Optimizing File I/O](https://docs.godotengine.org/en/stable/tutorials/optimization/file_io.html)
   - [Threading in Godot](https://docs.godotengine.org/en/stable/tutorials/threads/multithreaded_cli.html)
   - [Memory Management](https://docs.godotengine.org/en/stable/tutorials/optimization/memory_optimization.html)

4. **Best Practices**
   - [Save Game Design](https://www.gamasutra.com/view/feature/132353/)
   - [Data Serialization Patterns](https://martinfowler.com/articles/serialization.html)
   - [Version Migration Strategies](https://www.gamedev.net/articles/business/legal/data-migration-strategies-r1139/)

---

## Implementation Checklist

### Phase 1: Core Persistence
- [ ] Create `FileSessionProgressStore` extending `SessionProgressStorePort`
- [ ] Implement JSON serialization for session data
- [ ] Add atomic write with backup rotation
- [ ] Create save directory structure
- [ ] Implement version migration system

### Phase 2: Session Management
- [ ] Create `SessionData` domain class
- [ ] Add `AutoSaveManager` singleton
- [ ] Implement periodic auto-save (30 second interval)
- [ ] Add save on quit functionality
- [ ] Add save on pause functionality

### Phase 3: Gameplay Integration
- [ ] Modify `GameplayRuntime` to expose session state
- [ ] Add `get_session_state()` method
- [ ] Add `apply_session_state()` method
- [ ] Wire up auto-save manager to gameplay runtime

### Phase 4: UI Integration
- [ ] Add "New Game" button with confirmation
- [ ] Add save slot selection (future enhancement)
- [ ] Display save/load status notifications
- [ ] Add settings for auto-save frequency

### Phase 5: Testing & Validation
- [ ] Unit tests for save/load functionality
- [ ] Test version migration
- [ ] Test corrupt save recovery
- [ ] Test concurrent save scenarios
- [ ] Performance test with large worlds

---

## Child-Safety Constraints

### Data Privacy Requirements

1. **Local Storage Only**
   - No cloud sync without explicit parent consent
   - All saves stored in user directory
   - No telemetry in save files

2. **Data Minimization**
   - Only save necessary gameplay data
   - No personal information in saves
   - No tracking identifiers

3. **Parent Controls**
   - Parent can delete saves
   - Parent can disable auto-save
   - Parent can view save metadata

4. **Transparency**
   - Clear save file location
   - Human-readable format (JSON)
   - No hidden data

### Safety Checks

```gdscript
# safety_checks.gd

func validate_save_data(data: Dictionary) -> bool:
    # Check for personal information
    var blacklist = ["name", "email", "address", "phone", "birthdate"]
    for key in blacklist:
        if data.has(key):
            return false
    
    # Check data size (max 50MB)
    var json_str = JSON.stringify(data)
    if json_str.length() > 50 * 1024 * 1024:
        return false
    
    # Check for nested depth (max 10 levels)
    if _get_max_depth(data) > 10:
        return false
    
    return true

func _get_max_depth(data: Variant, current_depth: int = 0) -> int:
    if data is Dictionary:
        if data.is_empty():
            return current_depth
        var max_child_depth = 0
        for value in data.values():
            max_child_depth = max(max_child_depth, _get_max_depth(value, current_depth + 1))
        return max_child_depth
    elif data is Array:
        if data.is_empty():
            return current_depth
        var max_child_depth = 0
        for value in data:
            max_child_depth = max(max_child_depth, _get_max_depth(value, current_depth + 1))
        return max_child_depth
    else:
        return current_depth
```

---

## References

### Internal References
- [VS-035: Offline-First Autosave](.ai/tasks/backlog.yaml#task-035) - Related autosave requirements
- [SessionProgressStorePort](src/ports/outbound/session_progress_store_port.gd) - Port interface
- [InMemorySessionProgressStore](src/adapters/outbound/in_memory_session_progress_store.gd) - Current implementation

### External References
- [Godot FileSystem Docs](https://docs.godotengine.org/en/stable/classes/class_diraccess.html)
- [Godot JSON Class](https://docs.godotengine.org/en/stable/classes/class_json.html)
- [Godot ConfigFile](https://docs.godotengine.org/en/stable/classes/class_configfile.html)
- [Godot Saving Games Tutorial](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [GDQuest Save System](https://gdquest.com/tutorial/godot-4-save-system/)
- [SaveSystem Addon](https://github.com/GodotExplorer/SaveSystem)

### Related Research
- [VS-035: Offline-First Autosave and Cloud Sync](.ai/tasks/backlog.yaml#task-035)

---

*Generated by Mistral Vibe for Choyce Engine VS-026*  
*Last Updated: 2026-07-18*  
*Document Size: ~22KB*
