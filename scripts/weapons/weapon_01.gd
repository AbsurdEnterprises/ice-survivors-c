extends "res://scripts/weapons/weapon_base.gd"
# Directional Melee Sweep

func _load_weapon_data() -> void:
	weapon_id = "weapon_01"
	super._load_weapon_data()

func fire() -> void:
	var sweep_range := 80.0 * get_area_mult()
	var sweep_width := 60.0 * get_area_mult()
	var dir := player.facing
	var center := player.global_position + dir * sweep_range * 0.5

	# Query enemies in sweep area
	var enemies := collision_manager.query_radius(center, sweep_range, "enemy")
	var dmg := get_damage()
	var kb := get_knockback()

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		# Check if enemy is in front of player (within sweep angle)
		var to_enemy := (enemy.global_position - player.global_position).normalized()
		var dot := dir.dot(to_enemy)
		if dot > 0.3:  # ~70 degree cone
			var kb_dir := to_enemy
			enemy.take_damage(dmg, kb_dir, kb)

	# Visual sweep effect - spawn a short-lived projectile for visual
	var proj := spawn_projectile({
		"position": center,
		"direction": dir,
		"speed": 0.0,
		"lifetime": 0.15,
		"radius": sweep_width * 0.5,
		"color": Color(0.8, 0.8, 1.0, 0.6),
		"pierce": 999,
		"damage": 0.0,  # Damage already applied above
	})
