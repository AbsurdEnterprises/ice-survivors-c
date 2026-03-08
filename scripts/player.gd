extends CharacterBody2D

signal player_damaged(current_hp: float, max_hp: float)
signal player_died()
signal player_healed(current_hp: float, max_hp: float)
signal xp_collected(current_xp: int, xp_needed: int, level: int)
signal level_up(new_level: int)

# Character data
var character_id = "char_02"
var stat_modifiers = {}

# Base stats (after character modifiers)
var max_hp = 100.0
var current_hp = 100.0
var move_speed = 150.0
var xp_radius = 64.0
var armor = 0.0
var luck = 0.0
var damage_mult = 1.0
var area_mult = 1.0
var cooldown_reduction = 0.0
var projectile_speed_mult = 1.0
var hp_regen = 0.0
var effect_duration_mult = 1.0
var damage_bonus = 0.0

# XP and leveling
var current_xp = 0
var current_level = 1

# Inventory
var weapons: Array[String] = []
var weapon_levels = {}
var passives: Array[String] = []
var passive_levels = {}

# I-frames
var is_invulnerable = false
var invulnerable_timer = 0.0
const INVULNERABLE_DURATION = 0.5
var blink_timer = 0.0

# Facing direction (for directional weapons)
var facing = Vector2.RIGHT

# Gold
var gold = 0

# Meta revive
var has_revive = false
var revive_used = false

# Node references
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var xp_pickup_area: Area2D = $XPPickupArea
@onready var xp_pickup_shape: CollisionShape2D = $XPPickupArea/CollisionShape2D
@onready var visual: ColorRect = $Visual

func _ready() -> void:
	_apply_character_data()

func initialize(char_id: String, meta_upgrades: Dictionary = {}) -> void:
	character_id = char_id
	_apply_character_data()
	_apply_meta_upgrades(meta_upgrades)
	current_hp = max_hp

func _apply_character_data() -> void:
	var data = CharacterData.get_character(character_id)
	var base: Dictionary = data["base_stats"]
	stat_modifiers = data["stat_modifiers"]

	max_hp = base["max_hp"] * stat_modifiers.get("max_hp", 1.0)
	move_speed = base["move_speed"] * stat_modifiers.get("move_speed", 1.0)
	xp_radius = base["xp_radius"]
	armor = stat_modifiers.get("armor", 0)
	luck = stat_modifiers.get("luck", 0)
	damage_mult = stat_modifiers.get("damage", 1.0)
	area_mult = stat_modifiers.get("area", 1.0)

	current_hp = max_hp

	# Add starting weapon
	var starting_weapon: String = data["starting_weapon"]
	if starting_weapon not in weapons:
		weapons.append(starting_weapon)
		weapon_levels[starting_weapon] = 1

	# Update XP pickup radius
	_update_xp_radius()

func _apply_meta_upgrades(meta: Dictionary) -> void:
	armor += meta.get("armor", 0.0)
	cooldown_reduction += meta.get("cooldown_reduction", 0.0)
	area_mult += meta.get("area", 0.0)
	has_revive = meta.get("revive", 0) > 0

func _update_xp_radius() -> void:
	if xp_pickup_shape:
		var shape = CircleShape2D.new()
		shape.radius = xp_radius
		xp_pickup_shape.shape = shape

func _draw() -> void:
	# Draw aura ring if weapon_05 is active
	if "weapon_05" in weapons:
		var aura_radius = 80.0 * area_mult
		draw_arc(Vector2.ZERO, aura_radius, 0, TAU, 32, Color(0.3, 0.5, 1.0, 0.3), 2.0)

	# Draw freeze beam if weapon_10 is active
	if "weapon_10" in weapons:
		# The beam visual is handled by the weapon update
		pass

func _physics_process(delta: float) -> void:
	_handle_movement()
	_handle_invulnerability(delta)
	_handle_regen(delta)
	queue_redraw()

func _handle_movement() -> void:
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		facing = input_dir

	velocity = input_dir * move_speed
	move_and_slide()

func _handle_invulnerability(delta: float) -> void:
	if not is_invulnerable:
		return

	invulnerable_timer -= delta
	blink_timer -= delta

	if blink_timer <= 0.0:
		visual.visible = not visual.visible
		blink_timer = 0.05

	if invulnerable_timer <= 0.0:
		is_invulnerable = false
		visual.visible = true

