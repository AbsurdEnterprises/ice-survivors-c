extends Node

const POOL_SIZE := 500

var pool: Array[CharacterBody2D] = []
var active_count := 0
var enemy_scene: PackedScene

func _ready() -> void:
	enemy_scene = preload("res://scenes/enemy.tscn")
	_initialize_pool()

func _initialize_pool() -> void:
	for i in POOL_SIZE:
		var enemy := enemy_scene.instantiate() as CharacterBody2D
		enemy.deactivate()
		add_child(enemy)
		pool.append(enemy)

func get_enemy() -> CharacterBody2D:
	for enemy in pool:
		if not enemy.is_active:
			active_count += 1
			return enemy

	# Pool exhausted - expand if under hard cap
	if pool.size() < 2000:
		var enemy := enemy_scene.instantiate() as CharacterBody2D
		enemy.deactivate()
		add_child(enemy)
		pool.append(enemy)
		active_count += 1
		return enemy

	return null

func return_enemy(enemy: CharacterBody2D) -> void:
	if enemy.is_active:
		enemy.deactivate()
		active_count -= 1

func get_active_enemies() -> Array:
	var result := []
	for enemy in pool:
		if enemy.is_active:
			result.append(enemy)
	return result

func get_active_count() -> int:
	# Recount for accuracy
	active_count = 0
	for enemy in pool:
		if enemy.is_active:
			active_count += 1
	return active_count
