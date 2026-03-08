extends Area2D

signal chest_opened(player: CharacterBody2D)

var is_active = false
var player: CharacterBody2D

func _ready() -> void:
	set_physics_process(false)

func _draw() -> void:
	if not is_active:
		return
	# Draw chest as a gold rectangle with darker border
	draw_rect(Rect2(-16, -12, 32, 24), Color(0.8, 0.6, 0.1))
	draw_rect(Rect2(-14, -10, 28, 20), Color(1.0, 0.85, 0.2))
	draw_rect(Rect2(-4, -3, 8, 6), Color(0.9, 0.7, 0.1))

func activate(pos: Vector2, player_ref: CharacterBody2D) -> void:
	global_position = pos
	player = player_ref
	is_active = true
	visible = true
	set_physics_process(true)
	queue_redraw()

func deactivate() -> void:
	is_active = false
	visible = false
	set_physics_process(false)
	global_position = Vector2(-9999, -9999)

func _physics_process(_delta: float) -> void:
	if not is_active or not player or not is_instance_valid(player):
		return

	var dist = global_position.distance_to(player.global_position)
	if dist < 40.0:
		chest_opened.emit(player)
		deactivate()
