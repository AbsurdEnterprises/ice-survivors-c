# ICE Survivors — V1 Engine Build: One-Shot Agent Prompt

## System Role

You are a Senior Game Developer specializing in Godot 4.4+ with GDScript. You will build a highly optimized 2D bullet-heaven survival game engine. The game features a single player character surviving 30 minutes against thousands of procedurally spawning enemies, with automatic weapons, experience-based leveling, item selection, and weapon evolution mechanics.

V1 uses **geometric primitives only** — no sprite assets. The player is a blue `ColorRect`, enemies are red/orange/purple rectangles of varying sizes, projectiles are small yellow circles (`draw_circle` in `_draw()`), and experience pickups are green diamonds. Visual polish comes in V2; your job is pristine systems, math, and performance.

---

## Architecture Overview

Use Godot's node/scene composition. Keep scene trees **shallow** — most logic lives in GDScript, not deep node nesting. The project structure:

```
res://
├── project.godot
├── scenes/
│   ├── main.tscn              # Root scene, manages game state
│   ├── player.tscn             # Player node (CharacterBody2D)
│   ├── enemy.tscn              # Pooled enemy template (CharacterBody2D)
│   ├── projectile.tscn         # Pooled projectile template (Area2D)
│   ├── xp_gem.tscn             # Pooled XP pickup (Area2D)
│   ├── hud.tscn                # UI overlay (CanvasLayer)
│   └── level_up_screen.tscn    # Pause menu for item selection
├── scripts/
│   ├── game_manager.gd         # Master game loop, timers, state machine
│   ├── player.gd               # Movement, stats, inventory, damage
│   ├── enemy_spawner.gd        # Spawning curves, pool management
│   ├── enemy.gd                # Enemy AI, scaling, death
│   ├── weapon_system.gd        # Weapon firing, cooldowns, evolution checks
│   ├── weapons/                # One script per weapon behavior
│   │   ├── weapon_base.gd
│   │   ├── weapon_01.gd        # Directional melee sweep
│   │   ├── weapon_02.gd        # Auto-target nearest projectile
│   │   ├── weapon_03.gd        # Directional barrage
│   │   ├── weapon_04.gd        # Arcing lob projectile
│   │   ├── weapon_05.gd        # Persistent aura
│   │   ├── weapon_06.gd        # Random ground pools
│   │   ├── weapon_07.gd        # Orbiting projectiles
│   │   ├── weapon_08.gd        # Random strike (lightning)
│   │   ├── weapon_09.gd        # Bouncing projectile
│   │   └── weapon_10.gd        # Rotating freeze beam
│   ├── projectile_pool.gd      # Object pool for projectiles
│   ├── enemy_pool.gd           # Object pool for enemies
│   ├── xp_pool.gd              # Object pool for XP gems
│   ├── collision_manager.gd    # Spatial hash grid for game-logic queries
│   ├── camera.gd               # Smooth follow camera
│   ├── level_up_manager.gd     # Item selection RNG, UI
│   ├── meta_progression.gd     # Persistent upgrades (save/load)
│   └── data/
│       ├── weapon_data.gd      # Weapon/passive/evolution lookup tables
│       ├── enemy_data.gd       # Enemy class definitions
│       └── character_data.gd   # Playable character stat blocks
└── save/
    └── (save.json created at runtime)
```

### Critical Performance Rules

1. **Object Pooling is mandatory.** Never use `queue_free()` on enemies, projectiles, or XP gems during gameplay. Deactivate them (`visible = false`, `set_physics_process(false)`, move to `Vector2(-9999, -9999)`) and return to the pool array. Reactivate from the pool on spawn.

2. **Spatial Hash Grid.** Divide the game world into 128×128 pixel cells. Register every active entity's cell each frame. For collision queries, check only same-cell and 8 adjacent cells. This reduces collision checks from O(N²) to near O(N).

3. **Batch damage numbers.** Do not use Godot's Label node for floating damage text. Pre-generate a texture atlas of digits 0-9 as a single image. Render damage numbers by compositing digit sprites. Pool these too.

