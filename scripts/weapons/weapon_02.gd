extends "res://scripts/weapons/weapon_base.gd"
# Auto-target nearest enemy projectile

func _load_weapon_data() -> void:
	weapon_id = "weapon_02"
	super._load_weapon_data()

func fire() -> void:
	var count = get_projectile_count()
	var targets_hit = {}

	for i in count:
		var nearest = collision_manager.query_nearest(player.global_position, "enemy")
		if not nearest:
			return

		# Skip already targeted enemies this volley
		var attempts = 0
		while nearest and nearest.get_instance_id() in targets_hit and attempts < 10:
			# Find another target
			var enemies = collision_manager.query_radius(player.global_position, 800.0, "enemy")
			nearest = null
			for e in enemies:
				if e.get_instance_id() not in targets_hit:
					nearest = e
					break
			attempts += 1

		if not nearest:
			return

		targets_hit[nearest.get_instance_id()] = true
		var dir = (nearest.global_position - player.global_position).normalized()

		spawn_projectile({
			"position": player.global_position,
			"direction": dir,
			"speed": 500.0 * player.projectile_speed_mult,
			"lifetime": 3.0,
			"radius": 5.0,
			"color": Color(1.0, 1.0, 0.2),
		})
