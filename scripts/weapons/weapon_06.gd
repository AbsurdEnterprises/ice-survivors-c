extends "res://scripts/weapons/weapon_base.gd"
# Random Ground Pools

func _load_weapon_data() -> void:
	weapon_id = "weapon_06"
	super._load_weapon_data()

func fire() -> void:
	var count := get_projectile_count()
	var pool_radius := 48.0 * get_area_mult()

	for i in count:
		var offset := Vector2(randf_range(-250, 250), randf_range(-250, 250))
		var target_pos := player.global_position + offset

		spawn_projectile({
			"position": target_pos,
			"direction": Vector2.ZERO,
			"speed": 0.0,
			"lifetime": 999.0,
			"radius": pool_radius,
			"color": Color(1.0, 0.3, 0.0, 0.5),
			"is_pool": true,
			"pool_duration": 3.0 * player.effect_duration_mult,
			"pool_radius": pool_radius,
			"damage": get_damage(),
			"knockback": get_knockback(),
			"pierce": 999,
		})
