extends Control

signal selection_made(item_id: String)

var option_buttons: Array[Button] = []
var current_options: Array[String] = []

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var options_container: VBoxContainer = $Panel/OptionsContainer

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_selection(player: CharacterBody2D) -> void:
	visible = true
	_clear_options()

	var num_options := 4 if player.current_level > 1 else 3
	var options := _generate_options(player, num_options)
	current_options = options

	title_label.text = "LEVEL UP! Choose an upgrade:"

	for i in options.size():
		var item_id: String = options[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(500, 60)
		btn.text = _get_item_description(item_id, player)
		btn.pressed.connect(_on_option_pressed.bind(i))
		options_container.add_child(btn)
		option_buttons.append(btn)

func _clear_options() -> void:
	for btn in option_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	option_buttons.clear()
	current_options.clear()

func _on_option_pressed(index: int) -> void:
	if index >= current_options.size():
		return
	var item_id := current_options[index]
	visible = false
	selection_made.emit(item_id)

func _generate_options(player: CharacterBody2D, count: int) -> Array[String]:
	var candidates: Array[Dictionary] = []

	# Add weapons the player doesn't have (and has room for)
	for weapon_id in WeaponData.WEAPONS:
		if weapon_id not in player.weapons:
			if player.weapons.size() < 6:
				var weight := 10.0 + player.luck * 2.0
				candidates.append({"id": weapon_id, "weight": weight})
		else:
			# Upgrade existing weapon
			var current_lvl: int = player.weapon_levels.get(weapon_id, 1)
			var max_lvl: int = WeaponData.WEAPONS[weapon_id]["max_level"]
			if current_lvl < max_lvl:
				candidates.append({"id": weapon_id, "weight": 20.0})

	# Add passives
	for passive_id in WeaponData.PASSIVES:
		if passive_id not in player.passives:
			if player.passives.size() < 6:
				var weight := 10.0 + player.luck * 2.0
				# Rare items
				if passive_id in ["passive_05", "passive_06"]:
					weight = 5.0 + player.luck * 3.0
				candidates.append({"id": passive_id, "weight": weight})
		else:
			var current_lvl: int = player.passive_levels.get(passive_id, 1)
			var max_lvl: int = WeaponData.PASSIVES[passive_id]["max_level"]
			if current_lvl < max_lvl:
				candidates.append({"id": passive_id, "weight": 20.0})

	# Weighted selection without replacement
	var selected: Array[String] = []
	for _i in count:
		if candidates.is_empty():
			break
		var total_weight := 0.0
		for c in candidates:
			total_weight += c["weight"]
		if total_weight <= 0:
			break

		var roll := randf() * total_weight
		var cumulative := 0.0
		for j in candidates.size():
			cumulative += candidates[j]["weight"]
			if roll <= cumulative:
				selected.append(candidates[j]["id"])
				candidates.remove_at(j)
				break

	return selected

func _get_item_description(item_id: String, player: CharacterBody2D) -> String:
	if item_id.begins_with("weapon_"):
		var data := WeaponData.WEAPONS[item_id]
		var lvl: int = player.weapon_levels.get(item_id, 0)
		if lvl > 0:
			return "[LV %d→%d] %s: %s" % [lvl, lvl + 1, item_id, data["description"]]
		else:
			return "[NEW] %s: %s" % [item_id, data["description"]]
	elif item_id.begins_with("passive_"):
		var data := WeaponData.PASSIVES[item_id]
		var lvl: int = player.passive_levels.get(item_id, 0)
		if lvl > 0:
			return "[LV %d→%d] %s: %s" % [lvl, lvl + 1, item_id, data["description"]]
		else:
			return "[NEW] %s: %s" % [item_id, data["description"]]
	return item_id