func _handle_regen(delta: float) -> void:
	if hp_regen > 0.0 and current_hp < max_hp:
		current_hp = minf(current_hp + hp_regen * delta, max_hp)
		player_healed.emit(current_hp, max_hp)

func take_damage(amount: float) -> void:
	if is_invulnerable:
		return

	var actual_damage = maxf(1.0, amount - armor)
	current_hp -= actual_damage
	player_damaged.emit(current_hp, max_hp)

	if current_hp <= 0:
		if has_revive and not revive_used:
			_revive()
		else:
			player_died.emit()
		return

	# Start i-frames
	is_invulnerable = true
	invulnerable_timer = INVULNERABLE_DURATION
	blink_timer = 0.05

func _revive() -> void:
	revive_used = true
	current_hp = max_hp * 0.5
	is_invulnerable = true
	invulnerable_timer = 3.0
	blink_timer = 0.05
	player_healed.emit(current_hp, max_hp)

func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	player_healed.emit(current_hp, max_hp)

func collect_xp(amount: int) -> void:
	current_xp += amount
	var xp_needed = _xp_for_next_level()
	while current_xp >= xp_needed:
		current_xp -= xp_needed
		current_level += 1
		level_up.emit(current_level)
		xp_needed = _xp_for_next_level()
	xp_collected.emit(current_xp, xp_needed, current_level)

func _xp_for_next_level() -> int:
	return int(floor(10.0 * pow(current_level, 1.5) + 50.0))

func get_xp_needed() -> int:
	return _xp_for_next_level()

# Inventory management
func add_weapon(weapon_id: String) -> void:
	if weapon_id in weapons:
		weapon_levels[weapon_id] = mini(weapon_levels[weapon_id] + 1, WeaponData.WEAPONS[weapon_id]["max_level"])
	elif weapons.size() < 6:
		weapons.append(weapon_id)
		weapon_levels[weapon_id] = 1

func add_passive(passive_id: String) -> void:
	if passive_id in passives:
		passive_levels[passive_id] = mini(passive_levels[passive_id] + 1, WeaponData.PASSIVES[passive_id]["max_level"])
	else:
		if passives.size() < 6:
			passives.append(passive_id)
			passive_levels[passive_id] = 1
	_recalculate_passive_stats()

func _recalculate_passive_stats() -> void:
	# Reset to base
	var data = CharacterData.get_character(character_id)
	var base: Dictionary = data["base_stats"]
	var mods: Dictionary = data["stat_modifiers"]

	var base_max_hp: float = base["max_hp"] * mods.get("max_hp", 1.0)
	cooldown_reduction = 0.0
	projectile_speed_mult = 1.0
	var passive_area = 0.0
	hp_regen = 0.0
	var xp_radius_mult = 1.0
	effect_duration_mult = 1.0
	var luck_bonus = 0.0
	var armor_bonus = 0.0
	damage_bonus = 0.0

	for pid in passives:
		var plevel: int = passive_levels.get(pid, 0)
		var pdata = WeaponData.PASSIVES[pid]
		var total_bonus: float = pdata["bonus_per_level"] * plevel
		match pdata["stat"]:
			"max_hp":
				base_max_hp *= (1.0 + total_bonus)
			"cooldown_reduction":
				cooldown_reduction += total_bonus
			"projectile_speed":
				projectile_speed_mult += total_bonus
			"area":
				passive_area += total_bonus
			"hp_regen":
				hp_regen += total_bonus
			"xp_radius":
				xp_radius_mult += total_bonus
			"effect_duration":
				effect_duration_mult += total_bonus
			"luck":
				luck_bonus += total_bonus
			"armor":
				armor_bonus += total_bonus
			"damage_bonus":
				damage_bonus += total_bonus

	max_hp = base_max_hp
	area_mult = mods.get("area", 1.0) + passive_area
	luck = mods.get("luck", 0) + luck_bonus
	armor = mods.get("armor", 0) + armor_bonus
	xp_radius = base["xp_radius"] * xp_radius_mult
	_update_xp_radius()

	# Keep HP ratio when max HP changes
	if current_hp > max_hp:
		current_hp = max_hp

func evolve_weapon(evo_id: String) -> void:
	var evo = WeaponData.EVOLUTIONS[evo_id]
	var old_weapon: String = evo["replaces"]
	var idx = weapons.find(old_weapon)
	if idx >= 0:
		weapons[idx] = evo_id
		weapon_levels.erase(old_weapon)
		weapon_levels[evo_id] = 1
