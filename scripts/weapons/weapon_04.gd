extends "res://scripts/weapons/weapon_base.gd"
# Arcing Lob Projectile

func _load_weapon_data() -> void:
	weapon_id = "weapon_04"
	super._load_weapon_data()

func fire() -> void:
	var count := get_projectile_count()

	for i in count:
		# Target nearest enemy or random position
		var target_pos: Vector2
		var nearest := collision_manager.query_nearest(player.global_position, "enemy", 600.0)
		if nearest:
			target_pos = nearest.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		else:
			var angle := randf() * TAU
			target_pos = player.global_position + Vector2(cos(angle), sin(angle)) * randf_range(100, 300)

		var dir := (target_pos - player.global_position).normalized()
		var dist := player.global_position.distance_to(target_pos)

		spawn_projectile({
			"position": player.global_position,
			"direction": dir,
			"speed": 200.0 * player.projectile_speed_mult,
			"lifetime": 5.0,
			"radius": 8.0 * get_area_mult(),
			"color": Color(1.0, 0.6, 0.1),
			"arcing": true,
			"arc_target": target_pos,
			"arc_height": 80.0 + dist * 0.3,
			"arc_duration": maxf(0.5, dist / (200.0 * player.projectile_speed_mult)),
		})
