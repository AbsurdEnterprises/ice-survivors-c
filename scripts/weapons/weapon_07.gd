extends "res://scripts/weapons/weapon_base.gd"
# Orbiting Projectiles

var orbit_projectiles := []
var orbit_angle := 0.0
var orbit_radius := 100.0
var orbit_speed := 3.0  # radians per second

func _load_weapon_data() -> void:
	weapon_id = "weapon_07"
	super._load_weapon_data()

func fire() -> void:
	# Orbiting weapons don't fire traditionally - they maintain orbiting projectiles
	pass

func update(delta: float) -> void:
	var count := get_projectile_count()
	orbit_radius = 100.0 * get_area_mult()
	orbit_angle += orbit_speed * delta

	# Ensure we have the right number of orbitals
	while orbit_projectiles.size() < count:
		var proj = projectile_pool.get_projectile()
		if proj:
			proj.activate({
				"position": player.global_position,
				"direction": Vector2.ZERO,
				"speed": 0.0,
				"lifetime": 999999.0,
				"radius": 8.0,
				"color": Color(0.6, 0.8, 1.0),
				"pierce": 999,
				"damage": get_damage(),
				"knockback": get_knockback(),
				"collision_manager": collision_manager,
				"weapon_id": weapon_id,
			})
			orbit_projectiles.append(proj)
		else:
			break

	# Clean up dead projectiles
	orbit_projectiles = orbit_projectiles.filter(func(p): return is_instance_valid(p) and p.is_active)

	# Update positions
	for i in orbit_projectiles.size():
		var angle := orbit_angle + (TAU / orbit_projectiles.size()) * i
		var pos := player.global_position + Vector2(cos(angle), sin(angle)) * orbit_radius
		orbit_projectiles[i].global_position = pos

		# Manual collision check for orbitals
		var enemies = collision_manager.query_radius(pos, 20.0, "enemy")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				var eid = enemy.get_instance_id()
				if eid not in orbit_projectiles[i].hit_enemies:
					orbit_projectiles[i].hit_enemies[eid] = true
					var kb_dir := (enemy.global_position - pos).normalized()
					enemy.take_damage(get_damage(), kb_dir, get_knockback())

	# Reset hit tracking periodically (every orbit)
	if fmod(orbit_angle, TAU) < orbit_speed * delta:
		for proj in orbit_projectiles:
			if is_instance_valid(proj):
				proj.hit_enemies.clear()
