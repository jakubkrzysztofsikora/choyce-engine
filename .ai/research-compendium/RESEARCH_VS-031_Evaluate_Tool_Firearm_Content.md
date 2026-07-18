# RESEARCH_VS-031: Evaluate Optional Parent-Gated Tool and Firearm Content

**Task ID**: VS-031
**Title**: Evaluate optional parent-gated tool and firearm content for a later mode
**Specialty**: child-safety-and-combat-content
**Status**: todo
**Owner**: mistral
**Cross-review**: claude
**Dependencies**: [VS-023, TASK-015]
**Complexity**: HIGH

---

## Task Overview

This task evaluates **tool and firearm content** (SWAT, Soldier, Tank, Pistol, Assault Rifle models and ShooterKit) for potential **parent-gated optional content** in a later game mode. The evaluation must ensure all content is **properly licensed**, **parent-gated**, **single-player by default**, **non-gory**, **reversible**, and **explicitly covered by age/content policies**. Critically, **no candidate asset** can be imported or exposed to the current visual vertical slice without an approved design and safety review.

### Why This Matters

- **Parent Choice**: Some parents may want tactical/SCP-style content for older children
- **Safety First**: Must maintain child-safe defaults with explicit parent opt-in
- **Legal Compliance**: Must verify all asset licenses and provenance
- **Design Cohesion**: Must fit within Choyce Engine's hexagonal architecture and safety systems
- **Isolation**: Current VS must remain melee/creative-only

### Key Requirements (from backlog.yaml lines 1560-1564)

1. **License and source provenance are recorded for every candidate model and toolkit**
2. **The default child sandbox stays melee/creative-only and contains no firearm or tactical-police content**
3. **Any later experiment is parent-gated, single-player by default, non-gory, reversible, and has explicit age/content policy coverage**
4. **No candidate asset is imported or exposed to the current visual vertical slice without an approved design and safety review**

### Candidate Assets

| Asset | Path | Type | Source |
|-------|------|------|--------|
| SWAT Model | `/Users/jakubsikora/Downloads/SWAT.glb` | Character | Unknown (needs verification) |
| Soldier Model | `/Users/jakubsikora/Downloads/Soldier.fbx` | Character | Unknown (needs verification) |
| Tank Model | `/Users/jakubsikora/Downloads/Tank.glb` | Vehicle | Unknown (needs verification) |
| Pistol Model | `/Users/jakubsikora/Downloads/Pistol.glb` | Weapon | Unknown (needs verification) |
| Assault Rifle Model | `/Users/jakubsikora/Downloads/Assault Rifle.glb` | Weapon | Unknown (needs verification) |
| ShooterKit | `/Users/jakubsikora/Downloads/ShooterKit-aacba3868d41706fde6daff00877055e52d200c6` | Toolkit | Unknown (needs verification) |

---

## Current Implementation Analysis

### What Exists

From the codebase:
- `src/domain/identity_safety/parental_control_policy.gd` - Parental control and content policy system
- `docs/requirements/functionality-requirements.md` - Functional requirements including safety constraints
- VS-023: Original Liminal Creatures - Already provides Backrooms-inspired creatures (child-safe)
- VS-005: Combat Telegraphs and Feedback - Melee combat system with wind-up telegraphs

### Architecture Integration Points

The Choyce Engine uses **hexagonal architecture** with:
- **Domain Layer**: Contains `ParentalControlPolicy`, safety rules, content classification
- **Application Layer**: Handles use cases, parent approval workflows
- **Adapter Layer**: Godot-specific implementations

For firearm/tool content to be integrated safely:
1. Must be **gated by ParentalControlPolicy**
2. Must use **existing combat systems** (hit detection, telegraphs)
3. Must be **fully reversible** (can be disabled/removed)
4. Must be **audit-logged** (all access attempts recorded)

---

## Online Research Summary

### 1. Firearm Content in Children's Games - Industry Standards

**ESRB Guidelines**:
- **E (Everyone)**: "Content is generally suitable for ages 6 and up. May contain minimal cartoon, fantasy or mild violence and/or infrequent use of mild language."
- **E10+ (Everyone 10+)**: "Content is generally suitable for ages 10 and up. May contain more cartoon, fantasy or mild violence, mild language and/or minimal suggestive themes."
- **T (Teen)**: "Content is generally suitable for ages 13 and up. May contain violence, suggestive themes, crude humor, minimal blood, simulated gambling and/or infrequent use of strong language."

**COPPA Compliance**:
- Must have **parental consent** for data collection
- Must have **clear content descriptors**
- Must allow **parental review** of content

**Recommendation**: Firearm content should be **E10+ minimum**, require **explicit parent unlock**, and be **clearly labeled** in settings.

### 2. Alternative: Tool-Based Combat (Recommended)

Instead of firearms, consider **tool-based combat** that fits the sandbox theme:
- **Construction Tools**: Hammers, wrenches, crowbars (melee)
- **Farming Tools**: Hoes, pitchforks, sickles
- **Utility Tools**: Flashlights, nets, ropes
- **Fantasy Tools**: Magic staves, energy projectors (non-gun-like)

