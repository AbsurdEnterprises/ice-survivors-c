extends Camera2D

@export var follow_target: Node2D
@export var smooth_weight = 0.1

var is_locked = false
var lock_position = Vector2.ZERO

func _ready() -> void:
	make_current()

func _physics_process(_delta: float) -> void:
	if is_locked:
		global_position = global_position.lerp(lock_position, smooth_weight)
		return

	if follow_target:
		global_position = global_position.lerp(follow_target.global_position, smooth_weight)

func lock_to(pos: Vector2) -> void:
	is_locked = true
	lock_position = pos

func unlock() -> void:
	is_locked = false

func shake(intensity: float = 5.0, duration: float = 0.2) -> void:
	var tween = create_tween()
	var original_offset = offset
	for i in int(duration / 0.05):
		var shake_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "offset", shake_offset, 0.05)
	tween.tween_property(self, "offset", original_offset, 0.05)
