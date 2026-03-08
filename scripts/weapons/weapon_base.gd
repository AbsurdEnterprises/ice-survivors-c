extends Node

var player: CharacterBody2D
var projectile_pool: Node
var collision_manager: Node
var game_manager: Node

var weapon_id := ""
var level := 1
var cooldown_timer := 0.0
var base_cooldown := 1.0
var base_damage := 10.0
var base_knockback := 10.0
var base_area := 1.0
var base_pierce := 1
var base_projectile_count := 1

func initialize(p: CharacterBody2D, proj_pool: Node, col_mgr: Node, game: Node) -> void:
	player = p
	projectile_pool = proj_pool
	collision_manager = col_mgr
	game_manager = game
	_load_weapon_data()

func _load_weapon_data() -> void:
	if weapon_id == "":
		return
	var data := WeaponData.get_weapon(weapon_id)
	base_damage = data["base_dmg"]
	base_cooldown = data["cooldown"]
	base_knockback = data["knockback"]
	base_area = data["area"]
	base_pierce = data["pierce"]
	base_projectile_count = data["projectile_count"]

func get_cooldown() -> float:
	return base_cooldown * (1.0 - player.cooldown_reduction)

func get_damage() -> float:
	var level_mult := 1.0 + (level - 1) * 0.25
	return base_damage * level_mult * player.damage_mult * (1.0 + player.damage_bonus)

func get_area_mult() -> float:
	return base_area * player.area_mult

func get_knockback() -> float:
	return base_knockback

func get_pierce() -> int:
	return base_pierce

func get_projectile_count() -> int:
	return base_projectile_count + int(floor((level - 1) / 2.0))

func update(delta: float) -> void:
	cooldown_timer -= delta
	if cooldown_timer <= 0:
		cooldown_timer = get_cooldown()
		fire()

func fire() -> void:
	pass  # Override in subclasses

func on_level_up() -> void:
	pass  # Override for special level-up behavior

func spawn_projectile(data: Dictionary) -> Area2D:
	var proj = projectile_pool.get_projectile()
	if not proj:
		return null
	data["collision_manager"] = collision_manager
	data["damage"] = data.get("damage", get_damage())
	data["knockback"] = data.get("knockback", get_knockback())
	data["pierce"] = data.get("pierce", get_pierce())
	data["weapon_id"] = weapon_id
	proj.activate(data)
	return proj
