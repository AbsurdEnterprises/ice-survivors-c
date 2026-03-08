extends Node

var player: CharacterBody2D
var projectile_pool: Node
var collision_manager: Node
var game_manager: Node

# Active weapon instances
var active_weapons = {}

# Weapon scripts
var weapon_scripts = {
	"weapon_01": preload("res://scripts/weapons/weapon_01.gd"),
	"weapon_02": preload("res://scripts/weapons/weapon_02.gd"),
	"weapon_03": preload("res://scripts/weapons/weapon_03.gd"),
	"weapon_04": preload("res://scripts/weapons/weapon_04.gd"),
	"weapon_05": preload("res://scripts/weapons/weapon_05.gd"),
	"weapon_06": preload("res://scripts/weapons/weapon_06.gd"),
	"weapon_07": preload("res://scripts/weapons/weapon_07.gd"),
	"weapon_08": preload("res://scripts/weapons/weapon_08.gd"),
	"weapon_09": preload("res://scripts/weapons/weapon_09.gd"),
	"weapon_10": preload("res://scripts/weapons/weapon_10.gd"),
}

func initialize(p: CharacterBody2D, proj_pool: Node, col_mgr: Node, game: Node) -> void:
	player = p
	projectile_pool = proj_pool
	collision_manager = col_mgr
	game_manager = game

	# Initialize starting weapon
	for weapon_id in player.weapons:
		_add_weapon_instance(weapon_id)

func _physics_process(delta: float) -> void:
	for weapon_id in active_weapons:
		var weapon = active_weapons[weapon_id]
		if weapon and is_instance_valid(weapon):
			weapon.update(delta)

func on_weapon_added(weapon_id: String) -> void:
	if weapon_id in active_weapons:
		# Level up existing weapon
		active_weapons[weapon_id].level = player.weapon_levels.get(weapon_id, 1)
		active_weapons[weapon_id].on_level_up()
	else:
		_add_weapon_instance(weapon_id)

func _add_weapon_instance(weapon_id: String) -> void:
	if weapon_id not in weapon_scripts:
		return

	var weapon_node = Node.new()
	weapon_node.set_script(weapon_scripts[weapon_id])
	weapon_node.name = weapon_id
	add_child(weapon_node)

	weapon_node.initialize(player, projectile_pool, collision_manager, game_manager)
	weapon_node.level = player.weapon_levels.get(weapon_id, 1)
	active_weapons[weapon_id] = weapon_node

func remove_weapon(weapon_id: String) -> void:
	if weapon_id in active_weapons:
		active_weapons[weapon_id].queue_free()
		active_weapons.erase(weapon_id)
