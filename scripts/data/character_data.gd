extends Node
class_name CharacterData

const CHARACTERS = {
	"char_01": {
		"starting_weapon": "weapon_05",
		"stat_modifiers": {"max_hp": 1.20, "move_speed": 0.90, "damage": 1.0, "area": 1.0, "armor": 0, "luck": 0},
		"base_stats": {"max_hp": 120, "move_speed": 135, "xp_radius": 64}
	},
	"char_02": {
		"starting_weapon": "weapon_02",
		"stat_modifiers": {"max_hp": 1.0, "move_speed": 1.0, "damage": 0.90, "area": 1.30, "armor": 0, "luck": 0},
		"base_stats": {"max_hp": 100, "move_speed": 150, "xp_radius": 64}
	},
	"char_03": {
		"starting_weapon": "weapon_01",
		"stat_modifiers": {"max_hp": 1.0, "move_speed": 1.15, "damage": 1.0, "area": 1.0, "armor": -1, "luck": 0},
		"base_stats": {"max_hp": 100, "move_speed": 172, "xp_radius": 64}
	},
	"char_04": {
		"starting_weapon": "weapon_03",
		"stat_modifiers": {"max_hp": 0.80, "move_speed": 1.40, "damage": 1.0, "area": 1.0, "armor": 0, "luck": 0},
		"base_stats": {"max_hp": 80, "move_speed": 210, "xp_radius": 64}
	},
	"char_05": {
		"starting_weapon": "weapon_08",
		"stat_modifiers": {"max_hp": 1.0, "move_speed": 1.0, "damage": 1.0, "area": 1.0, "armor": 0, "luck": 0.20},
		"base_stats": {"max_hp": 100, "move_speed": 150, "xp_radius": 64}
	},
	"char_06": {
		"starting_weapon": "weapon_07",
		"stat_modifiers": {"max_hp": 1.0, "move_speed": 0.70, "damage": 1.0, "area": 1.0, "armor": 5, "luck": 0},
		"base_stats": {"max_hp": 100, "move_speed": 105, "xp_radius": 64}
	},
}

static func get_character(id: String) -> Dictionary:
	return CHARACTERS[id]
