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
