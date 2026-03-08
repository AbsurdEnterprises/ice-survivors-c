extends Node2D

# Simple pooled floating damage numbers using Labels (V1 approach)
# V2 would use sprite-batched digit atlas

const POOL_SIZE := 50
var pool: Array[Label] = []

func _ready() -> void:
	for i in POOL_SIZE:
		var label := Label.new()
		label.visible = false
		label.z_index = 100
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		pool.append(label)

func show_damage(pos: Vector2, amount: float, is_crit: bool = false) -> void:
	var label := _get_label()
	if not label:
		return

	label.text = str(int(amount))
	label.global_position = pos + Vector2(randf_range(-10, 10), -20)
	label.visible = true
	label.modulate = Color(1, 0, 0) if not is_crit else Color(1, 1, 0)
	label.scale = Vector2.ONE * (1.0 if not is_crit else 1.5)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 40.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(func(): label.visible = false; label.modulate.a = 1.0)

func _get_label() -> Label:
	for label in pool:
		if not label.visible:
			return label
	return null