4. **XP Gem Aggregation.** If uncollected XP gems exceed 200, merge all gems into a single high-value gem at the centroid of the cluster. This prevents thousands of Area2D nodes from tanking physics performance.

5. **Enemy Cap.** Hard cap active enemies at the value defined by `M_CAP` in the spawning formula. When the cap is reached, stop spawning until slots free up. Target: 500 for unoptimized, 2000+ for optimized.

---

## Core Gameplay Loop

Each run lasts exactly **30 minutes**. The loop, every frame:

1. Process player input → 8-directional movement
2. Update camera to track player
3. Run enemy spawner (check spawn timer, spawn from pool if under cap)
4. Update all active enemies (move toward player using their AI script)
5. Update all active weapons (check cooldown timers, fire if ready)
6. Update all active projectiles (move, check lifetime, check collisions via spatial hash)
7. Process collisions: projectile→enemy (deal damage), enemy→player (deal damage, trigger i-frames), player→xp_gem (collect)
8. Check XP thresholds → trigger level-up pause if crossed
9. Update HUD (HP bar, XP bar, timer, kill count)
10. At minute 30, spawn the final boss entity

---

## Mathematical Models

### Enemy Spawning Curve

```
N(t) = min(M_CAP, floor(B_S * (1 + r)^t + S(t)))
```

| Variable | Value | Description |
|----------|-------|-------------|
| `M_CAP` | 500 (initial), 2000 (optimized) | Max concurrent enemies |
| `B_S` | 8 | Base enemies spawned per cycle |
| `r` | 0.12 | Exponential growth rate |
| `t` | minutes elapsed (float) | Time into run |
| `S(t)` | Step function | Surge waves (see below) |

**Surge waves `S(t)`:**
- t = 5.0 min → +40 enemies over 10 seconds
- t = 10.0 min → +80 enemies over 10 seconds (coincides with Boss 1)
- t = 15.0 min → +120 enemies over 10 seconds
- t = 20.0 min → +160 enemies over 10 seconds (coincides with Boss 2)
- t = 25.0 min → +200 enemies over 10 seconds
- t = 30.0 min → Final boss spawn, standard spawning stops

**Spawn position:** Calculate a point on an ellipse around the player, just outside viewport bounds. Ellipse semi-axes = `(viewport_width/2 + 64, viewport_height/2 + 64)`. Randomize angle θ ∈ [0, 2π).

```
spawn_x = player.x + (hw + 64) * cos(θ)
spawn_y = player.y + (hh + 64) * sin(θ)
```

### Enemy Health Scaling

```
H_e(t) = H_BASE * (1 + t * 0.15) * C_MOD
```

| Enemy Class | `H_BASE` | `C_MOD` | Speed (`V_BASE`) | Behavior |
|-------------|----------|---------|-------------------|----------|
| `fodder_01` (Bureaucrat) | 10 | 0.8 | 40 px/s | Direct path to player |
| `erratic_02` (Recruit) | 15 | 1.0 | 55 px/s | Path to player with random pauses (0.5–2s) |
| `tank_03` (Tactical) | 40 | 5.0 | 35 px/s | Direct path, immune to knockback |
| `ranged_04` (Botnet) | 20 | 1.2 | 25 px/s | Orbits at 400px radius, fires projectiles inward every 3s |
| `hazard_05` (Vehicle) | 999 | 1.0 | 300 px/s | Straight line across screen, despawns at edge. NOT pooled — one-shot hazard on a timer. |

**Enemy speed scaling:**
```
V_e(t) = V_BASE + (t * 0.02 * V_BASE)
```

### Player Damage Formula (NEW — fills design gap)

```
Damage = BASE_DMG * (1 + (weapon_level - 1) * 0.25) * area_mult * crit_mult
```

| Variable | Description |
|----------|-------------|
| `BASE_DMG` | Per-weapon base damage (see weapon table) |
| `weapon_level` | 1–8, each level adds 25% of base |
| `area_mult` | 1.0 + (character_area_bonus + passive_area_bonus) |
| `crit_mult` | If crit triggers: 2.0. Otherwise: 1.0 |
| `crit_chance` | 0.05 + (luck_stat * 0.01). Capped at 0.50 |

**Weapon DPS verification for 30-minute survivability:**

