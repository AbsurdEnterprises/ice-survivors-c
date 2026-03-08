extends Node

const POOL_SIZE := 1000

var pool: Array[Area2D] = []
var projectile_scene: PackedScene

func _ready() -> void:
	projectile_scene = preload("res://scenes/projectile.tscn")
	_initialize_pool()

func _initialize_pool() -> void:
	for i in POOL_SIZE:
		var proj := projectile_scene.instantiate() as Area2D
		proj.deactivate()
		add_child(proj)
		pool.append(proj)

func get_projectile() -> Area2D:
	for proj in pool:
		if not proj.is_active:
			return proj

	# Expand pool
	if pool.size() < 2000:
		var proj := projectile_scene.instantiate() as Area2D
		proj.deactivate()
		add_child(proj)
		pool.append(proj)
		return proj

	return null

func return_projectile(proj: Area2D) -> void:
	proj.deactivate()
