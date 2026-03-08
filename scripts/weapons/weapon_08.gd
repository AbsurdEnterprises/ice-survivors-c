extends "res://scripts/weapons/weapon_base.gd"
# Random Strike (Lightning)

func _load_weapon_data() -> void:
	weapon_id = "weapon_08"
	super._load_weapon_data()

func fire() -> void:
	var count := get_projectile_count()
	var strike_radius := 48.0 * get_area_mult()

	for i in count:
		# Find a random enemy to strike
		var enemies = collision_manager.query_radius(player.global_position, 600.0, "enemy")
		if enemies.is_empty():
			return

		var target: Node2D = enemies[randi() % enemies.size()]
		if not is_instance_valid(target):
			continue

		var strike_pos := target.global_position
		var dmg := get_damage()
		var kb := get_knockback()

		# Deal AoE damage at strike location
		var hit_enemies = collision_manager.query_radius(strike_pos, strike_radius, "enemy")
		for enemy in hit_enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				var kb_dir := (enemy.global_position - strike_pos).normalized()
				enemy.take_damage(dmg, kb_dir, kb)

		# Visual: short-lived flash projectile
		spawn_projectile({
			"position": strike_pos,
			"direction": Vector2.ZERO,
			"speed": 0.0,
			"lifetime": 0.2,
			"radius": strike_radius,
			"color": Color(1.0, 1.0, 0.5, 0.8),
			"pierce": 999,
			"damage": 0.0,  # Damage already applied
		})
