extends Control

# Completely self-contained menu with NO external script dependencies.
# All data is inlined to avoid class_name resolution issues.

var selected_character = "char_02"
var selected_stage = "stage_01"
var meta_gold = 0
var meta_upgrade_levels = {}
var meta_unlocked_characters = ["char_01", "char_02"]
var meta_unlocked_stages = ["stage_01"]

const SAVE_PATH = "user://save.json"

const CHARACTER_INFO = {
	"char_01": {"name": "Tank", "hp": 120, "spd": 135, "weapon": "weapon_05"},
	"char_02": {"name": "Mage", "hp": 100, "spd": 150, "weapon": "weapon_02"},
	"char_03": {"name": "Rogue", "hp": 100, "spd": 172, "weapon": "weapon_01"},
	"char_04": {"name": "Scout", "hp": 80, "spd": 210, "weapon": "weapon_03"},
	"char_05": {"name": "Gambler", "hp": 100, "spd": 150, "weapon": "weapon_08"},
	"char_06": {"name": "Knight", "hp": 100, "spd": 105, "weapon": "weapon_07"},
}

const UPGRADE_INFO = {
	"meta_01": {"stat": "armor", "bonus": 1, "max_level": 5, "base_cost": 200},
	"meta_02": {"stat": "cooldown_reduction", "bonus": 0.03, "max_level": 5, "base_cost": 300},
	"meta_03": {"stat": "area", "bonus": 0.05, "max_level": 5, "base_cost": 250},
	"meta_04": {"stat": "revive", "bonus": 1, "max_level": 1, "base_cost": 5000},
}

func _ready() -> void:
	print("[MainMenu] _ready called")
	_load_save()
	_build_ui()
	print("[MainMenu] _ready complete")

func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[MainMenu] No save file found, using defaults")
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		return
	var data = json.data
	if data is Dictionary:
		meta_gold = data.get("gold", 0)
		meta_upgrade_levels = data.get("upgrades", {})
		meta_unlocked_stages = data.get("stages", ["stage_01"])
		meta_unlocked_characters = data.get("characters", ["char_01", "char_02"])
	print("[MainMenu] Save loaded, gold: ", meta_gold)

func _build_ui() -> void:
	# Title
	var title_label = $Panel/TitleLabel as Label
	title_label.text = "ICE SURVIVORS"

	# Gold
	var gold_label = $Panel/GoldLabel as Label
	gold_label.text = "Gold: %d" % meta_gold

	# Play button - connect FIRST
	var play_button = $Panel/PlayButton as Button
	play_button.text = "START RUN"
	play_button.pressed.connect(_on_play)
	print("[MainMenu] Play button connected")

	# Characters
	_build_characters()

	# Stages
	_build_stages()

	# Upgrades
	_build_upgrades()

func _build_characters() -> void:
	var container = $Panel/CharContainer as VBoxContainer
	# Clear existing children
	for c in container.get_children():
		c.queue_free()

	var header = Label.new()
	header.text = "SELECT CHARACTER"
	container.add_child(header)

	for char_id in CHARACTER_INFO:
		if not (char_id in meta_unlocked_characters):
			continue
		var info: Dictionary = CHARACTER_INFO[char_id]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 40)
		var prefix = "> " if char_id == selected_character else ""
		btn.text = "%s%s (HP:%d SPD:%d)" % [prefix, info["name"], info["hp"], info["spd"]]
		btn.pressed.connect(_select_character.bind(char_id))
		container.add_child(btn)
	print("[MainMenu] Characters built")

func _build_stages() -> void:
	var container = $Panel/StageContainer as VBoxContainer
	for c in container.get_children():
		c.queue_free()

	var header = Label.new()
	header.text = "SELECT STAGE"
	container.add_child(header)

	var stages = {"stage_01": "Urban Avenue", "stage_02": "Mall", "stage_03": "Wilderness"}
	for stage_id in stages:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 40)
		var locked: bool = not (stage_id in meta_unlocked_stages)
		var prefix = "> " if stage_id == selected_stage else ""
		if locked:
			btn.text = stages[stage_id] + " (LOCKED)"
			btn.disabled = true
		else:
			btn.text = prefix + stages[stage_id]
			btn.pressed.connect(_select_stage.bind(stage_id))
		container.add_child(btn)
	print("[MainMenu] Stages built")

func _build_upgrades() -> void:
	var container = $Panel/UpgradeContainer as VBoxContainer
	for c in container.get_children():
		c.queue_free()

	var header = Label.new()
	header.text = "UPGRADES"
	container.add_child(header)

	for uid in UPGRADE_INFO:
		var info: Dictionary = UPGRADE_INFO[uid]
		var level: int = meta_upgrade_levels.get(uid, 0)
		var max_lvl: int = info["max_level"]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(300, 40)

		if level >= max_lvl:
			btn.text = "%s LV %d/%d (MAX)" % [info["stat"], level, max_lvl]
			btn.disabled = true
		else:
			var cost: int = int(info["base_cost"] * (1.5 * (level + 1)))
			btn.text = "%s LV %d/%d - Cost: %d" % [info["stat"], level, max_lvl, cost]
			btn.disabled = meta_gold < cost
			btn.pressed.connect(_buy_upgrade.bind(uid))
		container.add_child(btn)
	print("[MainMenu] Upgrades built")

func _select_character(char_id: String) -> void:
	selected_character = char_id
	_build_characters()

func _select_stage(stage_id: String) -> void:
	selected_stage = stage_id
	_build_stages()

func _buy_upgrade(uid: String) -> void:
	var info: Dictionary = UPGRADE_INFO[uid]
	var level: int = meta_upgrade_levels.get(uid, 0)
	var cost: int = int(info["base_cost"] * (1.5 * (level + 1)))
	if meta_gold >= cost and level < info["max_level"]:
		meta_gold -= cost
		meta_upgrade_levels[uid] = level + 1
		_save_data()
		var gold_label = $Panel/GoldLabel as Label
		gold_label.text = "Gold: %d" % meta_gold
		_build_upgrades()

func _save_data() -> void:
	var data = {
		"gold": meta_gold,
		"upgrades": meta_upgrade_levels,
		"stages": meta_unlocked_stages,
		"characters": meta_unlocked_characters,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _get_applied_stats() -> Dictionary:
	var stats = {}
	for uid in UPGRADE_INFO:
		var level: int = meta_upgrade_levels.get(uid, 0)
		if level > 0:
			var info: Dictionary = UPGRADE_INFO[uid]
			stats[info["stat"]] = info["bonus"] * level
	return stats

func _on_play() -> void:
	print("[MainMenu] PLAY pressed! Character: ", selected_character, " Stage: ", selected_stage)
	GameConfig.character_id = selected_character
	GameConfig.stage_id = selected_stage
	GameConfig.meta_stats = _get_applied_stats()
	print("[MainMenu] Changing scene to main...")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