At t=25 minutes, a `tank_03` enemy has HP = `40 * (1 + 25*0.15) * 5.0 = 40 * 4.75 * 5.0 = 950 HP`.

A Level 8 `weapon_02` (auto-target) deals `12 * (1 + 7*0.25) = 12 * 2.75 = 33 damage` per shot at 0.3s cooldown = **110 DPS**. Time to kill one tank: ~8.6 seconds. This is intentionally slow for a single weapon — the design forces players to build synergistic multi-weapon loadouts. With 4-5 weapons active plus evolutions, total DPS should reach 500-800 by minute 25.

### Invincibility Frames (NEW — fills design gap)

After taking damage, the player is invulnerable for **0.5 seconds**. During i-frames:
- Player cannot take damage from any source
- Player visual blinks (toggle `visible` every 0.05s via a Timer)
- Player can still move, collect XP, and deal damage normally

Implement as a boolean `is_invulnerable` + a `Timer` node on the player scene.

### Experience and Leveling

```
XP_required(L) = floor(10 * L^1.5 + 50)
```

| Level | XP Required | Cumulative |
|-------|-------------|------------|
| 1→2 | 60 | 60 |
| 5→6 | 162 | 640 |
| 10→11 | 366 | 2,206 |
| 20→21 | 944 | 9,778 |
| 30→31 | 1,693 | 25,174 |

XP dropped per enemy kill:
- `fodder_01`: 1 XP
- `erratic_02`: 2 XP
- `tank_03`: 10 XP
- `ranged_04`: 5 XP
- Boss: 200 XP

### Level-Up Selection

On level up, pause the game. Present **4 options** (3 at Level 1). Options are drawn from the combined pool of all weapons and passive items the player does NOT have at max level.

**Selection weighting:**
- Item player doesn't own yet: weight = `10 + (luck * 2)`
- Upgrade to existing item: weight = `20`
- Rare items (passives 05, 06): weight = `5 + (luck * 3)`

Normalize weights to probabilities. Draw without replacement for the 4 slots.

### Treasure Chest Fallback (NEW — fills design gap)

When a boss is killed, it drops a Treasure Chest. On pickup:

1. **Check for eligible evolution:** Player has a Level 8 base weapon AND the required Level 1+ passive. If YES → force the evolution. Remove the base weapon, inject the evolution weapon. Passive stays.
2. **Multiple eligible:** If more than one evolution is available, present them as a selection screen (like level-up).
3. **No eligible evolution:** Award `300 gold` + full HP heal + 10 seconds of invulnerability.

---

## Data Schemas

### Weapon Definitions

