extends Node
class_name WeaponData

const WEAPONS := {
	"weapon_01": {
		"type": "melee_sweep", "base_dmg": 15, "cooldown": 1.1, "area": 1.0,
		"knockback": 80, "projectile_count": 1, "pierce": 999, "max_level": 8,
		"description": "Horizontal sweep in facing direction"
	},
	"weapon_02": {
		"type": "auto_target", "base_dmg": 12, "cooldown": 0.3, "area": 0.5,
		"knockback": 10, "projectile_count": 1, "pierce": 1, "max_level": 8,
		"description": "Fires projectile at nearest enemy"
	},
	"weapon_03": {
		"type": "directional_barrage", "base_dmg": 8, "cooldown": 0.25, "area": 0.3,
		"knockback": 30, "projectile_count": 3, "pierce": 1, "max_level": 8,
		"description": "Fires burst in movement direction"
	},
	"weapon_04": {
		"type": "arcing_lob", "base_dmg": 22, "cooldown": 1.8, "area": 1.2,
		"knockback": 40, "projectile_count": 1, "pierce": 3, "max_level": 8,
		"description": "Arcing projectile that falls through enemies"
	},
	"weapon_05": {
		"type": "persistent_aura", "base_dmg": 5, "cooldown": 0.5, "area": 1.5,
		"knockback": 60, "projectile_count": 0, "pierce": 999, "max_level": 8,
		"description": "Constant damage zone around player"
	},
	"weapon_06": {
		"type": "ground_pool", "base_dmg": 18, "cooldown": 3.0, "area": 1.8,
		"knockback": 5, "projectile_count": 1, "pierce": 999, "max_level": 8,
		"description": "Drops damaging zone at random nearby location"
	},
	"weapon_07": {
		"type": "orbiting", "base_dmg": 10, "cooldown": 0.0, "area": 0.8,
		"knockback": 50, "projectile_count": 3, "pierce": 999, "max_level": 8,
		"description": "Projectiles orbit player continuously"
	},
	"weapon_08": {
		"type": "random_strike", "base_dmg": 30, "cooldown": 2.0, "area": 1.0,
		"knockback": 20, "projectile_count": 1, "pierce": 999, "max_level": 8,
		"description": "Strikes random enemy location with explosive blast"
	},
	"weapon_09": {
		"type": "bouncing", "base_dmg": 14, "cooldown": 2.5, "area": 0.6,
		"knockback": 15, "projectile_count": 1, "pierce": 999, "max_level": 8,
		"description": "Projectile bounces off screen edges"
	},
	"weapon_10": {
		"type": "freeze_beam", "base_dmg": 0, "cooldown": 0.0, "area": 2.0,
		"knockback": 0, "projectile_count": 1, "pierce": 999, "max_level": 8,
		"description": "Rotating beam that freezes enemies"
	},
}

const PASSIVES := {
	"passive_01": {"stat": "max_hp", "bonus_per_level": 0.10, "max_level": 5, "description": "+10% max HP per level"},
	"passive_02": {"stat": "cooldown_reduction", "bonus_per_level": 0.08, "max_level": 5, "description": "-8% weapon cooldown per level"},
	"passive_03": {"stat": "projectile_speed", "bonus_per_level": 0.10, "max_level": 5, "description": "+10% projectile speed per level"},
	"passive_04": {"stat": "area", "bonus_per_level": 0.10, "max_level": 5, "description": "+10% AoE size per level"},
	"passive_05": {"stat": "hp_regen", "bonus_per_level": 0.3, "max_level": 5, "description": "+0.3 HP/s per level"},
	"passive_06": {"stat": "xp_radius", "bonus_per_level": 0.20, "max_level": 5, "description": "+20% XP pickup radius per level"},
	"passive_07": {"stat": "effect_duration", "bonus_per_level": 0.10, "max_level": 5, "description": "+10% weapon effect duration per level"},
	"passive_08": {"stat": "luck", "bonus_per_level": 0.10, "max_level": 5, "description": "+10% luck per level"},
	"passive_09": {"stat": "armor", "bonus_per_level": 1.0, "max_level": 5, "description": "+1 flat damage reduction per level"},
	"passive_10": {"stat": "damage_bonus", "bonus_per_level": 0.05, "max_level": 5, "description": "+5% global damage per level"},
}

const EVOLUTIONS := {
	"evo_01": {"requires_weapon": "weapon_01", "requires_passive": "passive_01", "replaces": "weapon_01",
		"bonus": "crit_lifesteal", "effect": "Deals critical hits, heals 5% of damage dealt"},
	"evo_02": {"requires_weapon": "weapon_02", "requires_passive": "passive_02", "replaces": "weapon_02",
		"bonus": "continuous_beam", "effect": "Fires continuous piercing beam, zero cooldown"},
	"evo_03": {"requires_weapon": "weapon_03", "requires_passive": "passive_03", "replaces": "weapon_03",
		"bonus": "mass_knockback", "effect": "Continuous barrage with massive knockback"},
	"evo_04": {"requires_weapon": "weapon_04", "requires_passive": "passive_04", "replaces": "weapon_04",
		"bonus": "ring_explosion", "effect": "Fires ring of projectiles outward in all directions"},
	"evo_05": {"requires_weapon": "weapon_05", "requires_passive": "passive_05", "replaces": "weapon_05",
		"bonus": "hp_steal_aura", "effect": "Massive aura steals enemy HP, heals player"},
	"evo_06": {"requires_weapon": "weapon_06", "requires_passive": "passive_06", "replaces": "weapon_06",
		"bonus": "homing_pools", "effect": "Pools slowly drift toward player, merge on overlap"},
	"evo_07": {"requires_weapon": "weapon_07", "requires_passive": "passive_07", "replaces": "weapon_07",
		"bonus": "permanent_orbit", "effect": "Orbitals never despawn, count increases to 8"},
	"evo_08": {"requires_weapon": "weapon_08", "requires_passive": "passive_08", "replaces": "weapon_08",
		"bonus": "double_strike", "effect": "Each strike hits same location twice, second hit 3x damage"},
	"evo_09": {"requires_weapon": "weapon_09", "requires_passive": "passive_09", "replaces": "weapon_09",
		"bonus": "bounce_explode", "effect": "Explodes on every bounce dealing AoE"},
	"evo_10": {"requires_weapon": "weapon_10", "requires_passive": ["passive_10", "passive_09"], "replaces": "weapon_10",
		"bonus": "infinite_freeze", "effect": "Freezes all on-screen enemies, halves HP each rotation"},
}

static func get_weapon(id: String) -> Dictionary:
	return WEAPONS[id]

static func get_passive(id: String) -> Dictionary:
	return PASSIVES[id]

static func get_evolution(id: String) -> Dictionary:
	return EVOLUTIONS[id]

static func calculate_damage(base_dmg: float, weapon_level: int, area_mult: float, luck: float) -> Dictionary:
	var level_mult := 1.0 + (weapon_level - 1) * 0.25
	var crit_chance := minf(0.50, 0.05 + luck * 0.01)
	var is_crit := randf() < crit_chance
	var crit_mult := 2.0 if is_crit else 1.0
	var damage := base_dmg * level_mult * area_mult * crit_mult
	return {"damage": damage, "is_crit": is_crit}
