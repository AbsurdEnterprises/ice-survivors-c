extends "res://scripts/weapons/weapon_base.gd"
# Persistent Aura

var aura_radius = 80.0

func _load_weapon_data() -> void:
	weapon_id = "weapon_05"
	super._load_weapon_data()

func fire() -> void:
	aura_radius = 80.0 * get_area_mult()
	var dmg = get_damage()
	var kb = get_knockback()

	var enemies = collision_manager.query_radius(player.global_position, aura_radius, "enemy")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var kb_dir = (enemy.global_position - player.global_position).normalized()
		enemy.take_damage(dmg, kb_dir, kb)

func update(delta: float) -> void:
	# Aura is always active, fires on cooldown
	cooldown_timer -= delta
	if cooldown_timer <= 0:
		cooldown_timer = get_cooldown()
		fire()
	# Draw aura visual (handled by player _draw override or a visual child)
