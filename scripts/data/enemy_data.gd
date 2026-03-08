extends Node
class_name EnemyData

const ENEMY_CLASSES := {
	"fodder_01": {
		"name": "Bureaucrat", "h_base": 10, "c_mod": 0.8, "v_base": 40.0,
		"behavior": "direct", "contact_damage": 5, "xp_value": 1,
		"size": Vector2(20, 20), "color": Color(1.0, 0.3, 0.3),
		"knockback_immune": false
	},
	"erratic_02": {
		"name": "Recruit", "h_base": 15, "c_mod": 1.0, "v_base": 55.0,
		"behavior": "erratic", "contact_damage": 8, "xp_value": 2,
		"size": Vector2(22, 22), "color": Color(1.0, 0.5, 0.2),
		"knockback_immune": false
	},
	"tank_03": {
		"name": "Tactical", "h_base": 40, "c_mod": 5.0, "v_base": 35.0,
		"behavior": "direct", "contact_damage": 15, "xp_value": 10,
		"size": Vector2(36, 36), "color": Color(0.6, 0.2, 0.8),
		"knockback_immune": true
	},
	"ranged_04": {
		"name": "Botnet", "h_base": 20, "c_mod": 1.2, "v_base": 25.0,
		"behavior": "orbit", "contact_damage": 12, "xp_value": 5,
		"size": Vector2(24, 24), "color": Color(0.8, 0.2, 0.4),
		"knockback_immune": false
	},
	"hazard_05": {
		"name": "Vehicle", "h_base": 999, "c_mod": 1.0, "v_base": 300.0,
		"behavior": "straight_line", "contact_damage": 50, "xp_value": 0,
		"size": Vector2(48, 24), "color": Color(1.0, 1.0, 0.0),
		"knockback_immune": true
	},
}

# Enemy class composition by time bracket (probabilities)
const COMPOSITION := [
	{"time_max": 3.0, "fodder_01": 1.0, "erratic_02": 0.0, "tank_03": 0.0, "ranged_04": 0.0, "hazard_05": 0.0},
	{"time_max": 7.0, "fodder_01": 0.60, "erratic_02": 0.35, "tank_03": 0.0, "ranged_04": 0.05, "hazard_05": 0.0},
	{"time_max": 12.0, "fodder_01": 0.40, "erratic_02": 0.30, "tank_03": 0.15, "ranged_04": 0.10, "hazard_05": 0.05},
	{"time_max": 20.0, "fodder_01": 0.25, "erratic_02": 0.25, "tank_03": 0.25, "ranged_04": 0.15, "hazard_05": 0.10},
	{"time_max": 30.0, "fodder_01": 0.15, "erratic_02": 0.20, "tank_03": 0.30, "ranged_04": 0.20, "hazard_05": 0.15},
]

const BOSSES := {
	"boss_01": {
		"spawn_time_minutes": 10, "speed": 60, "behavior": "drone_deployer",
		"contact_damage": 25, "drops": "treasure_chest",
		"size": Vector2(80, 80), "color": Color(0.5, 0.0, 0.5)
	},
	"boss_02": {
		"spawn_time_minutes": 20, "speed": 40, "behavior": "aoe_bombarder",
		"contact_damage": 30, "drops": "treasure_chest",
		"size": Vector2(96, 96), "color": Color(0.4, 0.0, 0.6)
	},
	"boss_final": {
		"spawn_time_minutes": 30, "speed": 999, "behavior": "death_wall",
		"contact_damage": 99999,
		"size": Vector2(128, 128), "color": Color(0.2, 0.0, 0.2)
	},
}

static func get_enemy_class(id: String) -> Dictionary:
	return ENEMY_CLASSES[id]

static func get_health(id: String, time_minutes: float) -> float:
	var data := ENEMY_CLASSES[id]
	return data["h_base"] * (1.0 + time_minutes * 0.15) * data["c_mod"]

static func get_speed(id: String, time_minutes: float) -> float:
	var data := ENEMY_CLASSES[id]
	var v_base: float = data["v_base"]
	return v_base + (time_minutes * 0.02 * v_base)

static func get_contact_damage(id: String, time_minutes: float) -> float:
	var data := ENEMY_CLASSES[id]
	return data["contact_damage"] * (1.0 + time_minutes * 0.08)

static func get_boss_hp(boss_id: String, time_minutes: float, player_level: int = 1) -> float:
	match boss_id:
		"boss_01":
			return 500.0 * (1.0 + time_minutes * 0.15) * 10.0
		"boss_02":
			return 500.0 * (1.0 + time_minutes * 0.15) * 20.0
		"boss_final":
			return player_level * 655350.0
	return 1000.0

static func pick_enemy_class(time_minutes: float) -> String:
	var comp := COMPOSITION[0]
	for c in COMPOSITION:
		if time_minutes < c["time_max"]:
			comp = c
			break
		comp = c

	var roll := randf()
	var cumulative := 0.0
	for key in ["fodder_01", "erratic_02", "tank_03", "ranged_04", "hazard_05"]:
		cumulative += comp[key]
		if roll <= cumulative:
			return key
	return "fodder_01"
