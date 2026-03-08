extends "res://scripts/weapons/weapon_base.gd"
# Bouncing Projectile

func _load_weapon_data() -> void:
	weapon_id = "weapon_09"
	super._load_weapon_data()

func fire() -> void:
	var count := get_projectile_count()

	for i in count:
		var angle := randf() * TAU
		var dir := Vector2(cos(angle), sin(angle))
		var cam_pos := Vector2.ZERO
		if game_manager and game_manager.camera:
			cam_pos = game_manager.camera.global_position

		spawn_projectile({
			"position": player.global_position,
			"direction": dir,
			"speed": 300.0 * player.projectile_speed_mult,
			"lifetime": 30.0,  # Long lifetime for bouncing
			"radius": 6.0,
			"color": Color(0.5, 1.0, 0.5),
			"bouncing": true,
			"camera_position": cam_pos,
		})
