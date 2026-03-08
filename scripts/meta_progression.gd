extends Node
class_name MetaProgression

const SAVE_PATH = "user://save.json"

const META_UPGRADES = {
	"meta_01": {"stat": "armor", "bonus_per_level": 1, "max_level": 5, "base_cost": 200},
	"meta_02": {"stat": "cooldown_reduction", "bonus_per_level": 0.03, "max_level": 5, "base_cost": 300},
	"meta_03": {"stat": "area", "bonus_per_level": 0.05, "max_level": 5, "base_cost": 250},
	"meta_04": {"stat": "revive", "bonus_per_level": 1, "max_level": 1, "base_cost": 5000},
}

var total_gold = 0
var upgrade_levels = {}
var unlocked_stages = ["stage_01"]
var unlocked_characters = ["char_01", "char_02"]

func _ready() -> void:
	load_data()

func get_upgrade_cost(upgrade_id: String) -> int:
	var data = META_UPGRADES[upgrade_id]
	var current_level: int = upgrade_levels.get(upgrade_id, 0)
	return int(data["base_cost"] * (1.5 * (current_level + 1)))

func can_purchase(upgrade_id: String) -> bool:
	var data = META_UPGRADES[upgrade_id]
	var current_level: int = upgrade_levels.get(upgrade_id, 0)
	return current_level < data["max_level"] and total_gold >= get_upgrade_cost(upgrade_id)

func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_purchase(upgrade_id):
		return false
	var cost = get_upgrade_cost(upgrade_id)
	total_gold -= cost
	upgrade_levels[upgrade_id] = upgrade_levels.get(upgrade_id, 0) + 1
	save_data()
	return true

func get_applied_stats() -> Dictionary:
	var stats = {}
	for uid in META_UPGRADES:
		var level: int = upgrade_levels.get(uid, 0)
		if level > 0:
			var data = META_UPGRADES[uid]
			stats[data["stat"]] = data["bonus_per_level"] * level
	return stats

func save_data() -> void:
	var data = {
		"gold": total_gold,
		"upgrades": upgrade_levels,
		"stages": unlocked_stages,
		"characters": unlocked_characters,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	if result != OK:
		return
	var data: Dictionary = json.data
	total_gold = data.get("gold", 0)
	upgrade_levels = data.get("upgrades", {})
	unlocked_stages = data.get("stages", ["stage_01"])
	unlocked_characters = data.get("characters", ["char_01", "char_02"])

func add_gold(amount: int) -> void:
	total_gold += amount
	save_data()