```json
{
  "weapons": [
    {
      "id": "weapon_01",
      "type": "melee_sweep",
      "base_dmg": 15,
      "cooldown": 1.1,
      "area": 1.0,
      "knockback": 80,
      "projectile_count": 1,
      "pierce": 999,
      "max_level": 8,
      "description": "Horizontal sweep in facing direction"
    },
    {
      "id": "weapon_02",
      "type": "auto_target",
      "base_dmg": 12,
      "cooldown": 0.3,
      "area": 0.5,
      "knockback": 10,
      "projectile_count": 1,
      "pierce": 1,
      "max_level": 8,
      "description": "Fires projectile at nearest enemy"
    },
    {
      "id": "weapon_03",
      "type": "directional_barrage",
      "base_dmg": 8,
      "cooldown": 0.25,
      "area": 0.3,
      "knockback": 30,
      "projectile_count": 3,
      "pierce": 1,
      "max_level": 8,
      "description": "Fires burst in movement direction"
    },
    {
      "id": "weapon_04",
      "type": "arcing_lob",
      "base_dmg": 22,
      "cooldown": 1.8,
      "area": 1.2,
      "knockback": 40,
      "projectile_count": 1,
      "pierce": 3,
      "max_level": 8,
      "description": "Arcing projectile that falls through enemies"
    },
    {
      "id": "weapon_05",
      "type": "persistent_aura",
      "base_dmg": 5,
      "cooldown": 0.5,
      "area": 1.5,
      "knockback": 60,
      "projectile_count": 0,
      "pierce": 999,
      "max_level": 8,
      "description": "Constant damage zone around player, reduces enemy knockback resistance"
    },
    {
      "id": "weapon_06",
      "type": "ground_pool",
      "base_dmg": 18,
      "cooldown": 3.0,
      "area": 1.8,
      "knockback": 5,
      "projectile_count": 1,
      "pierce": 999,
      "max_level": 8,
      "description": "Drops damaging zone at random nearby location, persists 3s"
    },
    {
      "id": "weapon_07",
      "type": "orbiting",
      "base_dmg": 10,
      "cooldown": 0.0,
      "area": 0.8,
      "knockback": 50,
      "projectile_count": 3,
      "pierce": 999,
      "max_level": 8,
      "description": "Projectiles orbit player continuously, block and damage enemies"
    },
    {
      "id": "weapon_08",
      "type": "random_strike",
      "base_dmg": 30,
      "cooldown": 2.0,
      "area": 1.0,
      "knockback": 20,
      "projectile_count": 1,
      "pierce": 999,
      "max_level": 8,
      "description": "Strikes random enemy location with explosive vertical blast"
    },
    {
      "id": "weapon_09",
      "type": "bouncing",
      "base_dmg": 14,
      "cooldown": 2.5,
      "area": 0.6,
      "knockback": 15,
      "projectile_count": 1,
      "pierce": 999,
      "max_level": 8,
      "description": "Projectile bounces off screen edges infinitely, passes through enemies"
    },
    {
      "id": "weapon_10",
      "type": "freeze_beam",
      "base_dmg": 0,
      "cooldown": 0.0,
      "area": 2.0,
      "knockback": 0,
      "projectile_count": 1,
      "pierce": 999,
      "max_level": 8,
      "description": "Rotating beam that freezes enemies for 2s, deals no damage"
    }
  ]
}
```

### Passive Item Definitions

```json
{
  "passives": [
    { "id": "passive_01", "stat": "max_hp", "bonus_per_level": 0.10, "max_level": 5, "description": "+10% max HP per level" },
    { "id": "passive_02", "stat": "cooldown_reduction", "bonus_per_level": 0.08, "max_level": 5, "description": "-8% weapon cooldown per level" },
    { "id": "passive_03", "stat": "projectile_speed", "bonus_per_level": 0.10, "max_level": 5, "description": "+10% projectile speed per level" },
    { "id": "passive_04", "stat": "area", "bonus_per_level": 0.10, "max_level": 5, "description": "+10% AoE size per level" },
    { "id": "passive_05", "stat": "hp_regen", "bonus_per_level": 0.3, "max_level": 5, "description": "+0.3 HP/s per level" },
    { "id": "passive_06", "stat": "xp_radius", "bonus_per_level": 0.20, "max_level": 5, "description": "+20% XP pickup radius per level" },
    { "id": "passive_07", "stat": "effect_duration", "bonus_per_level": 0.10, "max_level": 5, "description": "+10% weapon effect duration per level" },
    { "id": "passive_08", "stat": "luck", "bonus_per_level": 0.10, "max_level": 5, "description": "+10% luck per level" },
    { "id": "passive_09", "stat": "armor", "bonus_per_level": 1.0, "max_level": 5, "description": "+1 flat damage reduction per level" },
    { "id": "passive_10", "stat": "damage_bonus", "bonus_per_level": 0.05, "max_level": 5, "description": "+5% global damage per level" }
  ]
}
```

### Evolution Lookup Table