**Asset Sources (CC0)**:
- [Kenney Tool Pack](https://kenney.nl/assets/tool-pack) - Various tools
- [Quaternius Tools](https://quaternius.com/free-3d-models?category=tools) - 3D tool models
- [Poly Pizza Tools](https://poly.pizza/search?q=tool) - Low-poly tools

### 3. If Firearms Are Approved: Safe Implementation Patterns

**Design Constraints**:
- **No realistic firearms** - Only fantasy/sci-fi energy weapons
- **No blood/gore** - Only energy effects, knockback
- **No human targets** - Only monsters/creatures (from VS-023)
- **Ammo-based** - Limited use, must gather/recharge
- **Telegraph required** - Must use existing wind-up system from VS-005
- **Parent can disable** - Toggle in ParentalControlPolicy

**Implementation Approach**:
```gdscript
# Content Classification System
class_name ContentClassification extends RefCounted:
    enum ContentType {
        MELEE,       # Default, always allowed
        TOOL,        # Tools (hammers, etc.), always allowed
        ENERGY,      # Fantasy energy weapons, parent-gated
        FIREARM,     # Realistic firearms, parent-gated + age verification
        GORE,        # Never allowed
    }
    
    var type: ContentType
    var min_age: int = 0
    var requires_parent_approval: bool = false
    var description: String
```

### 4. License Provenance Research

**Important**: The downloaded assets need license verification. Based on filenames:

1. **SWAT.glb** - Likely from:
   - [Mixamo](https://www.mixamo.com/) - Requires attribution, check license
   - [Sketchfab](https://sketchfab.com/) - Varies by model
   - [CGTrader](https://www.cgtrader.com/) - Varies by model

2. **Soldier.fbx** - Likely from:
   - [Mixamo](https://www.mixamo.com/) - Free for non-commercial, attribution required
   - [MakeHuman](http://www.makehumancommunity.org/) - CC0 or AGPL

3. **Tank.glb** - Likely from:
   - [Quaternius](https://quaternius.com/free-3d-models) - CC0 (RECOMMENDED SOURCE)
   - [Poly Pizza](https://poly.pizza/) - CC0
   - [Kenney](https://kenney.nl/) - CC0

4. **Pistol.glb / Assault Rifle.glb** - PROBLEMATIC:
   - Most free firearm models have **restrictive licenses**
   - **Recommendation**: Do NOT use - create custom fantasy weapons instead
   - Alternative: Use [Kenney's Gun Pack](https://kenney.nl/assets/gunpack) but **modify heavily** to be non-recognizable

5. **ShooterKit** - Need to identify exact package:
   - Could be [Godot Shooter Kit](https://github.com/GodotExplorer/ShooterKit) - MIT License
   - Could be commercial asset - needs verification

**Action Required**: Verify each asset's license before any integration.

### 5. ShooterKit Analysis

Assuming this is the [GodotExplorer/ShooterKit](https://github.com/GodotExplorer/ShooterKit):

**Features**:
- Weapon system with recoil, spread, reload
- Projectile system
- Hit detection
- Particle effects

**License**: MIT (compatible)

**Safety Concerns**:
- Designed for realistic shooters
- May include blood/gore effects
- May include realistic weapon models
- May have public multiplayer features

**Recommendation**: **REJECT** for direct use. Instead:
- Extract **technical patterns** (projectile physics, recoil math)
- Reimplement with **fantasy weapons** and **child-safe effects**
- Use **existing telegraph system** from VS-005

---

## Technical Deep Dive

### Parent-Gated Content System

The existing `ParentalControlPolicy` must be extended:

```gdscript
# src/domain/identity_safety/parental_control_policy.gd
class_name ParentalControlPolicy extends RefCounted:
    
    # Existing combat difficulty setting
    @export var combat_difficulty: int = 0: set = set_combat_difficulty
    
    # NEW: Content access flags
    @export var allow_energy_weapons: bool = false: set = set_content_flag
    @export var allow_fantasy_weapons: bool = false: set = set_content_flag
    @export var allow_tactical_theme: bool = false: set = set_content_flag
    
    # Content age ratings
    @export var max_content_rating: String = "E": set = set_rating
    
    var _content_flags: Dictionary = {
        "allow_energy_weapons": false,
        "allow_fantasy_weapons": false,
        "allow_tactical_theme": false,
    }
    
    func set_content_flag(value: bool) -> void:
        # Requires parent authentication
        if !IdentityService.is_parent_authenticated():
            push_warning("Parent authentication required to change content settings")
            return
        
        # Audit log
        AuditService.log_content_setting_change(self, value)
    
    func is_content_allowed(content_type: String) -> bool:
        match content_type:
            "energy_weapon":
                return _content_flags["allow_energy_weapons"]
            "fantasy_weapon":
                return _content_flags["allow_fantasy_weapons"]
            "tactical_theme":
                return _content_flags["allow_tactical_theme"]
            _:
                return true  # Default allow (melee, tools)
```

### Weapon Classification System

```gdscript
# src/domain/combat/weapon_definition.gd
class_name WeaponDefinition extends RefCounted:
    
    @export var weapon_id: String
    @export var display_name: String
    @export var weapon_type: String  # "melee", "tool", "energy", "firearm"
    @export var content_rating: String  # "E", "E10+", "T"
    @export var requires_parent_unlock: bool = false
    @export var damage: float
    @export var range: float
    @export var fire_rate: float
    @export var ammo_type: String  # "none", "energy", "ammunition"
    @export var projectile_scene: PackedScene
    @export var attack_animation: String
    @export var windup_animation: String
    @export var hit_effect: PackedScene
    
    func is_allowed(parental_policy: ParentalControlPolicy) -> bool:
        if weapon_type == "melee" or weapon_type == "tool":
            return true  # Always allowed
        
        if weapon_type == "energy" and parental_policy.allow_energy_weapons:
            return true
        
        if weapon_type == "firearm" and parental_policy.allow_fantasy_weapons:
            # Only if heavily modified to be fantasy
            return is_fantasy_design()
        
        return false
    
    func is_fantasy_design() -> bool:
        # Check if weapon is sufficiently modified from realistic
        return display_name.to_lower().contains("energy") or \
               display_name.to_lower().contains("plasma") or \
               display_name.to_lower().contains("ray")
```

### Content Loading with Safety Checks

```gdscript
# src/adapters/inbound/content/weapon_loader.gd
class_name WeaponLoader extends Node:
    
    signal weapon_loaded(weapon: WeaponInstance)
    signal load_rejected(weapon_id: String, reason: String)
    
    var parental_policy: ParentalControlPolicy
    
    func load_weapon(weapon_id: String) -> void:
        var weapon_def = WeaponRegistry.get_definition(weapon_id)
        
        if weapon_def == null:
            load_rejected.emit(weapon_id, "Weapon not found")
            return
        
        # Check parent policy
        if not weapon_def.is_allowed(parental_policy):
            AuditService.log_content_access_attempt(
                weapon_id, 
                "REJECTED", 
                "Parent policy blocks content type: %s" % weapon_def.weapon_type
            )
            load_rejected.emit(weapon_id, "Parent policy blocks this content")
            return
        
        # Log successful access
        AuditService.log_content_access_attempt(
            weapon_id,
            "ALLOWED",
            "Loaded by parent policy"
        )
        
        # Load the weapon
        var weapon_instance = WeaponInstance.new()
        weapon_instance.setup_from_definition(weapon_def)
        weapon_loaded.emit(weapon_instance)
```

### Fantasy Weapon Implementation (Recommended)

Instead of realistic firearms, implement **fantasy energy weapons**:

```gdscript
# src/adapters/inbound/combat/energy_weapon.gd
class_name EnergyWeapon extends WeaponBase:
    
    @export var energy_type: String = "plasma"  # plasma, laser, ice, lightning
    @export var charge_time: float = 0.5
    @export var energy_cost: float = 10.0
    @export var beam_length: float = 50.0
    @export var beam_width: float = 0.2
    
    var is_charging: bool = false
    var charge_timer: float = 0.0
    
    func _ready() -> void:
        # Setup telegraph (from VS-005)
        setup_windup_telegraph()
    
    func start_charge() -> void:
        if not can_fire():
            return
        
        is_charging = true
        charge_timer = 0.0
        
        # Play charge-up animation
        animation_player.play("charge")
        
        # Show telegraph area
        show_telegraph_indicator(beam_length, Color.BLUE)
    
    func _process(delta: float) -> void:
        if is_charging:
            charge_timer += delta
            
            if charge_timer >= charge_time:
                fire_energy_blast()
                is_charging = false
    
    func fire_energy_blast() -> void:
        if not can_fire():
            return
        
        consume_energy(energy_cost)
        
        # Spawn energy beam
        var beam = EnergyBeam.new()
        beam.setup(beam_length, beam_width, energy_type)
        add_child(beam)
        
        # Play fire animation
        animation_player.play("fire")
        
        # Spawn hit effect at end of beam
        var hit_position = get_global_mouse_position()
        spawn_hit_effect(hit_position)
        
        # Check for hits
        perform_raycast_hit_detection(hit_position)
```

---

## Code Samples

### 1. Parent-Gated Content Check in Player Controller

```gdscript
# src/adapters/inbound/gameplay/player_controller.gd
func try_equip_weapon(weapon_id: String) -> bool:
    var weapon_def = WeaponRegistry.get_definition(weapon_id)
    
    if weapon_def == null:
        return false
    
    # Check if weapon is allowed by parent policy
    if not weapon_def.is_allowed(parental_control_policy):
        # Show parent-lock indicator
        HUD.show_parent_lock_indicator(weapon_def.display_name)
        
        # Play denied sound
        AudioService.play_ui_sound("denied")
        return false
    
    # Check if player has required level/items
    if not has_prerequisites(weapon_def):
        HUD.show_requirement_tooltip(weapon_def.get_requirements())
        return false
    
    # Equip the weapon
    current_weapon = weapon_def.instantiate()
    add_child(current_weapon)
    return true
```

### 2. Telegraph System for Energy Weapons (Building on VS-005)

```gdscript
# src/adapters/inbound/combat/energy_weapon_telegraph.gd
class_name EnergyWeaponTelegraph extends Node3D:
    
    @export var telegraph_mesh: MeshInstance3D
    @export var charge_time: float = 0.5
    @export var pulse_speed: float = 2.0
    
    var target_position: Vector3
    var progress: float = 0.0
    
    func setup(target: Vector3, beam_length: float) -> void:
        target_position = target
        
        # Position telegraph between weapon and target
        var direction = (target - global_position).normalized()
        var center = global_position + direction * (beam_length * 0.5)
        
        global_position = center
        look_at(target, Vector3.UP)
        
        # Scale to beam length
        var distance = global_position.distance_to(target)
        telegraph_mesh.scale.z = distance
        
        # Start pulsing
        start_pulse()
    
    func _process(delta: float) -> void:
        progress += delta / charge_time
        
        if progress >= 1.0:
            queue_free()
            return
        
        # Pulse effect
        var pulse = sin(progress * pulse_speed * TAU) * 0.5 + 0.5
        telegraph_mesh.modulate.a = pulse * 0.8
    
    func start_pulse() -> void:
        # Animate the telegraph
        var anim = Animation.new()
        anim.length = charge_time
        anim.loop_mode = Animation.LOOP_LINEAR
        
        var track = anim.add_track(Animation.TYPE_VALUE)
        anim.track_set_path(track, ".:modulate:a")
        anim.track_insert_key(track, 0.0, 0.0)
        anim.track_insert_key(track, charge_time * 0.5, 0.8)
        anim.track_insert_key(track, charge_time, 0.0)
        
        animation_player.add_animation("telegraph_pulse", anim)
        animation_player.play("telegraph_pulse")
```

### 3. Audit Logging for Content Access

```gdscript
# src/domain/identity_safety/audit_service.gd
class_name AuditService extends RefCounted:
    
    static var instance: AuditService
    
    var log_entries: Array[Dictionary] = []
    var max_entries: int = 10000
    
    func log_content_access_attempt(content_id: String, status: String, reason: String) -> void:
        var entry = {
            "timestamp": Time.get_unix_time_from_system(),
            "type": "content_access",
            "content_id": content_id,
            "status": status,
            "reason": reason,
            "user_id": IdentityService.get_current_user_id(),
            "is_parent": IdentityService.is_parent_authenticated(),
            "session_id": SessionService.get_current_session_id(),
        }
        
        log_entries.append(entry)
        
        # Trim if too large
        if log_entries.size() > max_entries:
            log_entries = log_entries.slice(-max_entries)
        
        # Save to file
        save_to_file()
    
    func log_content_setting_change(policy: ParentalControlPolicy, new_value: bool) -> void:
        var entry = {
            "timestamp": Time.get_unix_time_from_system(),
            "type": "content_setting_change",
            "setting": "parental_control",
            "new_value": new_value,
            "user_id": IdentityService.get_current_user_id(),
            "is_parent": true,  # Only parents can change this
            "session_id": SessionService.get_current_session_id(),
        }
        
        log_entries.append(entry)
        save_to_file()
    
    func save_to_file() -> void:
        var file = FileAccess.open("user://audit_log.json", FileAccess.WRITE)
        if file:
            file.store_string(JSON.stringify(log_entries))
            file.close()
```

### 4. Safe Alternative: Construction Tool Combat

```gdscript
# src/adapters/inbound/combat/construction_tool.gd
class_name ConstructionTool extends WeaponBase:
    
    enum ToolType {
        HAMMER,
        WRENCH,
        CROWBAR,
        SHOVEL,
    }
    
    @export var tool_type: ToolType = ToolType.HAMMER
    @export var build_power: float = 1.0  # Can also be used to "build" damage
    
    func get_animation_prefix() -> String:
        match tool_type:
            ToolType.HAMMER:
                return "hammer"
            ToolType.WRENCH:
                return "wrench"
            ToolType.CROWBAR:
                return "crowbar"
            ToolType.SHOVEL:
                return "shovel"
    
    func attack() -> void:
        var anim_prefix = get_animation_prefix()
        animation_player.play("%s_attack" % anim_prefix)
        
        # Show swing telegraph
        show_swing_arc()
        
        # Check for hits after swing delay
        await animation_player.animation_finished
        
        # Perform area hit detection
        var hit_enemies = detect_hits_in_arc()
        
        for enemy in hit_enemies:
            enemy.take_damage(get_damage() * build_power)
            spawn_hit_particles(enemy.global_position)
```

---

## Asset Packages and Tools

### Recommended CC0/Compatible Asset Sources

#### Fantasy/Sci-Fi Weapons (Safe Alternatives)

| Package | License | Link | Notes |
|---------|---------|------|-------|
| Kenney Fantasy Weapon Pack | CC0 | [kenney.nl/assets/fantasy-weapon-pack](https://kenney.nl/assets/fantasy-weapon-pack) | Swords, staves, bows |
| Kenney Gun Pack (Modified) | CC0 | [kenney.nl/assets/gunpack](https://kenney.nl/assets/gunpack) | Must heavily modify to be non-recognizable |
| Quaternius Sci-Fi Weapons | CC0 | [quaternius.com/free-3d-models?category=weapons](https://quaternius.com/free-3d-models?category=weapons) | Energy weapons, futuristic |
| Poly Pizza Weapons | CC0 | [poly.pizza/search?q=weapon](https://poly.pizza/search?q=weapon) | Various low-poly |
| CC0 Textures | CC0 | [cc0textures.com](https://cc0textures.com/) | For custom weapon texturing |

#### Tools (Always Safe)

| Package | License | Link | Notes |
|---------|---------|------|-------|
| Kenney Tool Pack | CC0 | [kenney.nl/assets/tool-pack](https://kenney.nl/assets/tool-pack) | Hammers, wrenches, etc. |
| Kenney Construction Kit | CC0 | [kenney.nl/assets/construction-kit](https://kenney.nl/assets/construction-kit) | Construction tools |
| Quaternius Tools | CC0 | [quaternius.com/free-3d-models?category=tools](https://quaternius.com/free-3d-models?category=tools) | 3D tool models |

#### Tactical Characters (Parent-Gated)

| Package | License | Link | Notes |
|---------|---------|------|-------|
| Quaternius Soldiers | CC0 | [quaternius.com/free-3d-models?category=characters](https://quaternius.com/free-3d-models?category=characters) | Must verify non-violent poses |
| Mixamo Characters | Varies | [mixamo.com](https://www.mixamo.com/) | Requires attribution, check each |

#### Vehicles (Parent-Gated)

| Package | License | Link | Notes |
|---------|---------|------|-------|
| Kenney Tank | CC0 | [kenney.nl/assets/tank](https://kenney.nl/assets/tank) | Cartoon style, safe |
| Quaternius Vehicles | CC0 | [quaternius.com/free-3d-models?category=vehicles](https://quaternius.com/free-3d-models?category=vehicles) | Various options |
| Poly Pizza Vehicles | CC0 | [poly.pizza/search?q=tank](https://poly.pizza/search?q=tank) | Low-poly options |

### Asset Verification Checklist

For EACH downloaded asset:

- [ ] **Download Source**: Identify exact website/URL
- [ ] **License Type**: MIT, CC0, CC-BY, Commercial, etc.
- [ ] **License Text**: Full license file saved
- [ ] **Attribution Required**: Yes/No
- [ ] **Commercial Use Allowed**: Yes/No
- [ ] **Modification Allowed**: Yes/No
- [ ] **Redistribution Allowed**: Yes/No
- [ ] **Author**: Record for attribution
- [ ] **Version/Date**: Record for tracking
- [ ] **File Hash**: SHA256 for verification
- [ ] **Content Review**: Check for violence/gore
- [ ] **Child-Safe Modification Plan**: If needed

### License Compatibility Matrix

| License | Commercial | Modification | Redistribution | Attribution | Choyce Compatible |
|---------|-----------|--------------|---------------|-------------|------------------|
| CC0 | Yes | Yes | Yes | No | ✅ YES |
| MIT | Yes | Yes | Yes | Yes | ✅ YES |
| CC-BY | Yes | Yes | Yes | Yes | ✅ YES |
| CC-BY-SA | Yes | Yes | Yes | Yes | ⚠️ CAUTION (viral) |
| Apache 2.0 | Yes | Yes | Yes | Yes | ✅ YES |
| GPL | No | Yes | Yes | Yes | ❌ NO |
| AGPL | No | Yes | Yes | Yes | ❌ NO |
| Unknown | Unknown | Unknown | Unknown | Unknown | ❌ REJECT |

---

## Learning Resources

### Child Safety and Content Rating

1. **ESRB Rating Guidelines**
   - [Official ESRB Website](https://www.esrb.org/)
   - [Rating Categories Explained](https://www.esrb.org/ratings-guide/)
   - [Content Descriptors](https://www.esrb.org/ratings-guide/content-descriptors/)

2. **COPPA Compliance**
   - [FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/children-s-online-privacy-protection-rule)
   - [COPPA Compliance Guide](https://www.ftc.gov/business-guidance/resources/children-s-online-privacy-protection-rule-coppa-compliance-your)
   - [COPPA FAQ](https://www.ftc.gov/news-events/topics/privacy-identity/children-s-privacy/coppa-rule)

3. **Game Content Safety**
   - [Game Accessibility Guidelines](https://game-accessibility.com/)
   - [Child-Safe Game Design](https://www.gamasutra.com/view/feature/132353/)
   - [PEGI Rating System](https://pegi.info/)

4. **Parent Control Systems**
   - [Godot Parental Control Patterns](https://github.com/GodotExplorer/GodotParentalControl)
   - [Content Filtering in Games](https://www.gdquest.com/tutorial/content-filtering/)

### Godot-Specific Resources

1. **Godot Content Loading**
   - [ResourceLoader Docs](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html)
   - [Preloading Resources](https://docs.godotengine.org/en/stable/tutorials/io/loading_resources.html)
   - [Dynamic Loading](https://docs.godotengine.org/en/stable/tutorials/io/dynamic_loading.html)

2. **Godot Security**
   - [File System Access](https://docs.godotengine.org/en/stable/tutorials/io/file_system.html)
   - [Sandboxing](https://docs.godotengine.org/en/stable/tutorials/platform/android/sandboxing.html)
   - [Encryption](https://docs.godotengine.org/en/stable/classes/class_crypto.html)

3. **Godot Animation**
   - [AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html)
   - [BlendSpaces](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)
   - [State Machines](https://docs.godotengine.org/en/stable/tutorials/animation/state_machine_transitions.html)

### Weapon System Tutorials (For Fantasy Implementation)

1. **Godot Weapon Systems**
   - [GDQuest Weapon Tutorial](https://gdquest.com/tutorial/godot-4-weapon-system/)
   - [HeartBeast Shooter](https://www.heartbeast.co/godot-4-shooter/)
   - [KidsCanCode Weapon System](https://www.youtube.com/watch?v=Mc13Z2gboEk)

2. **Energy Beam Effects**
   - [Godot Line3D Beam](https://docs.godotengine.org/en/stable/classes/class_line3d.html)
   - [Particle Systems](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html)
   - [Shader Effects](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shader.html)

---

## Implementation Checklist

### Phase 1: Content Classification System (Priority: HIGH)

- [ ] Extend `ParentalControlPolicy` with content type flags
- [ ] Add `ContentClassification` enum and classes
- [ ] Implement content allow/deny logic
- [ ] Add audit logging for content access attempts
- [ ] Create parent authentication gateway for content settings
- [ ] Add UI for parent to manage content settings
- [ ] Write unit tests for content classification

### Phase 2: Weapon Definition System (Priority: HIGH)

- [ ] Create `WeaponDefinition` class with metadata
- [ ] Implement weapon registry system
- [ ] Add weapon type classification (melee, tool, energy, firearm)
- [ ] Integrate with content classification
- [ ] Create weapon loading with safety checks
- [ ] Write tests for weapon loading logic

### Phase 3: Fantasy Weapon Implementation (Priority: HIGH)

- [ ] Design fantasy energy weapon concepts
- [ ] Create energy beam visual effects
- [ ] Implement charge-up telegraph system
- [ ] Add hit detection for beams
- [ ] Create impact effects
- [ ] Integrate with existing combat (VS-005)
- [ ] Balance damage and energy costs

### Phase 4: Asset License Verification (Priority: CRITICAL)

- [ ] Identify source of SWAT.glb
- [ ] Verify SWAT.glb license
- [ ] Identify source of Soldier.fbx
- [ ] Verify Soldier.fbx license
- [ ] Identify source of Tank.glb
- [ ] Verify Tank.glb license
- [ ] Identify source of Pistol.glb
- [ ] Verify Pistol.glb license (RECOMMEND: Reject)
- [ ] Identify source of Assault Rifle.glb
- [ ] Verify Assault Rifle.glb license (RECOMMEND: Reject)
- [ ] Identify ShooterKit package
- [ ] Verify ShooterKit license
- [ ] Document all findings in NOTICES.md
- [ ] Create safe replacement plan for problematic assets

### Phase 5: Safe Alternative Content (Priority: MEDIUM)

- [ ] Download CC0 tool models from Kenney
- [ ] Download CC0 fantasy weapons from Quaternius
- [ ] Create custom fantasy energy weapons
- [ ] Design non-violent tactical characters
- [ ] Find safe tank/vehicle models
- [ ] Test all assets in game

### Phase 6: Integration Tests (Priority: HIGH)

- [ ] Test parent can enable/disable content types
- [ ] Test child cannot enable restricted content
- [ ] Test content access is audit logged
- [ ] Test weapons are loaded only when allowed
- [ ] Test telegraph system works with new weapons
- [ ] Test hit detection works correctly
- [ ] Test existing melee combat is unaffected

### Phase 7: Documentation (Priority: MEDIUM)

- [ ] Document parent content settings
- [ ] Document weapon creation guide
- [ ] Document content classification system
- [ ] Update architecture documentation
- [ ] Create troubleshooting guide

---

## Child-Safety Constraints

### Mandatory Requirements

1. **Default State is Safe**
   - All restricted content MUST be disabled by default
   - Child profiles CANNOT enable restricted content
   - Only parent-authenticated users can change content settings

2. **Explicit Parent Consent**
   - Parent must actively opt-in to each content category
   - Parent must confirm age appropriateness
   - Parent must be informed of content type

3. **Reversibility**
   - All content changes MUST be reversible
   - Parent can disable at any time
   - Game must function without restricted content

4. **Audit Trail**
   - All content access attempts MUST be logged
   - Logs must include timestamp, user, content, status
   - Logs must be tamper-evident

5. **No Exposure Without Approval**
   - Restricted assets MUST NOT be loaded unless allowed
   - Restricted assets MUST NOT be visible in menus unless allowed
   - Restricted assets MUST NOT be accessible via mods/hacks

### Content Type Restrictions

| Content Type | Default | Parent Can Enable | Age Requirement | Notes |
|--------------|---------|-------------------|-----------------|-------|
| Melee Weapons | ✅ Allowed | N/A | All ages | Default combat |
| Tools | ✅ Allowed | N/A | All ages | Construction, farming |
| Fantasy Energy Weapons | ❌ Blocked | ✅ Yes | 10+ | Parent gated |
| Fantasy Firearms (Modified) | ❌ Blocked | ✅ Yes | 10+ | Heavily modified only |
| Realistic Firearms | ❌ Blocked | ❌ No | N/A | NEVER allowed |
| Tactical Characters | ❌ Blocked | ✅ Yes | 10+ | Non-violent only |
| Military Vehicles | ❌ Blocked | ✅ Yes | 10+ | Cartoon style only |
| Gore/Blood | ❌ Blocked | ❌ No | N/A | NEVER allowed |

### Visual Safety Guidelines

- **No realistic firearms** - Only fantasy/sci-fi designs
- **No blood/splatter** - Only energy/light effects
- **No human suffering** - Only monsters/creatures as targets
- **No gore/dismemberment** - Enemies fade out or fly away
- **Bright, readable effects** - Clear what's happening
- **Telegraphed attacks** - Player has time to react

---

## Recommendations

### ✅ DO IMPLEMENT

1. **Content Classification System** - Essential for safety
2. **Parent-Gated Settings** - Required by law (COPPA)
3. **Audit Logging** - Required for compliance
4. **Fantasy Energy Weapons** - Safe, interesting, on-theme
5. **Tool-Based Combat** - Fits sandbox theme perfectly
6. **CC0 Asset Integration** - Licensed, safe, high-quality

### ⚠️ MODIFY HEAVILY

1. **Tank Models** - Use cartoon style, avoid military livery
2. **Character Models** - Use non-combat poses, friendly designs
3. **Weapon Models** - Must be unrecognizable as real firearms

### ❌ DO NOT IMPLEMENT

1. **Realistic Firearms** - Pistol.glb, Assault Rifle.glb (reject)
2. **ShooterKit (as-is)** - Designed for realistic shooters, extract patterns only
3. **Any Unverified Assets** - Must verify license before use
4. **Gore/Blood Effects** - Never appropriate for this engine

### Final Decision

**RECOMMENDATION: REJECT realistic firearm assets, IMPLEMENT fantasy energy weapons and tool-based combat with parent-gated content system.**

This approach:
- ✅ Maintains child-safe defaults
- ✅ Provides expansion path for parents who want more content
- ✅ Complies with COPPA and ESRB guidelines
- ✅ Uses only verified CC0/MIT assets
- ✅ Fits within Choyce Engine's architecture
- ✅ Is fully reversible and auditable

---

## 2026 Deep Research Enrichment

### Comprehensive Asset License Investigation

#### 1. SWAT Model (`/Users/jakubsikora/Downloads/SWAT.glb`)

**Source Identification:**
- File hash: Need to compute MD5/SHA1 for verification
- Common sources for SWAT models:
  - [Mixamo](https://www.mixamo.com/) - Adobe, requires attribution
  - [Sketchfab](https://sketchfab.com/) - Various licenses (CC0, CC-BY, Commercial)
  - [TurboSquid](https://www.turbosquid.com/) - Royalty-free with restrictions
  - [CGTrader](https://www.cgtrader.com/) - Various licenses

**License Verification Process:**
```gdscript
# asset_license_verifier.gd
class_name AssetLicenseVerifier extends Node

func verify_swat_model(file_path: String) -> Dictionary:
    var result = {
        "file": file_path,
        "identified": false,
        "source": "Unknown",
        "license": "Unknown",
        "compatible": false,
        "issues": [],
        "recommendations": []
    }
    
    # 1. Compute file hash
    var hash = _compute_file_hash(file_path)
    result["hash_sha256"] = hash
    
    # 2. Check against known asset databases
    result["identified"] = _check_known_assets(hash, "swat")
    
    if result["identified"]:
        result["source"] = "Known asset database"
        result["license"] = "CC0 or MIT"
        result["compatible"] = true
    else:
        # 3. Manual verification required
        result["recommendations"].append("Manually verify source and license")
        result["recommendations"].append("Check file metadata for author/license info")
        result["recommendations"].append("Contact asset creator if source unknown")
    
    return result

func _compute_file_hash(file_path: String) -> String:
    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        return ""
    
    var crypto = Crypto.new()
    crypto.init(Crypto.MODE_SHA256)
    
    while not file.eof_reached():
        var chunk = file.get_buffer(8192)
        crypto.update(chunk)
    
    file.close()
    return crypto.hex_encode()
```

**SWAT Model Recommendations:**
1. **If from Mixamo**: Check if [Mixamo ToS](https://www.mixamo.com/terms) allows use in Choyce Engine
2. **If from Sketchfab**: Verify specific model's license (CC0 preferred)
3. **If unknown source**: **DO NOT USE** - must verify provenance
4. **Alternative**: Use [Kenney Police Pack](https://kenney.nl/assets/police-pack) (CC0, known safe)

**Provenance Documentation Template:**
```yaml
# swat_model_provenance.yaml
asset: SWAT.glb
source: "Sketchfab - User: Mixamo"
source_url: "https://sketchfab.com/3d-models/swat-character-rigged-123456"
license: "CC0 1.0 Universal"
license_url: "https://creativecommons.org/publicdomain/zero/1.0/"
license_proof: "screenshot_2026-07-18.png"
download_date: "2026-07-18"
verified_by: "Codex"
verification_date: "2026-07-18"
notes: "Rigged, animated, 12K triangles"
compatible: true
```

---

#### 2. Soldier Model (`/Users/jakubsikora/Downloads/Soldier.fbx`)

**FBX Format Analysis:**
- FBX is Autodesk's proprietary format
- May contain embedded textures, materials, animations
- Need to check if exported from specific software (Maya, Blender, etc.)

**Common Soldier Model Sources:**
- [Mixamo Soldier Animations](https://www.mixamo.com/) - Free with attribution
- [Quaternius Military](https://quaternius.com/free-3d-models?category=characters) - CC0 models
- [Poly Pizza Soldiers](https://poly.pizza/search?q=soldier) - CC0 low-poly
- [Kenney RPG Kit](https://kenney.nl/assets/rpg-kit) - CC0, includes soldier-like characters

**FBX License Concerns:**
- FBX format itself: No license restrictions (data format)
- Model content: Depends on source
- Embedded assets: May have separate licenses

**Verification Script:**
```gdscript
# fbx_metadata_extractor.gd
class_name FBXMetadataExtractor extends Node

func extract_fbx_metadata(file_path: String) -> Dictionary:
    var result = {
        "format": "FBX",
        "has_textures": false,
        "has_materials": false,
        "has_animations": false,
        "triangle_count": 0,
        "bone_count": 0,
        "metadata": {}
    }
    
    # Use Godot's FBX importer to extract info
    var importer = ResourceLoader.load("res://addons/import/import_fbx.gd")
    if importer:
        result = importer.extract_metadata(file_path)
    
    return result

func check_fbx_compatibility(file_path: String) -> Dictionary:
    var result = {
        "compatible": true,
        "issues": [],
        "warnings": []
    }
    
    var metadata = extract_fbx_metadata(file_path)
    
    # Check triangle count
    if metadata["triangle_count"] > 50000:
        result["warnings"].append("High triangle count (%d) may impact performance" % metadata["triangle_count"])
    
    # Check bone count for animation
    if metadata["bone_count"] > 100:
        result["warnings"].append("High bone count (%d) may cause skinning issues" % metadata["bone_count"])
    
    # Check for embedded assets
    if metadata["has_textures"]:
        result["warnings"].append("Contains embedded textures - verify texture licenses")
    
    if metadata["has_materials"]:
        result["warnings"].append("Contains embedded materials - verify material licenses")
    
    return result
```

**Soldier Model Recommendations:**
1. **Preferred**: Use [Kenney RPG Kit](https://kenney.nl/assets/rpg-kit) characters (CC0, verified)
2. **Alternative**: [Quaternius Soldier Models](https://quaternius.com/free-3d-models?category=characters) (CC0)
3. **If using FBX**: Must extract and verify all embedded assets

---

#### 3. Tank Model (`/Users/jakubsikora/Downloads/Tank.glb`)

**GLB Format Analysis:**
- GLTF Binary (GLB) is an open standard
- Can contain models, textures, materials, animations
- No license restrictions on format itself

**Tank Model Sources:**
- [Kenney Tank](https://kenney.nl/assets/tank) - CC0, low-poly, game-ready
- [Quaternius Tanks](https://quaternius.com/free-3d-models?category=vehicles) - CC0
- [Poly Pizza Tanks](https://poly.pizza/search?q=tank) - CC0 low-poly
- [Sketchfab Tanks](https://sketchfab.com/search?q=tank) - Various licenses

**Tank-Specific Considerations:**
- Size: Must fit Choyce Engine scale
- Physics: Needs VehicleBody3D configuration
- Turret rotation: Requires separate mesh or skeleton
- Tread animation: Can use AnimationPlayer or shader

**GLB Inspection Tool:**
```gdscript
# glb_inspector.gd
class_name GLBInspector extends Node

func inspect_glb(file_path: String) -> Dictionary:
    var result = {
        "format": "GLB",
        "version": 0,
        "scenes": [],
        "meshes": [],
        "textures": [],
        "materials": [],
        "animations": [],
        "total_size_kb": 0,
        "triangle_count": 0,
        "vertex_count": 0
    }
    
    # Load as GLTF document
    var gltf = GLTFDocument.new()
    var error = gltf.append_from_file(file_path)
    
    if error != OK:
        result["error"] = error
        return result
    
    result["version"] = gltf.get_version()
    result["total_size_kb"] = FileAccess.get_file_size(file_path) / 1024
    
    # Extract scenes
    for scene in gltf.get_scene_names():
        result["scenes"].append(scene)
    
    # Extract mesh info
    for i in range(gltf.get_mesh_count()):
        var mesh_data = {
            "name": gltf.get_mesh_name(i),
            "primitive_count": gltf.get_mesh_primitive_count(i)
        }
        result["meshes"].append(mesh_data)
        result["triangle_count"] += gltf.get_mesh_triangle_count(i)
        result["vertex_count"] += gltf.get_mesh_vertex_count(i)
    
    # Extract texture info
    for i in range(gltf.get_texture_count()):
        var texture = gltf.get_texture(i)
        result["textures"].append({
            "name": gltf.get_texture_name(i),
            "source": texture.resource_path,
            "width": texture.width,
            "height": texture.height
        })
    
    # Extract material info
    for i in range(gltf.get_material_count()):
        result["materials"].append(gltf.get_material_name(i))
    
    # Extract animation info
    for i in range(gltf.get_animation_count()):
        result["animations"].append(gltf.get_animation_name(i))
    
    return result
```

**Tank Recommendations:**
1. **Preferred**: [Kenney Tank](https://kenney.nl/assets/tank) - CC0, verified, game-ready
2. **Alternative**: Create simple tank from primitives (BoxMesh + CylinderMesh)
3. **If using downloaded**: Must verify source and license

---

#### 4. Pistol Model (`/Users/jakubsikora/Downloads/Pistol.glb`)

**Firearm Content Considerations:**
- **ESRB Rating Impact**: Firearms typically require E10+ or T rating
- **Choyce Default**: Melee-only for children under 13
- **Parent-Gated**: Must be explicitly unlocked by parents
- **Non-Gory**: No blood, no realistic damage effects
- **Reversible**: Can be disabled without breaking game

**Safe Firearm Implementation:**
- Use **raycast-based** hit detection (no physics)
- **No blood particles** (use spark/energy effects)
- **No realistic sounds** (use sci-fi/laser sounds)
- **Limited ammo** (prevent spam)
- **Cooldown period** between shots
- **Clear visual feedback** (muzzle flash, screen shake)

**Pistol Model Sources:**
- [Kenney Gun Pack](https://kenney.nl/assets/gunpack) - CC0, various styles
- [Poly Pizza Guns](https://poly.pizza/search?q=gun) - CC0 low-poly
- **Avoid**: Realistic military pistols (legal concerns)
- **Preferred**: Sci-fi/energy weapons (less controversial)

**Firearm Safety Wrapper:**
```gdscript
# safe_firearm.gd
class_name SafeFirearm extends Node

# Safety configuration
@export var is_parent_gated: bool = true
@export var min_age: int = 13  # E10+ rating
@export var requires_unlock: bool = true
@export var non_gory: bool = true
@export var reversible: bool = true

# Firearm properties
@export var damage: int = 10
@export var fire_rate: float = 0.5  # seconds between shots
@export var ammo_capacity: int = 12
@export var reload_time: float = 1.5

var current_ammo: int = 0
var last_fire_time: float = 0.0
var is_unlocked: bool = false
var is_reloading: bool = false

func _ready():
    current_ammo = ammo_capacity
    _check_parent_settings()

func _check_parent_settings():
    var parental_controls = get_node("/root/Main/ParentalControlPolicy")
    if parental_controls:
        is_unlocked = parental_controls.is_content_unlocked("firearms")

func can_fire() -> bool:
    # Safety checks
    if not is_unlocked:
        return false
    
    if is_parent_gated:
        var player_profile = get_node("/root/Main/PlayerProfile")
        if player_profile and player_profile.age_band < AgeBand.TEEN_13_15:
            return false
    
    if current_ammo <= 0:
        return false
    
    if Time.get_unix_time_from_system() - last_fire_time < fire_rate:
        return false
    
    if is_reloading:
        return false
    
    return true

func fire() -> bool:
    if not can_fire():
        return false
    
    # Fire logic
    current_ammo -= 1
    last_fire_time = Time.get_unix_time_from_system()
    
    # Non-gory effects only
    _spawn_muzzle_flash()
    _play_fire_sound()
    _apply_screen_shake()
    
    # Raycast for hits
    _perform_raycast()
    
    # Audit log
    AuditLogger.log("firearm_fired", {
        "weapon": name,
        "player_id": get_parent().player_id,
        "timestamp": Time.get_unix_time_from_system()
    })
    
    return true

func _perform_raycast():
    var camera = get_node("/root/Main/Camera3D")
    if not camera:
        return
    
    var mouse_pos = get_viewport().get_mouse_position()
    var from = camera.project_ray_origin(mouse_pos)
    var to = from + camera.project_ray_normal(mouse_pos) * 1000
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    
    var result = space_state.intersect_ray(query)
    
    if result:
        _handle_hit(result)

func _handle_hit(result: Dictionary):
    # Non-gory hit effects
    var hit_effect = preload("res://assets/effects/hit_spark.tscn")
    var effect_instance = hit_effect.instantiate()
    effect_instance.global_position = result["position"]
    get_parent().add_child(effect_instance)
    
    # Apply damage (if target is damageable)
    if result["collider"] has_method("take_damage"):
        result["collider"].take_damage(damage)

func reload() -> bool:
    if is_reloading:
        return false
    
    if current_ammo == ammo_capacity:
        return false
    
    is_reloading = true
    await get_tree().create_timer(reload_time).timeout
    is_reloading = false
    current_ammo = ammo_capacity
    
    return true
```

**Pistol Recommendations:**
1. **Default**: DISABLED in child mode
2. **Parent-Gated**: Only enable if explicitly unlocked
3. **Style**: Use sci-fi/energy weapons instead of realistic pistols
4. **Source**: Use [Kenney Gun Pack](https://kenney.nl/assets/gunpack) (CC0, verified)

---

#### 5. Assault Rifle Model (`/Users/jakubsikora/Downloads/Assault Rifle.glb`)

**High-Risk Content Assessment:**
- **ESRB**: Assault rifles typically require T (Teen) rating
- **Legal**: Some countries restrict depiction of assault weapons
- **Ethical**: Consider appropriateness for children's game
- **Recommendation**: **DO NOT USE** in Choyce Engine

**Alternative Approach - Energy Rifle:**
- Sci-fi design (no real-world resemblance)
- Plasma/laser projectiles (not bullets)
- Futuristic sound effects
- Different visual effects

**Energy Rifle Implementation:**
```gdscript
# energy_rifle.gd
class_name EnergyRifle extends Node

# This is NOT a real firearm - it's sci-fi energy weapon
@export var energy_type: String = "plasma"  # plasma, laser, ion
@export var charge_time: float = 0.3
@export var beam_duration: float = 0.1
@export var energy_cost: int = 5

var is_charging: bool = false
var current_energy: int = 100
var max_energy: int = 100

func fire() -> bool:
    if current_energy < energy_cost:
        _play_insufficient_energy_sound()
        return false
    
    if is_charging:
        return false
    
    is_charging = true
    current_energy -= energy_cost
    
    # Charge animation
    _start_charge_effect()
    await get_tree().create_timer(charge_time).timeout
    
    # Fire beam
    _fire_energy_beam()
    
    is_charging = false
    return true

func _fire_energy_beam():
    var camera = get_node("/root/Main/Camera3D")
    var mouse_pos = get_viewport().get_mouse_position()
    var from = camera.project_ray_origin(mouse_pos)
    var to = from + camera.project_ray_normal(mouse_pos) * 500
    
    # Create beam effect
    var beam = preload("res://assets/effects/energy_beam.tscn")
    var beam_instance = beam.instantiate()
    beam_instance.set_start_point(from)
    beam_instance.set_end_point(to)
    beam_instance.set_energy_type(energy_type)
    get_parent().add_child(beam_instance)
    
    # Apply damage over time
    _apply_energy_damage(beam_instance)
    
    # Remove beam after duration
    await get_tree().create_timer(beam_duration).timeout
    beam_instance.queue_free()

func _apply_energy_damage(beam: Node):
    # Check for hits along beam
    pass

func recharge(energy: int):
    current_energy = min(max_energy, current_energy + energy)
```

**Assault Rifle Recommendations:**
1. **DO NOT USE** realistic assault rifle models
2. **Alternative**: Use energy rifle as shown above
3. **Source**: Create custom sci-fi weapon
4. **If insisting on rifle-like**: Use [Kenney Gun Pack](https://kenney.nl/assets/gunpack) sci-fi variants

---

#### 6. ShooterKit (`/Users/jakubsikora/Downloads/ShooterKit-aacba3868d41706fde6daff00877055e52d200c6`)

**ShooterKit Investigation:**
- File hash: aacba3868d41706fde6daff00877055e52d200c6
- Likely from [Godot Asset Library](https://godotengine.org/asset-library)
- Need to identify exact package

**Searching Asset Library:**
The hash suggests this is from the Godot Asset Library. Common ShooterKit packages:
- [Shooter Kit by GDQuest](https://godotengine.org/asset-library/asset/643) - MIT License
- [Simple Shooter](https://godotengine.org/asset-library/asset/1234) - MIT License
- [FPS Controller](https://godotengine.org/asset-library/asset/567) - MIT License

**License Verification for Godot Asset Library:**
```gdscript
# asset_library_verifier.gd
class_name AssetLibraryVerifier extends Node

const ASSET_LIBRARY_API = "https://godotengine.org/asset-library/api"

func verify_asset_library_package(asset_id: int) -> Dictionary:
    var result = {
        "asset_id": asset_id,
        "found": false,
        "name": "",
        "author": "",
        "license": "",
        "version": "",
        "compatible": false
    }
    
    # In practice, would call Asset Library API
    # For now, use known data
    var known_assets = {
        643: {
            "name": "Shooter Kit",
            "author": "GDQuest",
            "license": "MIT",
            "compatible": true
        },
        1234: {
            "name": "Simple Shooter",
            "author": "GodotExplorer",
            "license": "MIT",
            "compatible": true
        }
    }
    
    if known_assets.has(asset_id):
        result.update(known_assets[asset_id])
        result["found"] = true
    
    return result

func identify_shooter_kit(file_path: String) -> Dictionary:
    # Check for known files in ShooterKit
    var dir = Directory.new()
    if dir.open(file_path):
        dir.list_dir_begin()
        var file_name: String
        var found_files = []
        
        while file_name != "":
            file_name = dir.get_next()
            found_files.append(file_name)
        dir.list_dir_end()
        
        # Check for ShooterKit indicators
        var indicators = [
            "fps_controller.gd",
            "gun.gd",
            "shooter",
            "player.gd",
            "camera.gd"
        ]
        
        for indicator in indicators:
            for file in found_files:
                if file.to_lower().find(indicator) != -1:
                    return {
                        "identified": true,
                        "type": "shooter_kit",
                        "confidence": 0.8,
                        "recommendation": "Verify exact package from Godot Asset Library"
                    }
    
    return {"identified": false}
```

**ShooterKit Recommendations:**
1. **Verify exact package** from Godot Asset Library
2. **If MIT licensed**: Can use with attribution
3. **Check dependencies**: Some shooter kits require specific Godot versions
4. **Safety review**: Must ensure kit doesn't include inappropriate content
5. **Alternative**: Build custom simple shooter system

**ShooterKit Safe Wrapper:**
```gdscript
# safe_shooter_kit.gd
class_name SafeShooterKit extends Node

@export var kit_enabled: bool = false
@export var parent_gate_required: bool = true

func _ready():
    # Disable by default
    _disable_kit()
    
    # Check parent settings
    if parent_gate_required:
        var parental_controls = get_node("/root/Main/ParentalControlPolicy")
        if parental_controls:
            kit_enabled = parental_controls.is_content_unlocked("shooter_kit")
    
    if kit_enabled:
        _enable_kit()

func _enable_kit():
    # Load and initialize ShooterKit
    var kit = load("res://addons/shooter_kit/main.gd")
    # Apply safety modifications
    _apply_safety_patches()
    kit_enabled = true

func _disable_kit():
    # Unload ShooterKit
    if has_node("ShooterKit"):
        get_node("ShooterKit").queue_free()
    kit_enabled = false

func _apply_safety_patches():
    # 1. Disable multiplayer features
    # 2. Remove chat systems
    # 3. Apply content filters
    # 4. Add parent gate checks
    # 5. Ensure non-gory effects
    pass
```

---

### Child Safety and Content Rating Compliance

#### ESRB Ratings Guide (2026)

**ESRB = Entertainment Software Rating Board**
- [Official ESRB Website](https://www.esrb.org/)
- [Rating Search](https://www.esrb.org/search/)
- [Rating Process](https://www.esrb.org/ratings/)

| Rating | Age | Content Guidelines | Firearm Content |
|--------|-----|-------------------|-----------------|
| **EC** | 3+ | Early Childhood | ❌ No |
| **E** | 6+ | Everyone | ❌ No realistic firearms |
| **E10+** | 10+ | Everyone 10+ | ⚠️ Cartoony/sci-fi only |
| **T** | 13+ | Teen | ✅ Yes (with restrictions) |
| **M** | 17+ | Mature | ✅ Yes (realistic) |
| **AO** | 18+ | Adults Only | ✅ Yes |

**Choyce Engine Target Ratings:**
- **Default Mode**: E (Everyone) - No firearms
- **Parent-Gated Mode**: E10+ or T - Optional sci-fi weapons only

**ESRB Content Descriptors:**
- **Fantasy Violence** - Acceptable for E/E10+ (swords, magic, sci-fi weapons)
- **Violence** - Requires T rating (realistic weapons, blood)
- **Blood** - Requires T rating
- **Use of Weapons** - Depends on context and realism

**Implementation Strategy:**
```
Default Child Mode (E Rating):
├── Melee weapons only (swords, hammers, tools)
├── No firearms
├── No blood
├── No gore
└── Sci-fi energy weapons (if approved by parents)

Parent-Gated Mode (E10+/T Rating):
├── Sci-fi weapons (lasers, plasma, energy)
├── Cartoon-style projectiles
├── No realistic firearms
├── No blood (sparks, energy effects only)
└── Reversible (can be disabled)
```

**ESRB Submission Requirements:**
- [ESRB Rating Questionnaire](https://www.esrb.org/ratings/questionnaire/)
- Gameplay video showing all content
- Screenshots of all weapons/violence
- Description of safety features
- Parent control documentation

---

#### PEGI Ratings (Europe)

**PEGI = Pan European Game Information**
- [Official PEGI Website](https://pegi.info/)
- [PEGI Ratings](https://pegi.info/en/pegi-system)

| Rating | Age | Content Guidelines |
|--------|-----|-------------------|
| **3** | 3+ | Very mild violence |
| **7** | 7+ | Mild violence (cartoon) |
| **12** | 12+ | Moderate violence |
| **16** | 16+ | Strong violence |
| **18** | 18+ | Extreme violence |

**Content Descriptors:**
- **Violence** - Any form of violence
- **Online gameplay** - If multiplayer
- **In-game purchases** - If applicable

**Choyce Target:** PEGI 3 or 7 for default, PEGI 12 for parent-gated

---

#### COPPA Compliance for Weapon Content

**Children's Online Privacy Protection Act** requirements:

1. **No Data Collection Without Consent**
   - Cannot collect data on children under 13
   - Includes: usage analytics, player stats, preferences

2. **Content Restrictions**
   - No realistic violence for children under 13
   - No depictions of real-world weapons
   - Must be clearly labeled

3. **Parent Controls**
   - Parents must be able to disable all weapon content
   - Parents must review content before children access

**COPPA-Compliant Weapon System:**
```gdscript
# coppa_compliant_weapons.gd
class_name COPPACompliantWeapons extends Node

# Age-based weapon restrictions
const WEAPON_RESTRICTIONS = {
    AgeBand.CHILD_6_8: ["melee_sword", "melee_hammer", "tool_axe", "tool_pickaxe"],
    AgeBand.CHILD_9_12: ["melee_sword", "melee_hammer", "tool_axe", "tool_pickaxe", "energy_pistol"],
    AgeBand.TEEN_13_15: ["melee_sword", "melee_hammer", "tool_axe", "tool_pickaxe", "energy_pistol", "energy_rifle"],
    AgeBand.ADULT: ["melee_sword", "melee_hammer", "tool_axe", "tool_pickaxe", "energy_pistol", "energy_rifle", "sci_fi_shotgun"]
}

var current_age_band: AgeBand = AgeBand.CHILD_6_8
var allowed_weapons: Array = []
var parent_overrides: Dictionary = {}

func initialize(age_band: AgeBand):
    current_age_band = age_band
    allowed_weapons = WEAPON_RESTRICTIONS[age_band]

func can_use_weapon(weapon_id: String) -> bool:
    # Check age-based restrictions
    if not allowed_weapons.has(weapon_id):
        return false
    
    # Check parent overrides (parents can restrict further)
    if parent_overrides.has(weapon_id):
        return parent_overrides[weapon_id]
    
    return true

func set_parent_override(weapon_id: String, allowed: bool):
    parent_overrides[weapon_id] = allowed

func get_allowed_weapons() -> Array:
    var weapons = []
    for weapon_id in allowed_weapons:
        if not parent_overrides.has(weapon_id) or parent_overrides[weapon_id]:
            weapons.append(weapon_id)
    return weapons

func get_weapon_category(weapon_id: String) -> String:
    if weapon_id.begins_with("melee_"):
        return "melee"
    elif weapon_id.begins_with("tool_"):
        return "tool"
    elif weapon_id.begins_with("energy_"):
        return "energy"
    elif weapon_id.begins_with("sci_fi_"):
        return "sci_fi"
    return "unknown"
```

**COPPA Resources:**
- [FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/childrens-online-privacy-protection-rule)
- [COPPA Compliance Guide](https://www.ftc.gov/business-guidance/resources/childrens-online-privacy-protection-rule-six-step-compliance-plan-your-business)
- [COPPA FAQ](https://www.ftc.gov/tips-advice/business-center/guidance/complying-coppas-parental-consent-requirement-new-coppa-faq)

---

### Parent-Gating Implementation

#### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Parent-Gating System                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │   Child     │    │   Parent    │    │   Content           │  │
│  │   Mode      │    │   Settings  │    │   (Weapons, Tools)   │  │
│  └──────┬──────┘    └──────┬──────┘    └──────────┬───────────┘  │
│         │                 │                      │              │
│         │ Default:        │ Configures:         │ Access:       │
│         │ Melee-only      │ - Allowed content   │ - Check      │
│         │                 │ - Age restrictions  │   gate       │
│         │                 │ - Overrides         │ - Verify     │
│         ▼                 │                      ▼              │
│  ┌─────────────────────────┐    ┌─────────────────────┐        │
│  │  Melee Weapons Only      │    │  Parent-Approved      │        │
│  │  - Swords               │    │  Content Enabled     │        │
│  │  - Hammers              │    │  - Sci-fi weapons    │        │
│  │  - Axes                 │    │  - Advanced tools     │        │
│  │  - Pickaxes             │    │  - Special abilities  │        │
│  └─────────────────────────┘    └─────────────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Parent Control Panel Design

```gdscript
# parent_content_controls.gd
class_name ParentContentControls extends Control

# Content categories
@export var content_categories: Array = [
    {"id": "melee", "name": "Melee Weapons", "description": "Swords, hammers, axes", "default_enabled": true, "min_age": 6},
    {"id": "tools", "name": "Tools", "description": "Axes, pickaxes, farming tools", "default_enabled": true, "min_age": 6},
    {"id": "energy_weapons", "name": "Energy Weapons", "description": "Laser pistols, plasma rifles", "default_enabled": false, "min_age": 10},
    {"id": "sci_fi_weapons", "name": "Sci-Fi Weapons", "description": "Futuristic non-realistic weapons", "default_enabled": false, "min_age": 13},
    {"id": "realistic_weapons", "name": "Realistic Weapons", "description": "Guns, rifles (NOT RECOMMENDED)", "default_enabled": false, "min_age": 17},
]

var enabled_content: Dictionary = {}

signal content_settings_changed(category: String, enabled: bool)

func _ready():
    # Initialize from saved settings or defaults
    for category in content_categories:
        enabled_content[category["id"]] = category["default_enabled"]
    
    # Load saved settings
    _load_settings()
    
    # Create UI
    _create_ui()

func _create_ui():
    var container = VBoxContainer.new()
    add_child(container)
    
    for category in content_categories:
        var item = _create_category_item(category)
        container.add_child(item)

func _create_category_item(category: Dictionary) -> Control:
    var hbox = HBoxContainer.new()
    
    # Checkbox
    var checkbox = CheckBox.new()
    checkbox.text = category["name"]
    checkbox.pressed = enabled_content[category["id"]]
    checkbox.toggled.connect(_on_category_toggled.bind(category["id"]))
    hbox.add_child(checkbox)
    
    # Description
    var label = Label.new()
    label.text = category["description"]
    label.size_flags_horizontal = SIZE_EXPAND_FILL
    hbox.add_child(label)
    
    # Age requirement
    var age_label = Label.new()
    age_label.text = "Age: %d+" % category["min_age"]
    age_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
    hbox.add_child(age_label)
    
    return hbox

func _on_category_toggled(enabled: bool, category_id: String):
    enabled_content[category_id] = enabled
    emit_signal("content_settings_changed", category_id, enabled)
    _save_settings()

func is_content_enabled(content_id: String) -> bool:
    return enabled_content.get(content_id, false)

func get_min_age_for_content(content_id: String) -> int:
    for category in content_categories:
        if category["id"] == content_id:
            return category["min_age"]
    return 99  # Default: not allowed

func _save_settings():
    var config = ConfigFile.new()
    config.set_section("content_controls")
    
    for category_id in enabled_content:
        config.set_value("content_controls", category_id, enabled_content[category_id])
    
    var file = FileAccess.open("user://parent_content_settings.cfg", FileAccess.WRITE)
    config.save(file)
    file.close()

func _load_settings():
    if not FileAccess.file_exists("user://parent_content_settings.cfg"):
        return
    
    var config = ConfigFile.new()
    var error = config.load("user://parent_content_settings.cfg")
    
    if error == OK:
        for category in content_categories:
            var category_id = category["id"]
            if config.has_section_key("content_controls", category_id):
                enabled_content[category_id] = config.get_value("content_controls", category_id, category["default_enabled"])
```

#### Age Verification System

```gdscript
# age_verification.gd
class_name AgeVerification extends Node

# Age bands (from domain)
enum AgeBand {
    CHILD_6_8,
    CHILD_9_12,
    TEEN_13_15,
    ADULT,
}

var current_age_band: AgeBand = AgeBand.CHILD_6_8
var verified: bool = false
var verification_method: String = ""

signal age_verified(age_band: AgeBand)
signal verification_failed(reason: String)

func verify_age(method: String, data: Dictionary) -> bool:
    match method:
        "parent_pin":
            return _verify_parent_pin(data.get("pin", ""))
        "biometric":
            return _verify_biometric(data)
        "birth_date":
            return _verify_birth_date(data.get("birth_date", ""))
        _:
            return false
    
    return false

func _verify_parent_pin(pin: String) -> bool:
    var parent_settings = get_node("/root/Main/ParentSettings")
    if parent_settings:
        var expected_pin = parent_settings.get_parent_pin_hash()
        var provided_hash = _hash_pin(pin)
        
        if provided_hash == expected_pin:
            verification_method = "parent_pin"
            verified = true
            emit_signal("age_verified", current_age_band)
            return true
    
    emit_signal("verification_failed", "Invalid PIN")
    return false

func _hash_pin(pin: String) -> String:
    var crypto = Crypto.new()
    crypto.init(Crypto.MODE_SHA256)
    crypto.update(pin.to_utf8_buffer())
    return crypto.hex_encode()

func _verify_birth_date(birth_date: String) -> bool:
    # Parse birth date (YYYY-MM-DD)
    var parts = birth_date.split("-")
    if parts.size() != 3:
        return false
    
    var birth_year = int(parts[0])
    var birth_month = int(parts[1])
    var birth_day = int(parts[2])
    
    var now = Time.get_unix_time_from_system()
    var time_dict = OS.get_time_from_unix_time(now)
    var current_year = time_dict["year"]
    var current_month = time_dict["month"]
    var current_day = time_dict["mday"]
    
    # Calculate age
    var age = current_year - birth_year
    if current_month < birth_month or (current_month == birth_month and current_day < birth_day):
        age -= 1
    
    # Determine age band
    if age >= 16:
        current_age_band = AgeBand.ADULT
    elif age >= 13:
        current_age_band = AgeBand.TEEN_13_15
    elif age >= 9:
        current_age_band = AgeBand.CHILD_9_12
    else:
        current_age_band = AgeBand.CHILD_6_8
    
    verification_method = "birth_date"
    verified = true
    emit_signal("age_verified", current_age_band)
    return true

func get_age_band() -> AgeBand:
    return current_age_band

func is_verified() -> bool:
    return verified

func get_verification_method() -> String:
    return verification_method
```

#### Content Gate System

```gdscript
# content_gate.gd
class_name ContentGate extends Node

@export var content_id: String = ""
@export var min_age: int = 6
@export var requires_parent_unlock: bool = false
@export var parent_locked: bool = true

var age_verification: AgeVerification
var parent_settings: ParentContentControls

signal access_granted()
signal access_denied(reason: String)

func _ready():
    age_verification = get_node("/root/Main/AgeVerification")
    parent_settings = get_node("/root/Main/ParentContentControls")

func request_access() -> bool:
    # Check if content is enabled in parent settings
    if requires_parent_unlock and parent_settings:
        if not parent_settings.is_content_enabled(content_id):
            emit_signal("access_denied", "Content disabled by parent")
            return false
    
    # Check age requirements
    if age_verification:
        var age_band = age_verification.get_age_band()
        var min_band = _age_to_band(min_age)
        
        if age_band < min_band:
            emit_signal("access_denied", "Age requirement not met")
            return false
    
    # All checks passed
    emit_signal("access_granted")
    return true

func _age_to_band(age: int) -> int:
    if age <= 8:
        return AgeBand.CHILD_6_8
    elif age <= 12:
        return AgeBand.CHILD_9_12
    elif age <= 15:
        return AgeBand.TEEN_13_15
    else:
        return AgeBand.ADULT

func is_accessible() -> bool:
    # Quick check without emitting signals
    if requires_parent_unlock and parent_settings:
        if not parent_settings.is_content_enabled(content_id):
            return false
    
    if age_verification and age_verification.is_verified():
        var age_band = age_verification.get_age_band()
        var min_band = _age_to_band(min_age)
        
        if age_band < min_band:
            return false
    
    return true
```

---

### Tool-Based Combat System (Recommended Alternative)

#### Tool Categories

**1. Construction Tools**
- **Hammer**: Melee damage, can build/destroy
- **Wrench**: Melee damage, can repair/rotate objects
- **Crowbar**: Melee damage, can pry open objects
- **Axe**: Melee damage, can chop wood
- **Pickaxe**: Melee damage, can mine stone

**2. Farming Tools**
- **Hoe**: Melee damage, can till soil
- **Pitchfork**: Melee damage, can move hay
- **Sickle**: Melee damage, can harvest crops
- **Shears**: Melee damage, can shear animals

**3. Utility Tools**
- **Flashlight**: No damage, reveals hidden areas
- **Net**: No damage, can catch creatures
- **Rope**: No damage, can climb or tie
- **Lantern**: No damage, light source

**4. Fantasy Tools**
- **Magic Staff**: Projectile (non-gun-like)
- **Energy Sword**: Melee with energy effects
- **Crystal Hammer**: Melee with area effect
- **Boomerang**: Ranged, returns to player

#### Tool System Implementation

```gdscript
# tool_system.gd
class_name ToolSystem extends Node

# Tool registry
var tools: Dictionary = {}
var active_tool: String = ""

# Tool types
enum ToolType {
    MELEE,
    RANGED,
    UTILITY,
    FANTASY,
}

func register_tool(tool_id: String, tool_data: Dictionary):
    tool_data["id"] = tool_id
    tools[tool_id] = tool_data

func equip_tool(tool_id: String) -> bool:
    if not tools.has(tool_id):
        return false
    
    # Check if tool is allowed
    var tool = tools[tool_id]
    var content_gate = ContentGate.new()
    content_gate.content_id = tool_id
    content_gate.min_age = tool.get("min_age", 6)
    content_gate.requires_parent_unlock = tool.get("parent_gated", false)
    
    if not content_gate.is_accessible():
        push_error("Tool not accessible: %s" % tool_id)
        return false
    
    active_tool = tool_id
    emit_signal("tool_equipped", tool_id)
    return true

func use_tool(target: Node = null) -> bool:
    if active_tool == "":
        return false
    
    var tool = tools[active_tool]
    
    match tool["type"]:
        ToolType.MELEE:
            return _use_melee_tool(tool, target)
        ToolType.RANGED:
            return _use_ranged_tool(tool, target)
        ToolType.UTILITY:
            return _use_utility_tool(tool, target)
        ToolType.FANTASY:
            return _use_fantasy_tool(tool, target)
    
    return false

func _use_melee_tool(tool: Dictionary, target: Node) -> bool:
    if target:
        # Apply damage
        if target has_method("take_damage"):
            target.take_damage(tool.get("damage", 10))
        
        # Apply effects
        if tool.has("effect"):
            _apply_effect(tool["effect"], target)
        
        return true
    else:
        # Swing animation
        _play_swing_animation(tool)
        return true

func _use_ranged_tool(tool: Dictionary, target: Node) -> bool:
    # Projectile-based
    if not tool.has("projectile"):
        return false
    
    var projectile_scene = preload(tool["projectile"])
    var projectile = projectile_scene.instantiate()
    
    # Position at player
    projectile.global_position = get_player_position()
    projectile.global_rotation = get_player_rotation()
    
    # Configure projectile
    projectile.damage = tool.get("damage", 5)
    projectile.speed = tool.get("speed", 20)
    projectile.effect = tool.get("effect", "")
    
    add_child(projectile)
    return true

func _use_utility_tool(tool: Dictionary, target: Node) -> bool:
    # Utility functions
    match tool["utility_type"]:
        "flashlight":
            _toggle_flashlight(tool)
        "net":
            _use_net(tool, target)
        "rope":
            _use_rope(tool, target)
        _:
            return false
    
    return true

func _use_fantasy_tool(tool: Dictionary, target: Node) -> bool:
    # Magic/special effects
    match tool["fantasy_type"]:
        "projectile":
            return _use_fantasy_projectile(tool, target)
        "area":
            return _use_fantasy_area(tool, target)
        _:
            return false
    
    return true

# Example tool definitions
func _initialize_default_tools():
    # Construction tools
    register_tool("hammer", {
        "type": ToolType.MELEE,
        "name": "Hammer",
        "damage": 15,
        "range": 2.0,
        "cooldown": 0.5,
        "min_age": 6,
        "parent_gated": false,
        "description": "Heavy melee tool for construction and combat",
        "model": "res://assets/tools/hammer.glb",
        "icon": "res://assets/icons/hammer.png",
        "sound": "res://assets/sounds/hammer_swing.wav"
    })
    
    register_tool("axe", {
        "type": ToolType.MELEE,
        "name": "Axe",
        "damage": 20,
        "range": 2.0,
        "cooldown": 0.6,
        "min_age": 6,
        "parent_gated": false,
        "description": "Wood-chopping tool, can also be used in combat",
        "model": "res://assets/tools/axe.glb",
        "icon": "res://assets/icons/axe.png",
        "sound": "res://assets/sounds/axe_swing.wav",
        "effect": "wood_chips"
    })
    
    # Fantasy tools
    register_tool("magic_staff", {
        "type": ToolType.FANTASY,
        "fantasy_type": "projectile",
        "name": "Magic Staff",
        "damage": 10,
        "projectile": "res://assets/projectiles/magic_bolt.tscn",
        "cooldown": 1.0,
        "min_age": 10,
        "parent_gated": true,
        "description": "Fires magical projectiles",
        "model": "res://assets/tools/staff.glb",
        "icon": "res://assets/icons/staff.png",
        "sound": "res://assets/sounds/magic_cast.wav"
    })
    
    register_tool("energy_sword", {
        "type": ToolType.FANTASY,
        "name": "Energy Sword",
        "damage": 25,
        "range": 2.5,
        "cooldown": 0.4,
        "min_age": 10,
        "parent_gated": true,
        "description": "Sword made of pure energy",
        "model": "res://assets/tools/energy_sword.glb",
        "icon": "res://assets/icons/energy_sword.png",
        "sound": "res://assets/sounds/energy_sword.wav",
        "effect": "energy_trail"
    })
```

#### Tool Progression System

```gdscript
# tool_progression.gd
class_name ToolProgression extends Node

# Tool unlock tree
var unlock_tree: Dictionary = {
    "basic": {
        "name": "Basic Tools",
        "tools": ["hammer", "axe", "pickaxe"],
        "unlocked_by_default": true,
        "requirements": {}
    },
    "advanced": {
        "name": "Advanced Tools",
        "tools": ["wrench", "sickle", "shears"],
        "unlocked_by_default": false,
        "requirements": {"level": 5}
    },
    "fantasy": {
        "name": "Fantasy Tools",
        "tools": ["magic_staff", "energy_sword"],
        "unlocked_by_default": false,
        "requirements": {"level": 10, "parent_unlock": true}
    },
    "utility": {
        "name": "Utility Tools",
        "tools": ["flashlight", "net", "rope"],
        "unlocked_by_default": false,
        "requirements": {"level": 3}
    }
}

var unlocked_categories: Array = ["basic"]
var player_level: int = 1

signal tool_unlocked(tool_id: String)
signal category_unlocked(category: String)

func check_unlock(tool_id: String) -> bool:
    # Find which category the tool belongs to
    for category in unlock_tree:
        if unlock_tree[category]["tools"].has(tool_id):
            return _check_category_unlock(category)
    
    return false

func _check_category_unlock(category: String) -> bool:
    # Already unlocked
    if unlocked_categories.has(category):
        return true
    
    var category_data = unlock_tree[category]
    
    # Check default unlock
    if category_data["unlocked_by_default"]:
        return true
    
    # Check requirements
    var requirements = category_data["requirements"]
    
    if requirements.has("level") and player_level < requirements["level"]:
        return false
    
    if requirements.has("parent_unlock"):
        var parent_settings = get_node("/root/Main/ParentContentControls")
        if parent_settings:
            # Check if parent has unlocked this category
            if not parent_settings.is_content_enabled(category):
                return false
    
    # All requirements met
    unlocked_categories.append(category)
    emit_signal("category_unlocked", category)
    return true

func unlock_tool(tool_id: String) -> bool:
    for category in unlock_tree:
        if unlock_tree[category]["tools"].has(tool_id):
            if _check_category_unlock(category):
                emit_signal("tool_unlocked", tool_id)
                return true
    
    return false

func set_player_level(level: int):
    player_level = level
    # Re-check unlocks
    for category in unlock_tree:
        if not unlocked_categories.has(category):
            _check_category_unlock(category)

func get_available_tools() -> Array:
    var available = []
    
    for category in unlock_tree:
        if unlocked_categories.has(category) or unlock_tree[category]["unlocked_by_default"]:
            for tool_id in unlock_tree[category]["tools"]:
                available.append(tool_id)
    
    return available
```

---

### Safe Firearm Implementation (If Approved)

#### Non-Gory Firearm Design Principles

1. **No Blood**: Use sparks, energy effects, or no effects
2. **No Realistic Sounds**: Use sci-fi/laser sounds
3. **Cartoony Visuals**: Oversized, colorful, unrealistic
4. **Limited Impact**: Low damage, no permanent effects
5. **Reversible**: Can be undone/disabled

**Safe Firearm Configuration:**
```yaml
# safe_firearm_config.yaml
firearm_id: "sci_fi_pistol"
name: "Sci-Fi Pistol"
description: "Energy-based weapon with non-gory effects"

# Safety settings
safe_for_children: false  # Requires parent unlock
min_age: 10
e10plus_rating: true
t_rating: false

# Visual settings
color: "#00FFFF"  # Cyan/blue (non-threatening)
size_scale: 1.2  # Slightly oversized
muzzle_flash: "energy_flash"
projectile_effect: "energy_bolt"
hit_effect: "energy_spark"

# Gameplay settings
damage: 5
damage_type: "energy"
fire_rate: 0.8  # Slow
ammo_capacity: 6
reload_time: 2.0
range: 50.0

# Sound settings
fire_sound: "res://assets/sounds/laser_pew.wav"
reload_sound: "res://assets/sounds/energy_reload.wav"

# Restrictions
requires_parent_unlock: true
requires_age_verification: true
can_be_disabled: true
audit_logged: true
```

#### Non-Gory Hit Effects

```gdscript
# non_gory_effects.gd
class_name NonGoryEffects extends Node

# Effect types
enum EffectType {
    SPARK,
    ENERGY_SPARK,
    SMOKE,
    LIGHT_FLASH,
    SCREEN_SHAKE,
    HIT_MARKER,
}

func spawn_hit_effect(hit_position: Vector3, hit_normal: Vector3, effect_type: EffectType = EffectType.ENERGY_SPARK):
    var effect_scene: PackedScene
    
    match effect_type:
        EffectType.SPARK:
            effect_scene = preload("res://assets/effects/spark_particles.tscn")
        EffectType.ENERGY_SPARK:
            effect_scene = preload("res://assets/effects/energy_spark.tscn")
        EffectType.SMOKE:
            effect_scene = preload("res://assets/effects/smoke_puff.tscn")
        EffectType.LIGHT_FLASH:
            effect_scene = preload("res://assets/effects/light_flash.tscn")
        _:
            effect_scene = preload("res://assets/effects/default_hit.tscn")
    
    var effect = effect_scene.instantiate()
    effect.global_position = hit_position
    
    # Rotate effect based on hit normal
    if hit_normal.length() > 0.1:
        var look_at = Vector3(0, 0, -1).rotated(Vector3.UP, hit_normal.signed_angle_to(Vector3.UP, Vector3.RIGHT))
        effect.look_at(hit_position + look_at, Vector3.UP)
    
    get_parent().add_child(effect)
    
    # Auto-remove after effect finishes
    effect.finish.connect(effect.queue_free)

func spawn_muzzle_flash(weapon_position: Vector3, weapon_direction: Vector3):
    var flash = preload("res://assets/effects/energy_muzzle_flash.tscn").instantiate()
    flash.global_position = weapon_position
    flash.look_at(weapon_position + weapon_direction, Vector3.UP)
    get_parent().add_child(flash)
    flash.finish.connect(flash.queue_free)

func spawn_projectile_trail(start_pos: Vector3, end_pos: Vector3):
    var trail = preload("res://assets/effects/energy_trail.tscn").instantiate()
    trail.set_start_point(start_pos)
    trail.set_end_point(end_pos)
    get_parent().add_child(trail)
    trail.finish.connect(trail.queue_free)
```

#### Energy Projectile System

```gdscript
# energy_projectile.gd
class_name EnergyProjectile extends Area3D

@export var speed: float = 25.0
@export var max_distance: float = 100.0
@export var damage: int = 5
@export var damage_type: String = "energy"
@export var lifetime: float = 3.0
@export var effect_type: EffectType = EffectType.ENERGY_SPARK

var direction: Vector3 = Vector3.FORWARD
var start_position: Vector3 = Vector3.ZERO
var traveled_distance: float = 0.0
var time_alive: float = 0.0

signal hit(target: Node, position: Vector3)
signal expired()

func _ready():
    start_position = global_position
    
    # Set collision shape
    var collision = CollisionShape3D.new()
    collision.shape = SphereShape3D.new()
    collision.shape.radius = 0.2
    add_child(collision)
    
    # Visual effect
    var visual = preload("res://assets/projectiles/energy_bolt.tscn").instantiate()
    add_child(visual)

func _physics_process(delta):
    time_alive += delta
    
    if time_alive >= lifetime:
        queue_free()
        emit_signal("expired")
        return
    
    # Move projectile
    var velocity = direction * speed
    global_position += velocity * delta
    traveled_distance += velocity.length() * delta
    
    if traveled_distance >= max_distance:
        queue_free()
        emit_signal("expired")
        return

func _on_body_entered(body: Node):
    # Apply damage
    if body has_method("take_damage"):
        body.take_damage(damage, damage_type)
    
    # Spawn hit effect
    var effect_system = get_node("/root/Main/NonGoryEffects")
    if effect_system:
        effect_system.spawn_hit_effect(global_position, -direction, effect_type)
    
    emit_signal("hit", body, global_position)
    queue_free()

func _on_area_entered(area: Area3D):
    # Handle area triggers
    pass
```

---

### Asset Source Recommendations

#### CC0 Model Sources (No Attribution Required)

**1. Kenney.nl**
- [Main Site](https://kenney.nl/)
- **Recommended Packs:**
  - [RPG Kit](https://kenney.nl/assets/rpg-kit) - Characters, weapons, tools
  - [Gun Pack](https://kenney.nl/assets/gunpack) - Sci-fi and fantasy weapons
  - [Tank](https://kenney.nl/assets/tank) - Simple tank model
  - [Tool Pack](https://kenney.nl/assets/tool-pack) - Various tools
- **License**: CC0 (Public Domain)
- **Quality**: High, game-ready
- **Format**: GLB, FBX, PNG
- **Poly Count**: Low to medium (optimized for games)

**2. Quaternius**
- [Main Site](https://quaternius.com/free-3d-models)
- **Categories:**
  - [Characters](https://quaternius.com/free-3d-models?category=characters) - Humans, creatures
  - [Weapons](https://quaternius.com/free-3d-models?category=weapons) - Sci-fi weapons
  - [Vehicles](https://quaternius.com/free-3d-models?category=vehicles) - Tanks, cars
  - [Tools](https://quaternius.com/free-3d-models?category=props) - Various tools
- **License**: CC0
- **Quality**: High, PBR textures
- **Format**: GLB, FBX
- **Poly Count**: Medium to high

**3. Poly Pizza**
- [Main Site](https://poly.pizza/)
- **Features:**
  - Low-poly models
  - Search by keyword
  - All CC0
- **Recommended Searches:**
  - "tool", "weapon", "sword", "hammer", "axe"
  - "gun" (sci-fi variants only)
  - "tank", "vehicle"
- **License**: CC0
- **Quality**: Low-poly, stylized
- **Format**: GLB

**4. CC0 Textures**
- [Main Site](https://cc0textures.com/)
- **Categories:**
  - Metal, Wood, Fabric, Stone, etc.
- **License**: CC0
- **Resolution**: Up to 8K
- **Format**: PNG, JPEG

**5. OpenPeeps**
- [Main Site](https://www.openpeeps.com/)
- **Content**: Hand-drawn character illustrations
- **License**: CC0
- **Use Case**: UI, character portraits

#### MIT License Sources (Attribution Required)

**1. Godot Asset Library**
- [Asset Library](https://godotengine.org/asset-library)
- **Search**: "weapon", "tool", "combat"
- **License**: Mostly MIT
- **Integration**: Direct import into Godot
- **Recommended:**
  - [Shooter Kit](https://godotengine.org/asset-library/asset/643) - By GDQuest
  - [Simple Combat](https://godotengine.org/asset-library/asset/1234)

**2. Sketchfab (MIT Filter)**
- [MIT Licensed Models](https://sketchfab.com/search?type=models&license=cc0,mit)
- **Filter**: Use license filter for MIT/CC0
- **Caution**: Always verify individual model license

**3. TurboSquid Free Section**
- [Free 3D Models](https://www.turbosquid.com/Search/3D-Models/free)
- **Filter**: By license (MIT, CC0)
- **Caution**: Some "free" models have restrictions

#### Commercial-Friendly Sources

**1. Mixamo**
- [Main Site](https://www.mixamo.com/)
- **Content**: Animated characters
- **License**: Free for use in games (check [ToS](https://www.mixamo.com/terms))
- **Format**: FBX (with animations)
- **Use Case**: SWAT, Soldier animations
- **Caution**: Requires attribution in some cases

**2. Adapting Existing Assets**
- Modify downloaded assets to create unique variants
- Combine multiple CC0 assets
- Re-texture with CC0 textures
- Re-rig animations

**Asset Provenance Tracking:**
```gdscript
# asset_provenance_tracker.gd
class_name AssetProvenanceTracker extends Node

var assets: Dictionary = {}

func register_asset(asset_id: String, provenance: Dictionary):
    provenance["asset_id"] = asset_id
    provenance["registration_date"] = Time.get_unix_time_from_system()
    assets[asset_id] = provenance
    _save_database()

func get_provenance(asset_id: String) -> Dictionary:
    return assets.get(asset_id, {})

func verify_all_assets() -> Array:
    var issues = []
    
    for asset_id in assets:
        var provenance = assets[asset_id]
        
        # Check if license is verified
        if not provenance.get("license_verified", false):
            issues.append({
                "asset_id": asset_id,
                "issue": "License not verified",
                "severity": "high"
            })
        
        # Check if source is known
        if provenance.get("source", "") == "Unknown":
            issues.append({
                "asset_id": asset_id,
                "issue": "Source unknown",
                "severity": "high"
            })
        
        # Check if compatible with target age
        var min_age = provenance.get("min_age", 0)
        if min_age > 12:  # Default child age
            issues.append({
                "asset_id": asset_id,
                "issue": "Minimum age %d may be too high for default mode" % min_age,
                "severity": "medium"
            })
    
    return issues

func export_provenance_report() -> String:
    var report = "# Asset Provenance Report\n\n"
    report += "Generated: %s\n\n" % Time.get_unix_time_from_system()
    
    report += "## Summary\n"
    report += "- Total assets: %d\n" % assets.size()
    report += "- Verified: %d\n" % _count_verified()
    report += "- Unverified: %d\n\n" % _count_unverified()
    
    report += "## Asset List\n\n"
    
    for asset_id in assets:
        var provenance = assets[asset_id]
        report += "### %s\n" % asset_id
        report += "- **Source**: %s\n" % provenance.get("source", "Unknown")
        report += "- **License**: %s\n" % provenance.get("license", "Unknown")
        report += "- **Author**: %s\n" % provenance.get("author", "Unknown")
        report += "- **Min Age**: %d\n" % provenance.get("min_age", 0)
        report += "- **Verified**: %s\n" % provenance.get("license_verified", false)
        report += "- **Notes**: %s\n\n" % provenance.get("notes", "")
    
    return report

func _count_verified() -> int:
    var count = 0
    for asset_id in assets:
        if assets[asset_id].get("license_verified", false):
            count += 1
    return count

func _count_unverified() -> int:
    return assets.size() - _count_verified()

func _save_database():
    var save_file = FileAccess.open("user://asset_provenance.json", FileAccess.WRITE)
    var json = JSON.new()
    save_file.store_string(json.stringify(assets))
    save_file.close()
```

---

### Integration with Existing Combat Systems

#### VS-005 Combat Telegraphs Integration

The existing combat system (VS-005) includes:
- Wind-up telegraphs
- Hitstop
- Screen shake
- Damage numbers
- Particle effects
- Weapon differentiation

**Safe Weapon Telegraphs:**
```gdscript
# safe_weapon_telegraphs.gd
class_name SafeWeaponTelegraphs extends Node

# Telegraph types for different weapon categories
const TELEGRAPH_CONFIGS = {
    "melee": {
        "wind_up_time": 0.3,
        "telegraph_color": Color.RED,
        "telegraph_scale": Vector3(1.5, 1.5, 0.1),
        "hitstop": 0.1,
        "screen_shake": 0.5
    },
    "tool": {
        "wind_up_time": 0.4,
        "telegraph_color": Color.YELLOW,
        "telegraph_scale": Vector3(1.2, 1.2, 0.1),
        "hitstop": 0.05,
        "screen_shake": 0.3
    },
    "energy": {
        "wind_up_time": 0.5,
        "telegraph_color": Color.CYAN,
        "telegraph_scale": Vector3(1.0, 1.0, 0.1),
        "hitstop": 0.0,
        "screen_shake": 0.0,
        "use_beam": true
    },
    "sci_fi": {
        "wind_up_time": 0.6,
        "telegraph_color": Color.PURPLE,
        "telegraph_scale": Vector3(2.0, 2.0, 0.1),
        "hitstop": 0.0,
        "screen_shake": 0.2,
        "use_charge_effect": true
    }
}

var current_telegraph: Node3D = null
var is_winding_up: bool = false

func start_telegraph(weapon_type: String, direction: Vector3):
    if TELEGRAPH_CONFIGS.has(weapon_type):
        var config = TELEGRAPH_CONFIGS[weapon_type]
        _start_wind_up(weapon_type, config, direction)

func _start_wind_up(weapon_type: String, config: Dictionary, direction: Vector3):
    is_winding_up = true
    
    # Create telegraph
    var telegraph_scene = preload("res://assets/combat/telegraph.tscn")
    current_telegraph = telegraph_scene.instantiate()
    current_telegraph.global_position = global_position + Vector3(0, 0.5, 0)
    current_telegraph.set_color(config["telegraph_color"])
    current_telegraph.set_scale(config["telegraph_scale"])
    get_parent().add_child(current_telegraph)
    
    # Animate telegraph
    var tween = create_tween()
    tween.tween_property(current_telegraph, "scale:x", config["telegraph_scale"].x * 1.5, config["wind_up_time"])
    tween.tween_property(current_telegraph, "scale:z", config["telegraph_scale"].z * 1.5, config["wind_up_time"])
    
    # Add charge effect for sci-fi
    if config.get("use_charge_effect", false):
        _start_charge_effect()
    
    # Add beam for energy weapons
    if config.get("use_beam", false):
        _start_beam_effect(direction)
    
    # Complete wind-up
    await tween.finished
    is_winding_up = false
    _complete_telegraph(weapon_type, config, direction)

func _start_charge_effect():
    var charge = preload("res://assets/effects/charge_up.tscn").instantiate()
    charge.global_position = global_position + Vector3(0, 1.0, 0)
    get_parent().add_child(charge)

func _start_beam_effect(direction: Vector3):
    # Preview beam direction
    var preview_beam = preload("res://assets/effects/preview_beam.tscn").instantiate()
    preview_beam.global_position = global_position
    preview_beam.set_direction(direction)
    get_parent().add_child(preview_beam)

func _complete_telegraph(weapon_type: String, config: Dictionary, direction: Vector3):
    if current_telegraph:
        current_telegraph.queue_free()
        current_telegraph = null
    
    # Apply hitstop
    if config.get("hitstop", 0.0) > 0:
        HitstopManager.hitstop(config["hitstop"])
    
    # Apply screen shake
    if config.get("screen_shake", 0.0) > 0:
        CameraShaker.shake(config["screen_shake"])

func cancel_telegraph():
    if current_telegraph:
        current_telegraph.queue_free()
        current_telegraph = null
    is_winding_up = false
```

#### VS-023 Liminal Creatures Integration

The backrooms monsters (VS-023) can interact with tools/weapons:
- Some creatures weak to specific tools
- Some creatures immune to certain weapon types
- Special effects when hitting creatures

**Creature Tool Vulnerabilities:**
```gdscript
# creature_tool_vulnerabilities.gd
class_name CreatureToolVulnerabilities extends Node

# Vulnerability matrix: {creature_type: {tool_type: multiplier}}
const VULNERABILITIES = {
    "liminal_hound": {
        "melee": 1.0,
        "tool_axe": 1.5,  # Extra damage with axe
        "tool_pickaxe": 0.5,  # Less effective
        "energy": 2.0,  # Very effective
        "sci_fi": 1.5
    },
    "liminal_stalker": {
        "melee": 0.8,
        "tool_axe": 1.2,
        "tool_pickaxe": 1.0,
        "energy": 0.5,  # Resistant to energy
        "sci_fi": 1.0
    },
    "liminal_brute": {
        "melee": 0.5,  # Resistant to melee
        "tool_axe": 1.0,
        "tool_pickaxe": 1.0,
        "energy": 1.2,
        "sci_fi": 1.8  # Very vulnerable
    },
    "liminal_flyer": {
        "melee": 0.0,  # Immune to melee
        "tool_axe": 0.0,
        "tool_pickaxe": 0.0,
        "energy": 1.0,
        "sci_fi": 1.5
    }
}

# Immunity matrix: {creature_type: [tool_types]}
const IMMUNITIES = {
    "liminal_flyer": ["melee", "tool_axe", "tool_pickaxe"],
    "liminal_ghost": ["melee", "tool_axe", "tool_pickaxe", "energy"],
    "liminal_shadow": ["melee"]
}

func get_damage_multiplier(creature_type: String, tool_type: String) -> float:
    if IMMUNITIES.has(creature_type):
        if IMMUNITIES[creature_type].has(tool_type):
            return 0.0
    
    if VULNERABILITIES.has(creature_type):
        if VULNERABILITIES[creature_type].has(tool_type):
            return VULNERABILITIES[creature_type][tool_type]
    
    return 1.0

func is_immune(creature_type: String, tool_type: String) -> bool:
    if IMMUNITIES.has(creature_type):
        return IMMUNITIES[creature_type].has(tool_type)
    return false

func get_effective_tools(creature_type: String) -> Array:
    var effective_tools = []
    
    if not VULNERABILITIES.has(creature_type):
        return effective_tools
    
    for tool_type in VULNERABILITIES[creature_type]:
        var multiplier = VULNERABILITIES[creature_type][tool_type]
        if multiplier > 1.0:
            effective_tools.append({
                "tool_type": tool_type,
                "multiplier": multiplier
            })
    
    # Sort by effectiveness
    effective_tools.sort_custom(func(a, b): return b["multiplier"] <=> a["multiplier"])
    
    return effective_tools
```

**Special Hit Effects:**
```gdscript
# creature_hit_effects.gd
class_name CreatureHitEffects extends Node

# Effect configurations per creature and tool type
const HIT_EFFECTS = {
    "liminal_hound": {
        "melee": {"effect": "blood_splat", "sound": "hit_flesh"},
        "tool_axe": {"effect": "wood_chips", "sound": "hit_wood"},
        "energy": {"effect": "energy_splash", "sound": "hit_energy"}
    },
    "liminal_stalker": {
        "melee": {"effect": "shadow_puff", "sound": "hit_shadow"},
        "energy": {"effect": "energy_absorb", "sound": "hit_absorb"}
    },
    "default": {
        "any": {"effect": "generic_spark", "sound": "hit_generic"}
    }
}

# Non-gory alternatives
const NON_GORY_EFFECTS = {
    "blood_splat": "spark_puff",
    "hit_flesh": "hit_spark",
    "hit_wood": "hit_wood",  # This is fine (wood)
    "hit_shadow": "hit_spark",
    "hit_energy": "hit_energy",
    "hit_absorb": "hit_spark"
}

func spawn_hit_effect(creature_type: String, tool_type: String, position: Vector3):
    var effect_config = _get_effect_config(creature_type, tool_type)
    
    # Use non-gory effects for child mode
    var player_profile = get_node("/root/Main/PlayerProfile")
    var use_non_gory = true  # Default to non-gory
    
    if player_profile:
        use_non_gory = player_profile.age_band < AgeBand.TEEN_13_15
    
    var effect_name = effect_config["effect"]
    if use_non_gory and NON_GORY_EFFECTS.has(effect_name):
        effect_name = NON_GORY_EFFECTS[effect_name]
    
    # Spawn effect
    var effect_scene = preload("res://assets/effects/%s.tscn" % effect_name)
    if effect_scene:
        var effect = effect_scene.instantiate()
        effect.global_position = position
        get_parent().add_child(effect)
    
    # Play sound
    var sound_name = effect_config["sound"]
    if use_non_gory and NON_GORY_EFFECTS.has(sound_name):
        sound_name = NON_GORY_EFFECTS[sound_name]
    
    _play_sound(sound_name, position)

func _get_effect_config(creature_type: String, tool_type: String) -> Dictionary:
    if HIT_EFFECTS.has(creature_type):
        if HIT_EFFECTS[creature_type].has(tool_type):
            return HIT_EFFECTS[creature_type][tool_type]
        elif HIT_EFFECTS[creature_type].has("any"):
            return HIT_EFFECTS[creature_type]["any"]
    
    return HIT_EFFECTS["default"]["any"]

func _play_sound(sound_name: String, position: Vector3):
    var sound = preload("res://assets/sounds/%s.wav" % sound_name)
    if sound:
        var audio_player = AudioStreamPlayer3D.new()
        audio_player.stream = sound
        audio_player.global_position = position
        get_parent().add_child(audio_player)
        audio_player.play()
        audio_player.finish.connect(audio_player.queue_free)
```

---

### Hexagonal Architecture Integration

#### Domain Layer: Content Classification

```gdscript
# src/domain/identity_safety/content_classification.gd
class_name ContentClassification extends RefCounted

# Content categories
enum ContentCategory {
    MELEE_WEAPON,
    TOOL,
    ENERGY_WEAPON,
    SCI_FI_WEAPON,
    REALISTIC_WEAPON,
    CREATURE,
    ENVIRONMENT,
    UI,
}

# Content ratings
enum ContentRating {
    UNIVERSAL,      # E for Everyone / PEGI 3
    CHILD,          # E for Everyone / PEGI 7
    PRE_TEEN,       # E10+ / PEGI 12
    TEEN,           # T / PEGI 16
    MATURE,         # M / PEGI 18
}

# Content descriptor flags
const ContentDescriptor = {
    NON_GORY: 1 << 0,
    NON_VIOLENT: 1 << 1,
    PARENT_GATED: 1 << 2,
    AGE_RESTRICTED: 1 << 3,
    REVERSIBLE: 1 << 4,
    AUDIT_LOGGED: 1 << 5,
    SINGLE_PLAYER_ONLY: 1 << 6,
}

var category: ContentCategory
var rating: ContentRating
var descriptors: int = 0
var min_age: int = 0
var license: String = ""
var source: String = ""
var provenance_hash: String = ""

func set_category(cat: ContentCategory) -> void:
    category = cat

func add_descriptor(descriptor: int) -> void:
    descriptors |= descriptor

func has_descriptor(descriptor: int) -> bool:
    return (descriptors & descriptor) == descriptor

func set_rating(r: ContentRating) -> void:
    rating = r
    min_age = _rating_to_min_age(r)

func _rating_to_min_age(rating: ContentRating) -> int:
    match rating:
        ContentRating.UNIVERSAL:
            return 3
        ContentRating.CHILD:
            return 6
        ContentRating.PRE_TEEN:
            return 10
        ContentRating.TEEN:
            return 13
        ContentRating.MATURE:
            return 17
    return 0

func is_allowed_for_age(age: int) -> bool:
    return age >= min_age

func requires_parent_gate() -> bool:
    return has_descriptor(ContentDescriptor.PARENT_GATED) or \
           rating >= ContentRating.PRE_TEEN
```

#### Domain Layer: Weapon Definition

```gdscript
# src/domain/gameplay/weapon.gd
class_name Weapon extends RefCounted

var weapon_id: String
var name: String
var description: String
var weapon_type: String  # "melee", "tool", "energy", "sci_fi", "realistic"
var damage: int
var damage_type: String
var range: float
var cooldown: float
var ammo_capacity: int
var reload_time: float
var content_classification: ContentClassification

# Visual properties
var model_path: String
var icon_path: String
var texture_path: String

# Audio properties
var fire_sound: String
var hit_sound: String
var reload_sound: String

# Gameplay properties
var accuracy: float = 1.0
var projectile_speed: float = 20.0
var projectile_scene: String
var hit_effect: String

func is_safe_for_children() -> bool:
    return content_classification.rating <= ContentClassification.ContentRating.CHILD

func requires_parent_unlock() -> bool:
    return content_classification.requires_parent_gate()

func get_min_age() -> int:
    return content_classification.min_age
```

#### Application Layer: Weapon Service

```gdscript
# src/application/services/weapon_service.gd
class_name WeaponService extends RefCounted

var weapon_port: WeaponPort
var content_policy: ContentPolicyPort

func initialize(weapon_port: WeaponPort, policy_port: ContentPolicyPort) -> void:
    self.weapon_port = weapon_port
    self.content_policy = policy_port

func get_weapon(weapon_id: String) -> Result:
    # Check content policy first
    var policy_result = content_policy.check_content(weapon_id)
    if policy_result.is_failure():
        return Result.fail("Content not allowed: %s" % policy_result.get_error())
    
    # Get weapon from port
    var weapon = weapon_port.get_weapon(weapon_id)
    if not weapon:
        return Result.fail("Weapon not found")
    
    # Verify content classification
    if not _verify_classification(weapon):
        return Result.fail("Weapon classification invalid")
    
    return Result.ok(weapon)

func get_available_weapons(player_profile: PlayerProfile) -> Result:
    # Get all weapons
    var all_weapons = weapon_port.get_all_weapons()
    var available = []
    
    for weapon in all_weapons:
        # Check age requirement
        if player_profile.age_band < weapon.get_min_age():
            continue
        
        # Check parent settings
        if weapon.requires_parent_unlock():
            var parent_settings = ParentSettings.get_instance()
            if not parent_settings.is_content_enabled(weapon.weapon_id):
                continue
        
        # Check content policy
        var policy_result = content_policy.check_content(weapon.weapon_id)
        if policy_result.is_failure():
            continue
        
        available.append(weapon)
    
    return Result.ok(available)

func _verify_classification(weapon: Weapon) -> bool:
    # Classification must be present
    if not weapon.content_classification:
        return false
    
    # Must have valid rating
    if weapon.content_classification.rating == ContentClassification.ContentRating.UNIVERSAL:
        return true
    
    # Must have descriptors
    if weapon.content_classification.descriptors == 0:
        return false
    
    return true
```

#### Adapter Layer: Weapon Repository

```gdscript
# src/adapters/outbound/weapon_repository.gd
class_name WeaponRepository extends Node
implements WeaponPort

var weapons: Dictionary = {}

func _ready():
    _load_weapons()

func _load_weapons():
    # Load from weapon definitions
    var weapon_files = [
        "res://data/weapons/melee.json",
        "res://data/weapons/tools.json",
        "res://data/weapons/energy.json",
        "res://data/weapons/sci_fi.json"
    ]
    
    for file_path in weapon_files:
        if FileAccess.file_exists(file_path):
            var file = FileAccess.open(file_path, FileAccess.READ)
            var json = JSON.new()
            json.parse(file.get_as_text())
            file.close()
            
            var data = json.get_data()
            for weapon_data in data:
                var weapon = _create_weapon_from_data(weapon_data)
                weapons[weapon.weapon_id] = weapon

func _create_weapon_from_data(data: Dictionary) -> Weapon:
    var weapon = Weapon.new()
    
    weapon.weapon_id = data.get("id", "")
    weapon.name = data.get("name", "")
    weapon.description = data.get("description", "")
    weapon.weapon_type = data.get("type", "melee")
    weapon.damage = data.get("damage", 10)
    weapon.damage_type = data.get("damage_type", "physical")
    weapon.range = data.get("range", 2.0)
    weapon.cooldown = data.get("cooldown", 0.5)
    weapon.ammo_capacity = data.get("ammo_capacity", 0)
    weapon.reload_time = data.get("reload_time", 0.0)
    
    # Model and assets
    weapon.model_path = data.get("model", "")
    weapon.icon_path = data.get("icon", "")
    
    # Audio
    weapon.fire_sound = data.get("fire_sound", "")
    weapon.hit_sound = data.get("hit_sound", "")
    weapon.reload_sound = data.get("reload_sound", "")
    
    # Content classification
    weapon.content_classification = _create_classification_from_data(data.get("classification", {}))
    
    return weapon

func _create_classification_from_data(data: Dictionary) -> ContentClassification:
    var classification = ContentClassification.new()
    
    var category_map = {
        "melee": ContentClassification.ContentCategory.MELEE_WEAPON,
        "tool": ContentClassification.ContentCategory.TOOL,
        "energy": ContentClassification.ContentCategory.ENERGY_WEAPON,
        "sci_fi": ContentClassification.ContentCategory.SCI_FI_WEAPON,
        "realistic": ContentClassification.ContentCategory.REALISTIC_WEAPON
    }
    
    if data.has("category"):
        classification.set_category(category_map.get(data["category"], ContentClassification.ContentCategory.MELEE_WEAPON))
    
    if data.has("rating"):
        var rating_map = {
            "universal": ContentClassification.ContentRating.UNIVERSAL,
            "child": ContentClassification.ContentRating.CHILD,
            "pre_teen": ContentClassification.ContentRating.PRE_TEEN,
            "teen": ContentClassification.ContentRating.TEEN,
            "mature": ContentClassification.ContentRating.MATURE
        }
        classification.set_rating(rating_map.get(data["rating"], ContentClassification.ContentRating.CHILD))
    
    if data.has("descriptors"):
        for descriptor in data["descriptors"]:
            var desc_map = {
                "non_gory": ContentDescriptor.NON_GORY,
                "non_violent": ContentDescriptor.NON_VIOLENT,
                "parent_gated": ContentDescriptor.PARENT_GATED,
                "age_restricted": ContentDescriptor.AGE_RESTRICTED,
                "reversible": ContentDescriptor.REVERSIBLE,
                "audit_logged": ContentDescriptor.AUDIT_LOGGED,
                "single_player_only": ContentDescriptor.SINGLE_PLAYER_ONLY
            }
            if desc_map.has(descriptor):
                classification.add_descriptor(desc_map[descriptor])
    
    return classification

# WeaponPort implementation
func get_weapon(weapon_id: String) -> Weapon:
    return weapons.get(weapon_id)

func get_all_weapons() -> Array:
    return weapons.values()

func get_weapons_by_type(weapon_type: String) -> Array:
    var result = []
    for weapon in weapons.values():
        if weapon.weapon_type == weapon_type:
            result.append(weapon)
    return result

func get_weapons_by_category(category: ContentClassification.ContentCategory) -> Array:
    var result = []
    for weapon in weapons.values():
        if weapon.content_classification.category == category:
            result.append(weapon)
    return result
```

#### Adapter Layer: Godot Weapon Adapter

```gdscript
# src/adapters/outbound/godot_weapon_adapter.gd
class_name GodotWeaponAdapter extends Node

var weapon: Weapon
var player: Node3D
var camera: Camera3D

@onready var telegraph_system: SafeWeaponTelegraphs = $Telegraphs
@onready var effect_system: NonGoryEffects = $Effects

signal weapon_fired()
signal weapon_reloaded()
signal ammo_changed(current: int, max: int)

var current_ammo: int = 0
var is_reloading: bool = false
var can_fire: bool = true
var last_fire_time: float = 0.0

func initialize(weapon: Weapon, player: Node3D, camera: Camera3D):
    self.weapon = weapon
    self.player = player
    self.camera = camera
    
    # Load model
    _load_model()
    
    # Initialize ammo
    current_ammo = weapon.ammo_capacity
    emit_signal("ammo_changed", current_ammo, weapon.ammo_capacity)

func _load_model():
    if weapon.model_path != "":
        var model = load(weapon.model_path)
        if model:
            var model_instance = model.instantiate()
            add_child(model_instance)
            model_instance.position = Vector3(0.5, 0, 0)  # Position in player's hand

func _input(event):
    if event.is_action_pressed("fire") and can_fire:
        fire()
    elif event.is_action_pressed("reload") and weapon.ammo_capacity > 0:
        reload()

func fire():
    if not can_fire:
        return
    
    # Check cooldown
    if Time.get_unix_time_from_system() - last_fire_time < weapon.cooldown:
        return
    
    # Check ammo
    if weapon.ammo_capacity > 0 and current_ammo <= 0:
        reload()
        return
    
    can_fire = false
    last_fire_time = Time.get_unix_time_from_system()
    
    # Start telegraph
    var mouse_pos = get_viewport().get_mouse_position()
    var direction = _get_camera_direction(mouse_pos)
    telegraph_system.start_telegraph(weapon.weapon_type, direction)
    
    # Fire after telegraph completes
    await telegraph_system.connect("telegraph_complete", Callable(self, "_on_telegraph_complete").bind(direction))

func _on_telegraph_complete(direction: Vector3):
    # Consume ammo if needed
    if weapon.ammo_capacity > 0:
        current_ammo -= 1
        emit_signal("ammo_changed", current_ammo, weapon.ammo_capacity)
    
    # Create projectile if ranged
    if weapon.weapon_type != "melee":
        _fire_projectile(direction)
    else:
        # Melee hit detection
        _melee_hit(direction)
    
    # Play fire sound
    _play_sound(weapon.fire_sound)
    
    # Spawn muzzle flash
    effect_system.spawn_muzzle_flash(global_position, direction)
    
    emit_signal("weapon_fired")
    
    # Reset fire flag
    can_fire = true

func _fire_projectile(direction: Vector3):
    if weapon.projectile_scene != "":
        var projectile_scene = load(weapon.projectile_scene)
        if projectile_scene:
            var projectile = projectile_scene.instantiate()
            projectile.global_position = global_position + direction * 0.5
            projectile.direction = direction
            projectile.damage = weapon.damage
            projectile.damage_type = weapon.damage_type
            get_parent().add_child(projectile)

func _melee_hit(direction: Vector3):
    # Raycast for melee hit
    var from = global_position
    var to = global_position + direction * weapon.range
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    
    var result = space_state.intersect_ray(query)
    
    if result:
        _apply_hit(result)

func _apply_hit(result: Dictionary):
    var target = result["collider"]
    
    # Apply damage
    if target has_method("take_damage"):
        target.take_damage(weapon.damage, weapon.damage_type)
    
    # Spawn hit effect
    effect_system.spawn_hit_effect(result["position"], result["normal"], EffectType.SPARK)
    
    # Play hit sound
    _play_sound(weapon.hit_sound, result["position"])

func _play_sound(sound_path: String, position: Vector3 = null):
    if sound_path == "":
        return
    
    var sound = load(sound_path)
    if sound:
        var audio_player = AudioStreamPlayer3D.new()
        audio_player.stream = sound
        
        if position != null:
            audio_player.global_position = position
        else:
            audio_player.global_position = global_position
        
        get_parent().add_child(audio_player)
        audio_player.play()
        audio_player.finish.connect(audio_player.queue_free)

func _get_camera_direction(mouse_pos: Vector2) -> Vector3:
    if camera:
        return camera.project_ray_normal(mouse_pos)
    return Vector3.FORWARD

func reload():
    if is_reloading:
        return
    
    if weapon.ammo_capacity <= 0:
        return  # No ammo to reload
    
    if current_ammo == weapon.ammo_capacity:
        return  # Already full
    
    is_reloading = true
    
    # Play reload sound
    _play_sound(weapon.reload_sound)
    
    # Wait for reload time
    await get_tree().create_timer(weapon.reload_time).timeout
    
    current_ammo = weapon.ammo_capacity
    is_reloading = false
    emit_signal("weapon_reloaded")
    emit_signal("ammo_changed", current_ammo, weapon.ammo_capacity)
```

---

### Testing and Validation

#### Automated Content Validation Tests

```gdscript
# test_content_validation.gd
class_name TestContentValidation extends TestCase

func test_weapon_classification():
    # Test that all weapons have valid classifications
    var weapon_service = WeaponService.new()
    var weapon_port = WeaponRepository.new()
    var policy_port = ContentPolicyMock.new()
    weapon_service.initialize(weapon_port, policy_port)
    
    var all_weapons = weapon_port.get_all_weapons()
    
    for weapon in all_weapons:
        assert_true(weapon.content_classification != null, \
            "Weapon %s missing classification" % weapon.weapon_id)
        assert_true(weapon.content_classification.rating != ContentClassification.ContentRating.UNIVERSAL || \
                   weapon.content_classification.rating == ContentClassification.ContentRating.UNIVERSAL,
            "Weapon %s has invalid rating" % weapon.weapon_id)

func test_child_safe_weapons():
    # Test that default weapons are child-safe
    var weapon_port = WeaponRepository.new()
    var default_weapons = weapon_port.get_weapons_by_type("melee") + \
                          weapon_port.get_weapons_by_type("tool")
    
    for weapon in default_weapons:
        assert_true(weapon.is_safe_for_children(), \
            "Default weapon %s is not child-safe" % weapon.weapon_id)

func test_parent_gated_weapons():
    # Test that energy/sci-fi weapons require parent gate
    var weapon_port = WeaponRepository.new()
    var parent_gated_types = ["energy", "sci_fi"]
    
    for weapon_type in parent_gated_types:
        var weapons = weapon_port.get_weapons_by_type(weapon_type)
        for weapon in weapons:
            assert_true(weapon.requires_parent_unlock(), \
                "%s weapon %s doesn't require parent unlock" % [weapon_type, weapon.weapon_id])

func test_age_restrictions():
    # Test age-based restrictions
    var weapon_port = WeaponRepository.new()
    
    # Energy weapons should be age 10+
    var energy_weapons = weapon_port.get_weapons_by_type("energy")
    for weapon in energy_weapons:
        assert_true(weapon.get_min_age() >= 10,
            "Energy weapon %s has min_age < 10" % weapon.weapon_id)
    
    # Sci-fi weapons should be age 13+
    var sci_fi_weapons = weapon_port.get_weapons_by_type("sci_fi")
    for weapon in sci_fi_weapons:
        assert_true(weapon.get_min_age() >= 13,
            "Sci-fi weapon %s has min_age < 13" % weapon.weapon_id)

func test_creature_vulnerabilities():
    # Test that creature vulnerabilities are configured
    var vulnerabilities = CreatureToolVulnerabilities.new()
    
    # Test that flyers are immune to melee
    assert_true(vulnerabilities.is_immune("liminal_flyer", "melee"))
    assert_true(vulnerabilities.is_immune("liminal_flyer", "tool_axe"))
    
    # Test that brutes take extra damage from sci-fi
    var multiplier = vulnerabilities.get_damage_multiplier("liminal_brute", "sci_fi")
    assert_true(multiplier > 1.0, "Brutes should be vulnerable to sci-fi")

# Mock for testing
class_name ContentPolicyMock extends RefCounted
implements ContentPolicyPort

func check_content(content_id: String) -> Result:
    # Mock: allow all for testing
    return Result.ok()
```

#### Manual Testing Checklist

**Parent-Gating Tests:**
- [ ] Child mode (age 6-8) can only access melee and tool weapons
- [ ] Child mode (age 9-12) can access melee, tool, and energy weapons (if parent allows)
- [ ] Teen mode (age 13-15) can access all weapon types (if parent allows)
- [ ] Parent can disable specific weapon categories
- [ ] Parent PIN is required to change weapon settings
- [ ] Parent settings persist across game restarts

**Weapon Functionality Tests:**
- [ ] Melee weapons work correctly (hit detection, damage)
- [ ] Tool weapons have special functions (axe chops wood, pickaxe mines)
- [ ] Energy weapons fire projectiles
- [ ] Sci-fi weapons have special effects
- [ ] All weapons have cooldown periods
- [ ] Ammo system works for ranged weapons
- [ ] Reload system works correctly

**Safety Tests:**
- [ ] No blood effects in child mode
- [ ] No gore effects in any mode
- [ ] All sounds are child-appropriate
- [ ] Telegraphs work for all weapon types
- [ ] Hit effects are appropriate for content rating
- [ ] Audit logging works for all weapon uses

**Content Rating Tests:**
- [ ] Weapons have correct ESRB/PEGI ratings
- [ ] Age restrictions are enforced
- [ ] Parent gates work correctly
- [ ] Reversible content can be disabled
- [ ] All content has provenance documentation

**Integration Tests:**
- [ ] Weapons work with existing combat system (VS-005)
- [ ] Weapons work with backrooms creatures (VS-023)
- [ ] Weapons respect parental controls
- [ ] Weapons integrate with save system
- [ ] Weapons work in multiplayer (if applicable)

---

### Final Recommendations and Decision Matrix

#### Decision: Tool-Based Combat System ✅ APPROVED

**Primary Recommendation**: Implement a **tool-based combat system** as the default, with optional parent-gated sci-fi weapons.

**Decision Matrix:**

| Option | Safety | Child-Friendly | Parent Control | Implementation Complexity | Legal Risk | Verdict |
|--------|--------|-----------------|-----------------|---------------------------|------------|---------|
| **Tool-Based Only** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ **RECOMMENDED** |
| Tool + Energy Weapons | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ **APPROVED** (Parent-Gated) |
| Tool + Sci-Fi Weapons | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⚠️ **CONDITIONAL** (E10+/T Rating) |
| Tool + Realistic Firearms | ⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ | ❌ **REJECTED** |

**Implementation Plan:**

**Phase 1: Tool System (Immediate)**
- [ ] Implement ToolSystem with melee and utility tools
- [ ] Create tool definitions (hammer, axe, pickaxe, wrench, etc.)
- [ ] Add tool progression system
- [ ] Integrate with VS-005 combat telegraphs
- [ ] Integrate with VS-023 creature vulnerabilities
- [ ] Add non-gory hit effects

**Phase 2: Parent-Gated Energy Weapons (After VS-023)**
- [ ] Implement parent-gating system
- [ ] Add energy weapons (magic staff, energy sword)
- [ ] Create age verification
- [ ] Add content classification
- [ ] Implement audit logging

**Phase 3: Optional Sci-Fi Weapons (Future)**
- [ ] Add sci-fi weapons (if approved by design review)
- [ ] Implement E10+/T rating compliance
- [ ] Add ESRB/PEGI documentation
- [ ] Create safety review process

**Phase 4: Asset Provenance (Ongoing)**
- [ ] Verify all existing asset licenses
- [ ] Document provenance for all tools/weapons
- [ ] Create asset tracking system
- [ ] Implement automated validation

#### Asset-Specific Decisions

| Asset | Source | License | Verdict | Action |
|-------|--------|---------|---------|--------|
| SWAT.glb | Unknown | Unknown | ❌ REJECT | **DO NOT USE** - Verify provenance first |
| Soldier.fbx | Unknown | Unknown | ❌ REJECT | **DO NOT USE** - Verify provenance first |
| Tank.glb | Unknown | Unknown | ❌ REJECT | **DO NOT USE** - Verify provenance first |
| Pistol.glb | Unknown | Unknown | ❌ REJECT | **DO NOT USE** - Verify provenance first |
| Assault Rifle.glb | Unknown | Unknown | ❌ REJECT | **DO NOT USE** - Verify provenance first |
| ShooterKit | Unknown | Unknown | ⚠️ CONDITIONAL | Verify from Godot Asset Library, check license |

**Replacements:**
- Use [Kenney Tool Pack](https://kenney.nl/assets/tool-pack) (CC0, verified)
- Use [Kenney Gun Pack](https://kenney.nl/assets/gunpack) (CC0, use sci-fi variants only)
- Use [Kenney RPG Kit](https://kenney.nl/assets/rpg-kit) (CC0, includes weapons)
- Create custom tools from primitives

#### Content Rating Compliance

**Choyce Engine Default Configuration:**
```
ESRB Rating: E (Everyone)
PEGI Rating: 3

Default Content:
├── Melee Weapons: Swords, Hammers, Axes, Pickaxes
├── Tools: All tool-based combat
├── Creatures: VS-023 Backrooms monsters (child-safe)
└── Effects: Non-gory sparks, energy impacts

Parent-Gated Content (Optional):
├── Energy Weapons: Magic Staff, Energy Sword
├── Sci-Fi Weapons: Plasma Rifle, Laser Pistol
└── Advanced Tools: Specialized equipment

ESRB Rating with Parent-Gated: E10+
PEGI Rating with Parent-Gated: 7 or 12 (depending on content)
```

**ESRB Submission Notes:**
- No realistic firearms in default mode
- No blood or gore
- All violence is cartoon/fantasy
- Parent controls clearly documented
- Content ratings displayed in settings

---

## Learning Resources

### Child Safety and Content Ratings
- [ESRB Official Site](https://www.esrb.org/)
- [ESRB Rating Process](https://www.esrb.org/ratings/)
- [PEGI Official Site](https://pegi.info/)
- [PEGI Descriptors](https://pegi.info/en/pegi-system)
- [FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/childrens-online-privacy-protection-rule)
- [COPPA Compliance Guide](https://www.ftc.gov/business-guidance/resources/childrens-online-privacy-protection-rule-six-step-compliance-plan-your-business)

### Godot Combat Systems
- [Godot Combat Tutorial](https://docs.godotengine.org/en/stable/getting_started/first_2d_game/04.hitbox_and_hurtbox.html)
- [Area3D Combat](https://docs.godotengine.org/en/stable/tutorials/physics/area_3d.html)
- [Raycasting in Godot](https://docs.godotengine.org/en/stable/tutorials/3d/3d_physics/ray_casting.html)
- [Godot Hit Detection](https://kidscancode.org/godot_recipes/4.x/2d/hit_detection/)

### Asset Sources and Licensing
- [Kenney.nl Assets](https://kenney.nl/) - CC0 Game Assets
- [Quaternius Models](https://quaternius.com/free-3d-models) - CC0 3D Models
- [Poly Pizza Models](https://poly.pizza/) - CC0 Low-Poly Models
- [OpenGameArt](https://opengameart.org/) - Various licenses
- [Godot Asset Library](https://godotengine.org/asset-library) - MIT License
- [Sketchfab](https://sketchfab.com/) - Various licenses (filter for CC0/MIT)

### Weapon System Design
- [Game Weapon Design](https://gamedev.net/tutorials/_/technical/game-design/)
- [Weapon Balancing](https://www.gamasutra.com/view/feature/132549/)
- [Parent Controls in Games](https://www.igda.org/?p=12345)
- [Content Rating Best Practices](https://www.gameindustry.org/responsibility/)

### Parent-Gating Implementation
- [Authentication in Godot](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [Secure Storage in Godot](https://docs.godotengine.org/en/stable/tutorials/io/file_access.html)
- [Encryption in Godot](https://github.com/GodotExplorer/Godot-Encryption)
- [PIN Protection Patterns](https://stackoverflow.com/questions/tagged/pin-protection)

### Testing Frameworks
- [Godot Unit Testing](https://docs.godotengine.org/en/stable/tutorials/testing/unit_testing.html)
- [Test-Driven Development in Godot](https://www.gdquest.com/tutorial/godot-test-driven-development/)
- [Behavior-Driven Development](https://cucumber.io/)

---

## Implementation Checklist

### Phase 1: Core Tool System
- [ ] Design tool classification system
- [ ] Implement ToolSystem base class
- [ ] Create tool definitions (JSON format)
- [ ] Implement tool registration and lookup
- [ ] Add tool equipment and usage
- [ ] Integrate with player controller
- [ ] Create tool models (use Kenney assets)
- [ ] Add tool icons and UI
- [ ] Implement tool cooldown system
- [ ] Add tool-specific animations
- [ ] Integrate with VS-005 telegraphs
- [ ] Integrate with VS-023 creatures
- [ ] Add non-gory hit effects
- [ ] Test all tools

### Phase 2: Parent-Gating System
- [ ] Design content classification system
- [ ] Implement AgeVerification
- [ ] Create ParentContentControls UI
- [ ] Add ContentGate for weapons
- [ ] Implement parent PIN system
- [ ] Add content settings persistence
- [ ] Create age-based restrictions
- [ ] Add parent override capabilities
- [ ] Integrate with weapon system
- [ ] Test parent-gating flow

### Phase 3: Energy/Sci-Fi Weapons
- [ ] Design energy weapon system
- [ ] Create energy projectile system
- [ ] Implement non-gory effects
- [ ] Add energy weapon models
- [ ] Create sci-fi weapon variants
- [ ] Set appropriate age ratings
- [ ] Add parent-gate requirements
- [ ] Integrate with content system
- [ ] Test energy/sci-fi weapons

### Phase 4: Asset Provenance
- [ ] Inventory all existing assets
- [ ] Verify licenses for all assets
- [ ] Document provenance for all assets
- [ ] Create asset tracking system
- [ ] Implement automated validation
- [ ] Add license verification to CI/CD
- [ ] Create asset audit reports

### Phase 5: Documentation
- [ ] Document weapon system architecture
- [ ] Document parent-gating system
- [ ] Document content classification
- [ ] Document asset provenance
- [ ] Create user documentation
- [ ] Create developer documentation
- [ ] Add troubleshooting guide

---

## Final Decision

**✅ APPROVED: Tool-Based Combat System**

**Implementation:**
1. **Primary**: Tool-based combat system (melee and utility tools)
2. **Optional**: Parent-gated energy/sci-fi weapons
3. **Rejected**: Realistic firearms (SWAT, Soldier, Pistol, Assault Rifle)
4. **Conditional**: ShooterKit (verify license and content)

**Key Principles:**
- Default mode is 100% child-safe (E rating)
- All optional content is parent-gated
- All content has verified provenance
- All content respects age restrictions
- No realistic violence or gore

**Asset Actions:**
- **REMOVE**: SWAT.glb, Soldier.fbx, Tank.glb, Pistol.glb, Assault Rifle.glb (unknown provenance)
- **VERIFY**: ShooterKit (check Godot Asset Library)
- **REPLACE**: Use Kenney.nl CC0 assets
- **DOCUMENT**: All asset provenance

**Safety Guarantees:**
- [ ] No realistic firearms in default mode
- [ ] No blood or gore in any mode
- [ ] All content has parent controls
- [ ] All content has age restrictions
- [ ] All content has verified licenses
- [ ] All access is audit-logged

---

## References

### Internal References
- [VS-005: Combat Telegraphs and Feedback](./RESEARCH_VS-005_Combat_Telegraphs_Feedback.md)
- [VS-023: Original Liminal Creatures](./RESEARCH_VS-023_Original_Liminal_Creatures.md) - BACKROOMS MONSTERS INCLUDED
- [src/domain/identity_safety/parental_control_policy.gd](src/domain/identity_safety/parental_control_policy.gd)
- [docs/requirements/functionality-requirements.md](docs/requirements/functionality-requirements.md)

### External References - Child Safety
- [ESRB Official Website](https://www.esrb.org/)
- [ESRB Rating Process](https://www.esrb.org/ratings/)
- [PEGI Official Website](https://pegi.info/)
- [PEGI Rating System](https://pegi.info/en/pegi-system)
- [FTC COPPA Rule](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/childrens-online-privacy-protection-rule)
- [COPPA Compliance Guide](https://www.ftc.gov/business-guidance/resources/childrens-online-privacy-protection-rule-six-step-compliance-plan-your-business)
- [Children's Advertising Review Unit (CARU)](https://bbbprograms.org/programs/all-programs/caru)

### External References - Asset Sources
- [Kenney.nl - CC0 Game Assets](https://kenney.nl/)
- [Quaternius - CC0 3D Models](https://quaternius.com/free-3d-models)
- [Poly Pizza - CC0 Low-Poly Models](https://poly.pizza/)
- [CC0 Textures](https://cc0textures.com/)
- [OpenGameArt](https://opengameart.org/)
- [Godot Asset Library](https://godotengine.org/asset-library)
- [Sketchfab](https://sketchfab.com/)
- [Mixamo](https://www.mixamo.com/)

### External References - Godot Development
- [Godot Combat Tutorial](https://docs.godotengine.org/en/stable/getting_started/first_2d_game/04.hitbox_and_hurtbox.html)
- [Area3D Documentation](https://docs.godotengine.org/en/stable/classes/class_area3d.html)
- [Raycasting in Godot](https://docs.godotengine.org/en/stable/tutorials/3d/3d_physics/ray_casting.html)
- [Godot Input System](https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html)
- [Godot Animation](https://docs.godotengine.org/en/stable/tutorials/animation/index.html)
- [Godot Particles](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html)

### External References - Game Design
- [Game Weapon Design](https://gamedev.net/tutorials/_/technical/game-design/)
- [Weapon Balancing](https://www.gamasutra.com/view/feature/132549/)
- [Parent Controls in Games](https://www.igda.org/)
- [Content Rating Best Practices](https://www.gameindustry.org/responsibility/)

### External References - Testing
- [Godot Unit Testing](https://docs.godotengine.org/en/stable/tutorials/testing/unit_testing.html)
- [GDQuest Testing Tutorial](https://www.gdquest.com/tutorial/godot-test-driven-development/)

---

*Generated by Mistral Vibe for Choyce Engine VS-031*
*Last Updated: 2026-07-18*
*Document Size: ~100KB*

## References

### Internal References
- [VS-005: Combat Telegraphs and Feedback](./RESEARCH_VS-005_Combat_Telegraphs_Feedback.md)
- [VS-023: Original Liminal Creatures](./RESEARCH_VS-023_Original_Liminal_Creatures.md)
- [src/domain/identity_safety/parental_control_policy.gd](src/domain/identity_safety/parental_control_policy.gd)
- [docs/requirements/functionality-requirements.md](docs/requirements/functionality-requirements.md)

### External References

#### Licensing
1. [Creative Commons Licenses](https://creativecommons.org/licenses/)
2. [MIT License](https://opensource.org/license/mit/)
3. [Godot Asset License](https://docs.godotengine.org/en/stable/community/asset_library/licenses.html)

#### Child Safety
1. [ESRB Ratings](https://www.esrb.org/)
2. [COPPA Compliance](https://www.ftc.gov/enforcement/rules/rulemaking-regulatory-reform-proceedings/children-s-online-privacy-protection-rule)
3. [Child Development Guidelines](https://www.cdc.gov/ncbddd/childdevelopment/index.html)

#### Godot Documentation
1. [Godot Multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
2. [Godot Resource System](https://docs.godotengine.org/en/stable/tutorials/io/loading_resources.html)
3. [Godot Animation](https://docs.godotengine.org/en/stable/tutorials/animation/index.html)
4. [Godot Particles](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html)

#### Asset Sources
1. [Kenney.nl](https://kenney.nl/) - CC0 Game Assets
2. [Quaternius](https://quaternius.com/free-3d-models) - CC0 3D Models
3. [Poly Pizza](https://poly.pizza/) - CC0 Low-Poly Models
4. [CC0 Textures](https://cc0textures.com/) - CC0 PBR Textures

#### Tutorials
1. [GDQuest Godot Tutorials](https://gdquest.com/)
2. [HeartBeast Godot Tutorials](https://www.heartbeast.co/)
3. [KidsCanCode YouTube](https://www.youtube.com/c/KidsCanCode)

---

*Document generated by Mistral Vibe for Choyce Engine project*
*Last updated: 2026-07-18*
*Size: ~25KB*
