extends "res://scripts/weapons/weapon_base.gd"
# Rotating Freeze Beam

var beam_angle := 0.0
var beam_length := 300.0
var rotation_speed := 1.5  # radians per second
var freeze_duration := 2.0

func _load_weapon_data() -> void:
	weapon_id = "weapon_10"
	super._load_weapon_data()

func fire() -> void:
	# Freeze beam doesn't fire projectiles - it's a continuous rotating effect
	pass

func update(delta: float) -> void:
	beam_length = 300.0 * get_area_mult()
	beam_angle += rotation_speed * delta
	freeze_duration = 2.0 * player.effect_duration_mult

	# Check enemies along the beam line
	var beam_dir := Vector2(cos(beam_angle), sin(beam_angle))
	var beam_width := 20.0

	# Sample points along the beam
	var steps := int(beam_length / 32.0)
	for i in steps:
		var point := player.global_position + beam_dir * (32.0 * (i + 1))
		var enemies = collision_manager.query_radius(point, beam_width, "enemy")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.has_method("apply_freeze"):
				enemy.apply_freeze(freeze_duration)