```json
{
  "evolutions": [
    { "id": "evo_01", "requires_weapon": "weapon_01", "requires_passive": "passive_01", "replaces": "weapon_01",
      "bonus": "crit_lifesteal", "effect": "Deals critical hits, heals 5% of damage dealt" },
    { "id": "evo_02", "requires_weapon": "weapon_02", "requires_passive": "passive_02", "replaces": "weapon_02",
      "bonus": "continuous_beam", "effect": "Fires continuous piercing beam, zero cooldown" },
    { "id": "evo_03", "requires_weapon": "weapon_03", "requires_passive": "passive_03", "replaces": "weapon_03",
      "bonus": "mass_knockback", "effect": "Continuous barrage with massive knockback, pushes enemies off-screen" },
    { "id": "evo_04", "requires_weapon": "weapon_04", "requires_passive": "passive_04", "replaces": "weapon_04",
      "bonus": "ring_explosion", "effect": "Fires ring of projectiles outward in all directions, passes through all" },
    { "id": "evo_05", "requires_weapon": "weapon_05", "requires_passive": "passive_05", "replaces": "weapon_05",
      "bonus": "hp_steal_aura", "effect": "Massive aura steals enemy HP, heals player. Scales with missing HP" },
    { "id": "evo_06", "requires_weapon": "weapon_06", "requires_passive": "passive_06", "replaces": "weapon_06",
      "bonus": "homing_pools", "effect": "Pools slowly drift toward player, merge into mega-pool on overlap" },
    { "id": "evo_07", "requires_weapon": "weapon_07", "requires_passive": "passive_07", "replaces": "weapon_07",
      "bonus": "permanent_orbit", "effect": "Orbitals never despawn, count increases to 8, permanent rotating shield" },
    { "id": "evo_08", "requires_weapon": "weapon_08", "requires_passive": "passive_08", "replaces": "weapon_08",
      "bonus": "double_strike", "effect": "Each strike hits same location twice, second hit deals 3x damage" },
    { "id": "evo_09", "requires_weapon": "weapon_09", "requires_passive": "passive_09", "replaces": "weapon_09",
      "bonus": "bounce_explode", "effect": "Explodes on every bounce dealing AoE, retains piercing" },
    { "id": "evo_10", "requires_weapon": "weapon_10", "requires_passive": ["passive_10", "passive_09"], "replaces": "weapon_10",
      "bonus": "infinite_freeze", "effect": "Freezes all on-screen enemies, halves all entity HP each full rotation" }
  ]
}
```

Note: `evo_10` requires TWO passives (`passive_10` AND `passive_09`) both at Level 1+. This is the ultimate evolution.

### Character Definitions

```json
{
  "characters": [
    {
      "id": "char_01",
      "starting_weapon": "weapon_05",
      "stat_modifiers": { "max_hp": 1.20, "move_speed": 0.90, "damage": 1.0, "area": 1.0, "armor": 0, "luck": 0 },
      "base_stats": { "max_hp": 120, "move_speed": 135, "xp_radius": 64 }
    },
    {
      "id": "char_02",
      "starting_weapon": "weapon_02",
      "stat_modifiers": { "max_hp": 1.0, "move_speed": 1.0, "damage": 0.90, "area": 1.30, "armor": 0, "luck": 0 },
      "base_stats": { "max_hp": 100, "move_speed": 150, "xp_radius": 64 }
    },
    {
      "id": "char_03",
      "starting_weapon": "weapon_01",
      "stat_modifiers": { "max_hp": 1.0, "move_speed": 1.15, "damage": 1.0, "area": 1.0, "armor": -1, "luck": 0 },
      "base_stats": { "max_hp": 100, "move_speed": 172, "xp_radius": 64 }
    },
    {
      "id": "char_04",
      "starting_weapon": "weapon_03",
      "stat_modifiers": { "max_hp": 0.80, "move_speed": 1.40, "damage": 1.0, "area": 1.0, "armor": 0, "luck": 0 },
      "base_stats": { "max_hp": 80, "move_speed": 210, "xp_radius": 64 }
    },
    {
      "id": "char_05",
      "starting_weapon": "weapon_08",
      "stat_modifiers": { "max_hp": 1.0, "move_speed": 1.0, "damage": 1.0, "area": 1.0, "armor": 0, "luck": 0.20 },
      "base_stats": { "max_hp": 100, "move_speed": 150, "xp_radius": 64 }
    },
    {
      "id": "char_06",
      "starting_weapon": "weapon_07",
      "stat_modifiers": { "max_hp": 1.0, "move_speed": 0.70, "damage": 1.0, "area": 1.0, "armor": 5, "luck": 0 },
      "base_stats": { "max_hp": 100, "move_speed": 105, "xp_radius": 64 }
    }
  ]
}
```

### Boss Definitions

