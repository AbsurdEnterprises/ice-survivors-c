extends "res://scripts/weapons/weapon_base.gd"
# Directional Barrage

func _load_weapon_data() -> void:
	weapon_id = "weapon_03"
	super._load_weapon_data()

func fire() -> void:
	var count := get_projectile_count()
	var dir := player.facing
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var spread := 0.3  # radians spread per projectile
	var base_angle := dir.angle()

	for i in count:
		var offset := (i - (count - 1) / 2.0) * spread
		var angle := base_angle + offset + randf_range(-0.05, 0.05)
		var proj_dir := Vector2(cos(angle), sin(angle))

		spawn_projectile({
			"position": player.global_position,
			"direction": proj_dir,
			"speed": 350.0 * player.projectile_speed_mult,
			"lifetime": 2.0,
			"radius": 4.0,
			"color": Color(1.0, 0.8, 0.2),
		})
