extends Node

const POOL_SIZE = 300
const MERGE_THRESHOLD = 200

var pool: Array[Area2D] = []
var active_gems = []
var gem_scene: PackedScene

var player: CharacterBody2D

func _ready() -> void:
	gem_scene = preload("res://scenes/xp_gem.tscn")
	_initialize_pool()

func _initialize_pool() -> void:
	for i in POOL_SIZE:
		var gem = gem_scene.instantiate() as Area2D
		gem.deactivate()
		add_child(gem)
		pool.append(gem)

func initialize(p: CharacterBody2D) -> void:
	player = p

func spawn_gem(pos: Vector2, xp_value: int) -> void:
	# Check if we need to merge
	_update_active_list()
	if active_gems.size() >= MERGE_THRESHOLD:
		_merge_gems()

	var gem = _get_gem()
	if not gem:
		return

	gem.activate(pos, xp_value, player)
	active_gems.append(gem)

func _get_gem() -> Area2D:
	for gem in pool:
		if not gem.is_active:
			return gem

	# Expand pool
	if pool.size() < 500:
		var gem = gem_scene.instantiate() as Area2D
		gem.deactivate()
		add_child(gem)
		pool.append(gem)
		return gem

	return null

func _update_active_list() -> void:
	active_gems = active_gems.filter(func(g): return is_instance_valid(g) and g.is_active)

func _merge_gems() -> void:
	_update_active_list()
	if active_gems.size() < MERGE_THRESHOLD:
		return

	# Calculate centroid and total XP
	var centroid = Vector2.ZERO
	var total_xp = 0
	for gem in active_gems:
		centroid += gem.global_position
		total_xp += gem.xp_value

	centroid /= active_gems.size()

	# Deactivate all
	for gem in active_gems:
		gem.deactivate()
	active_gems.clear()

	# Spawn one big gem
	var mega_gem = _get_gem()
	if mega_gem:
		mega_gem.activate(centroid, total_xp, player)
		mega_gem.is_mega = true
		active_gems.append(mega_gem)

func magnet_all() -> void:
	_update_active_list()
	for gem in active_gems:
		if is_instance_valid(gem) and gem.is_active:
			gem.start_magnet()