```json
{
  "bosses": [
    {
      "id": "boss_01",
      "spawn_time_minutes": 10,
      "hp_formula": "500 * (1 + t * 0.15) * 10",
      "speed": 60,
      "behavior": "drone_deployer",
      "notes": "Spawns 3 fast mini-drones every 4 seconds. Drones have 30 HP, speed 200, direct path. Boss itself moves slowly toward player. Lock camera bounds to arena.",
      "drops": "treasure_chest"
    },
    {
      "id": "boss_02",
      "spawn_time_minutes": 20,
      "hp_formula": "500 * (1 + t * 0.15) * 20",
      "speed": 40,
      "behavior": "aoe_bombarder",
      "notes": "Fires slow-moving AoE blast every 3 seconds. Blast travels to target location, explodes in 96px radius, leaves burning ground for 4 seconds dealing 5 DPS. Boss moves toward player. Lock camera bounds.",
      "drops": "treasure_chest"
    },
    {
      "id": "boss_final",
      "spawn_time_minutes": 30,
      "hp_formula": "player_level * 655350",
      "speed": 999,
      "behavior": "death_wall",
      "notes": "Unkillable. Moves faster than max player speed. Instant kill on contact. Run ends on contact. This is the genre-standard run terminator."
    }
  ]
}
```

### Enemy Class Composition by Time

| Time Range | fodder_01 | erratic_02 | tank_03 | ranged_04 | hazard_05 |
|------------|-----------|------------|---------|-----------|-----------|
| 0–3 min | 100% | 0% | 0% | 0% | 0% |
| 3–7 min | 60% | 35% | 0% | 5% | 0% |
| 7–12 min | 40% | 30% | 15% | 10% | 5% |
| 12–20 min | 25% | 25% | 25% | 15% | 10% |
| 20–30 min | 15% | 20% | 30% | 20% | 15% |

---

## Player Damage Intake

```
damage_taken = max(1, enemy_base_contact_damage * (1 + t * 0.08) - player_armor)
```

| Enemy Class | Base Contact Damage |
|-------------|-------------------|
| fodder_01 | 5 |
| erratic_02 | 8 |
| tank_03 | 15 |
| ranged_04 (projectile) | 12 |
| hazard_05 | 50 |
| boss_01 (contact) | 25 |
| boss_02 (contact) | 30 |
| boss_02 (AoE blast) | 20 |
| boss_final | 99999 (instant kill) |

Minimum damage is always 1 (armor can never fully negate).

---

## Meta-Progression (Persistent Upgrades)

Saved to `user://save.json`. Gold is earned during runs (1 gold per elite kill, 5 per boss, random drops from destructibles).

```json
{
  "meta_upgrades": [
    { "id": "meta_01", "stat": "armor", "bonus_per_level": 1, "max_level": 5, "base_cost": 200 },
    { "id": "meta_02", "stat": "cooldown_reduction", "bonus_per_level": 0.03, "max_level": 5, "base_cost": 300 },
    { "id": "meta_03", "stat": "area", "bonus_per_level": 0.05, "max_level": 5, "base_cost": 250 },
    { "id": "meta_04", "stat": "revive", "bonus_per_level": 1, "max_level": 1, "base_cost": 5000 }
  ]
}
```

**Upgrade cost formula:**
```
cost(level) = base_cost * (1.5 * level)
```

Where `level` is the level being purchased (1-indexed). Level 1 of meta_01 costs `200 * 1.5 = 300`, Level 2 costs `200 * 3.0 = 600`, etc.

`meta_04` (auto-revive) triggers once per run: on death, restore 50% HP and grant 3 seconds of invulnerability. Consumed on use, available again next run.

---

## Destructible Objects

Spawn destructible props at random positions during world generation. Density: approximately 1 per 512×512 pixel area.

| Object | HP | Drop |
|--------|-----|------|
| destructible_01 (prop) | 5 | 50% nothing, 30% small_heal (15 HP), 15% gold (1-3), 5% screen_nuke |
| destructible_02 (prop) | 10 | 40% nothing, 25% medium_heal (30 HP), 20% gold (2-5), 10% magnet, 5% screen_nuke |

**Magnet:** On pickup, all XP gems on the map fly toward the player over 2 seconds.

