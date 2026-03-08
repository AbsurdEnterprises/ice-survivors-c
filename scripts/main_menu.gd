extends Control

var meta: MetaProgression
var selected_character := "char_02"
var selected_stage := "stage_01"

@onready var title_label: Label = $Panel/TitleLabel
@onready var char_container: VBoxContainer = $Panel/CharContainer
@onready var stage_container: VBoxContainer = $Panel/StageContainer
@onready var upgrade_container: VBoxContainer = $Panel/UpgradeContainer
@onready var gold_label: Label = $Panel/GoldLabel
@onready var play_button: Button = $Panel/PlayButton

func _ready() -> void:
	meta = MetaProgression.new()
	meta.load_data()
	_build_ui()

func _build_ui() -> void:
	title_label.text = "ICE SURVIVORS"
	gold_label.text = "Gold: %d" % meta.total_gold

	_build_character_select()
	_build_stage_select()
	_build_upgrade_shop()

	play_button.text = "START RUN"
	play_button.pressed.connect(_on_play)

func _build_character_select() -> void:
	# Clear existing
	for child in char_container.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "SELECT CHARACTER"
	char_container.add_child(header)

	for char_id in CharacterData.CHARACTERS:
		if char_id not in meta.unlocked_characters:
			continue
		var data := CharacterData.get_character(char_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 40)
		var base: Dictionary = data["base_stats"]
		btn.text = "%s (HP:%d SPD:%d)" % [char_id, base["max_hp"], base["move_speed"]]
		btn.pressed.connect(_on_char_selected.bind(char_id))
		if char_id == selected_character:
			btn.text = "> " + btn.text
		char_container.add_child(btn)

func _build_stage_select() -> void:
	for child in stage_container.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "SELECT STAGE"
	stage_container.add_child(header)

	var stages := {
		"stage_01": "Urban Avenue",
		"stage_02": "Mall",
		"stage_03": "Wilderness",
	}

	for stage_id in stages:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 40)
		if stage_id in meta.unlocked_stages:
			btn.text = stages[stage_id]
			btn.pressed.connect(_on_stage_selected.bind(stage_id))
		else:
			btn.text = stages[stage_id] + " (LOCKED)"
			btn.disabled = true
		if stage_id == selected_stage:
			btn.text = "> " + btn.text
		stage_container.add_child(btn)

func _build_upgrade_shop() -> void:
	for child in upgrade_container.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "UPGRADES"
	upgrade_container.add_child(header)

	for uid in MetaProgression.META_UPGRADES:
		var data := MetaProgression.META_UPGRADES[uid]
		var level: int = meta.upgrade_levels.get(uid, 0)
		var max_level: int = data["max_level"]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(300, 40)

		if level >= max_level:
			btn.text = "%s LV %d/%d (MAX)" % [data["stat"], level, max_level]
			btn.disabled = true
		else:
			var cost := meta.get_upgrade_cost(uid)
			btn.text = "%s LV %d/%d - Cost: %d gold" % [data["stat"], level, max_level, cost]
			btn.disabled = not meta.can_purchase(uid)
			btn.pressed.connect(_on_upgrade_purchased.bind(uid))

		upgrade_container.add_child(btn)

func _on_char_selected(char_id: String) -> void:
	selected_character = char_id
	_build_character_select()

func _on_stage_selected(stage_id: String) -> void:
	selected_stage = stage_id
	_build_stage_select()

func _on_upgrade_purchased(uid: String) -> void:
	if meta.purchase_upgrade(uid):
		gold_label.text = "Gold: %d" % meta.total_gold
		_build_upgrade_shop()

func _on_play() -> void:
	# Store selected character and stage for the game scene to read
	var game_config := {
		"character": selected_character,
		"stage": selected_stage,
		"meta_upgrades": meta.get_applied_stats(),
	}
	# Use a global autoload or pass via scene change
	GameConfig.character_id = selected_character
	GameConfig.stage_id = selected_stage
	GameConfig.meta_stats = meta.get_applied_stats()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
