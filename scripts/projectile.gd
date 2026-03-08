extends Area2D

var is_active := false
var direction := Vector2.ZERO
var speed := 400.0
var damage := 10.0
var knockback := 10.0
var pierce := 1
var pierce_count := 0
var lifetime := 5.0
var lifetime_timer := 0.0
var weapon_id := ""
var is_enemy_projectile := false

# Bouncing
var is_bouncing := false
var bounce_rect := Rect2()

# Arcing
var is_arcing := false
var arc_start := Vector2.ZERO
var arc_target := Vector2.ZERO
var arc_height := 100.0
var arc_progress := 0.0
var arc_duration := 1.0

# Ground pool
var is_pool := false
var pool_duration := 3.0
var pool_timer := 0.0
var pool_damage_timer := 0.0
var pool_radius := 48.0

# Visual
var radius := 6.0
var color := Color(1.0, 1.0, 0.2)

# Collision manager
var collision_manager: Node

# Enemies already hit (for pierce tracking)
var hit_enemies := {}

func _ready() -> void:
	set_physics_process(false)

func _draw() -> void:
	if not is_active:
		return
	if is_pool:
		draw_circle(Vector2.ZERO, pool_radius, Color(1.0, 0.3, 0.0, 0.5))
	else:
		draw_circle(Vector2.ZERO, radius, color)

func activate(data: Dictionary) -> void:
	global_position = data.get("position", Vector2.ZERO)
	direction = data.get("direction", Vector2.RIGHT).normalized()
	speed = data.get("speed", 400.0)
	damage = data.get("damage", 10.0)
	knockback = data.get("knockback", 10.0)
	pierce = data.get("pierce", 1)
	lifetime = data.get("lifetime", 5.0)
	weapon_id = data.get("weapon_id", "")
	is_enemy_projectile = data.get("is_enemy", false)
	radius = data.get("radius", 6.0)
	color = data.get("color", Color(1.0, 1.0, 0.2))
	collision_manager = data.get("collision_manager", null)

	is_bouncing = data.get("bouncing", false)
	is_arcing = data.get("arcing", false)
	is_pool = data.get("is_pool", false)

	if is_arcing:
		arc_start = global_position
		arc_target = data.get("arc_target", Vector2.ZERO)
		arc_height = data.get("arc_height", 100.0)
		arc_progress = 0.0
		arc_duration = data.get("arc_duration", 1.0)

	if is_pool:
		pool_duration = data.get("pool_duration", 3.0)
		pool_timer = pool_duration
		pool_damage_timer = 0.0
		pool_radius = data.get("pool_radius", 48.0)
		speed = 0.0

	if is_bouncing:
		var vp_size := Vector2(1280, 720)
		var cam_pos := data.get("camera_position", Vector2.ZERO)
		bounce_rect = Rect2(cam_pos - vp_size, vp_size * 2.0)

	pierce_count = 0
	lifetime_timer = 0.0
	hit_enemies.clear()
	is_active = true
	visible = true
	set_physics_process(true)
	queue_redraw()

func deactivate() -> void:
	is_active = false
	visible = false
	set_physics_process(false)
	global_position = Vector2(-9999, -9999)
	hit_enemies.clear()
	is_bouncing = false
	is_arcing = false
	is_pool = false
	is_enemy_projectile = false

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	lifetime_timer += delta

	if is_pool:
		_process_pool(delta)
		return

	if is_arcing:
		_process_arc(delta)
		return

	# Normal movement
	global_position += direction * speed * delta

	# Bouncing
	if is_bouncing:
		_process_bounce()

	# Lifetime
	if lifetime_timer >= lifetime:
		deactivate()
		return

	# Register in spatial hash
	if collision_manager:
		collision_manager.register(self, "projectile")

	# Check collisions
	_check_collisions()

func _process_arc(delta: float) -> void:
	arc_progress += delta / arc_duration
	if arc_progress >= 1.0:
		# Land at target
		global_position = arc_target
		is_arcing = false
		# Convert to ground damage or just do impact
		_check_collisions()
		if pierce_count >= pierce:
			deactivate()
		return

	# Parabolic interpolation
	var t := arc_progress
	var pos := arc_start.lerp(arc_target, t)
	pos.y -= arc_height * sin(t * PI)
	global_position = pos

	if collision_manager:
		collision_manager.register(self, "projectile")
	_check_collisions()

func _process_pool(delta: float) -> void:
	pool_timer -= delta
	pool_damage_timer -= delta

	if pool_timer <= 0:
		deactivate()
		return

	if pool_damage_timer <= 0:
		pool_damage_timer = 0.5
		# Damage all enemies in radius
		if collision_manager:
			var enemies := collision_manager.query_radius(global_position, pool_radius, "enemy")
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					enemy.take_damage(damage, Vector2.ZERO, 0)

	queue_redraw()

func _process_bounce() -> void:
	# Update bounce rect based on current camera
	if global_position.x < bounce_rect.position.x or global_position.x > bounce_rect.end.x:
		direction.x = -direction.x
	if global_position.y < bounce_rect.position.y or global_position.y > bounce_rect.end.y:
		direction.y = -direction.y

func _check_collisions() -> void:
	if not collision_manager:
		return

	if is_enemy_projectile:
		# Check against player
		var players := collision_manager.query_radius(global_position, radius + 16.0, "player")
		for p in players:
			if is_instance_valid(p) and p.has_method("take_damage"):
				p.take_damage(damage)
				deactivate()
				return
	else:
		# Check against enemies
		var enemies := collision_manager.query_radius(global_position, radius + 20.0, "enemy")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			var eid := enemy.get_instance_id()
			if eid in hit_enemies:
				continue

			hit_enemies[eid] = true
			var kb_dir := (enemy.global_position - global_position).normalized()
			enemy.take_damage(damage, kb_dir, knockback)
			pierce_count += 1

			if pierce_count >= pierce:
				deactivate()
				return