**Screen Nuke:** On pickup, instantly destroy all non-boss enemies currently on screen. Flash the screen white for 0.1s.

---

## Stage Design

### Stage 1: Urban Avenue (default)

- Infinite horizontal scrolling, vertically constrained to 600px band
- Background: tiled grey rectangles (buildings) with white rectangle ground
- Environmental hazards: every 45 seconds, a `hazard_05` vehicle crosses the screen horizontally

### Stage 2: Mall (unlocked after first boss kill)

- Infinite in both X and Y
- Static rectangular obstacles (kiosks) placed procedurally — 8×8 grid of 64×64 blocks with 256px spacing
- Escalator zones (colored rectangles) that apply forced movement vector to player for 1 second when entered

### Stage 3: Wilderness (unlocked after minute 20 survival)

- Infinite in both X and Y
- Dense procedural tree placement (green circles, impassable) using Poisson disc sampling, min distance 96px
- Enemies spawn from tree line edges (nearest tree cluster boundary) instead of screen edge

---

## Development Phases — Execute In Order

### PHASE 1: Core Movement and Camera
- [ ] Create `project.godot` with 1280×720 viewport, pixel snap ON
- [ ] Create `player.tscn`: CharacterBody2D with a 32×32 blue ColorRect and CollisionShape2D
- [ ] Implement 8-directional movement in `player.gd` with base speed from character data
- [ ] Create `camera.gd`: Camera2D that smoothly follows the player (lerp, weight 0.1)
- [ ] Implement infinite scrolling background using tiled grey/white ColorRects
- [ ] Test: Player moves smoothly in all directions, camera follows

### PHASE 2: Enemy Pool and Spawning
- [ ] Create `enemy.tscn`: CharacterBody2D with variable-size red ColorRect and CollisionShape2D
- [ ] Implement `enemy_pool.gd`: Pre-instantiate 500 enemy nodes, all deactivated
- [ ] Implement `enemy_spawner.gd`: Spawn timer, ellipse position calculation, N(t) formula
- [ ] Implement `enemy.gd`: `fodder_01` AI (move directly toward player position each frame)
- [ ] Add `erratic_02` AI: same as fodder but with random pause timer
- [ ] Test: Enemies spawn at correct rates, track player, pool recycles properly

### PHASE 3: Collision and Damage
- [ ] Implement `collision_manager.gd`: Spatial hash grid, 128px cells
- [ ] Register all active enemies and projectiles in the grid each physics frame
- [ ] Implement enemy→player collision: deal damage, trigger i-frames (0.5s), visual blink
- [ ] Implement player HP, HP bar on HUD
- [ ] Implement enemy death: deactivate, return to pool, spawn XP gem
- [ ] Test: Player takes damage from enemies, i-frames work, enemies die when HP reaches 0

### PHASE 4: XP and Leveling
- [ ] Create `xp_gem.tscn`: Area2D with small green diamond shape
- [ ] Implement `xp_pool.gd`: Pool of 300 XP gem nodes
- [ ] Implement XP pickup via player's Area2D (with radius from character data)
- [ ] Implement XP bar on HUD, level counter
- [ ] Implement XP(L) formula, trigger level-up state on threshold
- [ ] Implement XP gem aggregation (merge when >200 active)
- [ ] Build `level_up_screen.tscn`: Pause game, show 4 item options as clickable rectangles with text
- [ ] Implement weighted random selection algorithm for item offers
- [ ] Test: Kill enemies → gems drop → collect → level up → select item → game resumes

