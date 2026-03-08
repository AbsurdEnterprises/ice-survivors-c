extends Area2D

var is_active := false
var xp_value := 1
var player: CharacterBody2D
var is_mega := false

# Magnet
var is_magnetized := false
var magnet_speed := 300.0

# Float animation
var float_offset := 0.0
var base_position := Vector2.ZERO

func _ready() -> void:
	set_physics_process(false)

func _draw() -> void:
	if not is_active:
		return
	# Draw diamond shape
	var size := 6.0 if not is_mega else 12.0
	var col := Color(0.2, 1.0, 0.3) if not is_mega else Color(0.2, 1.0, 0.8)
	var points := PackedVector2Array([
		Vector2(0, -size),
		Vector2(size, 0),
		Vector2(0, size),
		Vector2(-size, 0)
	])
	draw_colored_polygon(points, col)

func activate(pos: Vector2, value: int, player_ref: CharacterBody2D) -> void:
	global_position = pos
	base_position = pos
	xp_value = value
	player = player_ref
	is_active = true
	is_mega = false
	is_magnetized = false
	float_offset = randf() * TAU
	visible = true
	set_physics_process(true)
	queue_redraw()

func deactivate() -> void:
	is_active = false
	visible = false
	set_physics_process(false)
	global_position = Vector2(-9999, -9999)

func _physics_process(delta: float) -> void:
	if not is_active or not player or not is_instance_valid(player):
		return

	# Float animation
	float_offset += delta * 3.0
	global_position.y = base_position.y + sin(float_offset) * 3.0

	# Magnet movement
	if is_magnetized:
		var dir := (player.global_position - global_position).normalized()
		global_position += dir * magnet_speed * delta
		base_position = global_position

	# Check pickup
	var dist := global_position.distance_to(player.global_position)
	var pickup_radius = player.xp_radius

	if dist < pickup_radius:
		if not is_magnetized:
			is_magnetized = true
			magnet_speed = 300.0

	if dist < 16.0:
		player.collect_xp(xp_value)
		deactivate()

func start_magnet() -> void:
	is_magnetized = true
	magnet_speed = 500.0