### PHASE 5: Weapon System
- [ ] Implement `weapon_base.gd`: Base class with cooldown timer, damage calculation, level tracking
- [ ] Create `projectile.tscn` and `projectile_pool.gd` (pool of 1000)
- [ ] Implement `weapon_02` (auto-target): Find nearest enemy via spatial hash, fire projectile
- [ ] Implement `weapon_05` (aura): Persistent Area2D around player, damage tick every 0.5s
- [ ] Implement `weapon_01` (sweep): Raycast or area sweep in facing direction
- [ ] Implement `weapon_03` (barrage): Multi-projectile burst in movement direction
- [ ] Implement `weapon_04` (lob): Arcing trajectory using parabolic motion
- [ ] Implement `weapon_06` (ground pool): Random position, persistent damage zone
- [ ] Implement `weapon_07` (orbit): Projectiles orbit at fixed radius using sin/cos
- [ ] Implement `weapon_08` (strike): Random enemy position, instant AoE
- [ ] Implement `weapon_09` (bounce): Bounce off viewport edges, pierce enemies
- [ ] Implement `weapon_10` (freeze): Rotating beam, applies freeze status (speed = 0 for 2s)
- [ ] Implement weapon leveling: Each level increases stats per the 25% formula
- [ ] Test: Each weapon fires correctly, damages enemies, levels up

### PHASE 6: Evolution System
- [ ] Implement inventory tracking: arrays for active weapons (max 6) and passive items (max 6)
- [ ] Implement passive item stat application on the player
- [ ] Implement evolution lookup check on treasure chest pickup
- [ ] Implement treasure chest entity (dropped by bosses)
- [ ] Implement chest fallback: no eligible evolution → gold + heal
- [ ] Implement at least `evo_02` (continuous beam) and `evo_05` (HP steal aura) as proof of concept
- [ ] Test: Level weapon to 8, have required passive, kill boss, open chest → evolution triggers

### PHASE 7: Boss Encounters
- [ ] Implement `boss_01`: Large purple rectangle, drone spawner behavior, HP bar on screen
- [ ] Implement camera lock on boss spawn (restrict player to visible arena)
- [ ] Implement `boss_02`: AoE bombardment pattern
- [ ] Implement `boss_final`: Death wall at minute 30, instant kill, run terminator
- [ ] Implement treasure chest drop on boss_01 and boss_02 death
- [ ] Test: Bosses spawn at correct times, behaviors work, chests drop

### PHASE 8: Additional Enemy Types
- [ ] Implement `tank_03`: Direct path, knockback immunity flag
- [ ] Implement `ranged_04`: Orbit behavior at 400px, fire projectile at player every 3s
- [ ] Implement `hazard_05`: Straight-line cross, extreme speed, despawn at edge
- [ ] Implement enemy class composition table (spawn probability by time bracket)
- [ ] Test: All enemy types behave correctly, composition shifts over time

### PHASE 9: Destructibles, Pickups, and Stage Hazards
- [ ] Implement destructible objects: static rectangles with HP, random drops
- [ ] Implement heal pickup, gold pickup, magnet pickup, screen nuke pickup
- [ ] Implement Stage 1 vehicle hazard (periodic `hazard_05` crossing)
- [ ] Test: Destructibles break, drops function, hazards damage both player and enemies

### PHASE 10: Meta-Progression and Save System
- [ ] Implement gold tracking during runs
- [ ] Implement save/load to `user://save.json`
- [ ] Build main menu: character select, meta-upgrade shop, stage select
- [ ] Implement meta-upgrade purchase with cost formula
- [ ] Apply meta-upgrades to player base stats on run start
- [ ] Implement `meta_04` auto-revive mechanic
- [ ] Test: Buy upgrades, save, reload, verify persistence, start run with boosted stats

### PHASE 11: Polish and Game Feel
- [ ] Add screen shake on boss spawn and player hit
- [ ] Add kill counter and timer to HUD
- [ ] Add floating damage numbers (sprite-batched digits from pre-rendered atlas)
- [ ] Add run-end summary screen: time survived, kills, gold earned
- [ ] Implement remaining evolutions from the lookup table
- [ ] Balance pass: play through full 30 minutes, tune damage curves if needed

---

## Final Notes for the Agent

- **Test each phase before moving to the next.** Print debug output to confirm pool sizes, entity counts, and frame timings.
- **Target 60 FPS with 500+ active enemies.** If frame time exceeds 16ms, profile and optimize before proceeding.
- **Do not use `queue_free()` on pooled entities.** This is the single most common performance mistake.
- **All numeric values in this document are authoritative.** Do not invent new values or "round" the formulas. Implement them exactly.
- **Commit after each phase.** Use descriptive commit messages: "Phase 3: Spatial hash collision + i-frames + enemy death."
