extends CharacterBody2D

signal enemy_died(xp_value: int, position: Vector2)

var enemy_class := "fodder_01"
var max_hp := 10.0
var current_hp := 10.0
var move_speed := 40.0
var contact_damage := 5.0
var xp_value := 1
var knockback_immune := false
var is_active := false
var is_boss := false
var boss_id := ""

# Behavior
var behavior := "direct"
var target: Node2D  # Player reference

# Erratic behavior
var pause_timer := 0.0
var is_paused := false

# Orbit behavior (ranged_04)
var orbit_angle := 0.0
var orbit_radius := 400.0
var shoot_timer := 0.0

# Hazard (straight line)
var hazard_direction := Vector2.RIGHT
var hazard_lifetime := 0.0

# Boss drone deployer (boss_01)
var drone_timer := 0.0
var drone_interval := 4.0

# Boss AoE bombarder (boss_02)
var bombard_timer := 0.0
var bombard_interval := 3.0

# Game manager ref (for boss projectile spawning)
var game_manager_ref: Node

# Knockback
var knockback_velocity := Vector2.ZERO
var knockback_decay := 10.0

# Visual
@onready var visual: ColorRect = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Collision manager ref
var collision_manager: Node

# Boss HP bar ref (for bosses)
var boss_hp_callback: Callable

# Freeze status
var is_frozen := false
var freeze_timer := 0.0

func _ready() -> void:
	set_physics_process(false)

func activate(data: Dictionary, player_ref: Node2D, time_minutes: float, col_manager: Node, game_mgr: Node = null) -> void:
	enemy_class = data.get("class_id", "fodder_01")
	target = player_ref
	collision_manager = col_manager
	game_manager_ref = game_mgr

	var class_data := EnemyData.get_enemy_class(enemy_class)
	behavior = class_data["behavior"]
	knockback_immune = class_data["knockback_immune"]
	xp_value = class_data["xp_value"]

	# Calculate scaled stats
	max_hp = EnemyData.get_health(enemy_class, time_minutes)
	current_hp = max_hp
	move_speed = EnemyData.get_speed(enemy_class, time_minutes)
	contact_damage = EnemyData.get_contact_damage(enemy_class, time_minutes)

	# Set visual
	var size: Vector2 = class_data["size"]
	visual.size = size
	visual.position = -size / 2.0
	visual.color = class_data["color"]
	visual.visible = true

	# Set collision shape
	var shape := RectangleShape2D.new()
	shape.size = size
	collision_shape.shape = shape

	# Set position from data
	global_position = data.get("position", Vector2.ZERO)

	# Behavior setup
	match behavior:
		"erratic":
			pause_timer = randf_range(1.0, 4.0)
			is_paused = false
		"orbit":
			orbit_angle = randf() * TAU
			shoot_timer = 3.0
		"straight_line":
			hazard_direction = data.get("direction", Vector2.RIGHT)
			hazard_lifetime = 5.0

	knockback_velocity = Vector2.ZERO
	is_frozen = false
	freeze_timer = 0.0
	is_active = true
	is_boss = false
	visible = true
	set_physics_process(true)

func activate_boss(boss_data: Dictionary, player_ref: Node2D, time_minutes: float, col_manager: Node) -> void:
	target = player_ref
	collision_manager = col_manager
	is_boss = true
	boss_id = boss_data["boss_id"]

	var bdata = EnemyData.BOSSES[boss_id]
	behavior = bdata["behavior"]
	knockback_immune = true
	contact_damage = bdata["contact_damage"]
	move_speed = bdata["speed"]
	xp_value = 200

	max_hp = EnemyData.get_boss_hp(boss_id, time_minutes, boss_data.get("player_level", 1))
	current_hp = max_hp

	var size: Vector2 = bdata["size"]
	visual.size = size
	visual.position = -size / 2.0
	visual.color = bdata["color"]
	visual.visible = true

	var shape := RectangleShape2D.new()
	shape.size = size
	collision_shape.shape = shape

	global_position = boss_data.get("position", Vector2.ZERO)
	game_manager_ref = boss_data.get("game_manager", null)

	# Boss-specific setup
	drone_timer = 4.0
	bombard_timer = 3.0

	knockback_velocity = Vector2.ZERO
	is_frozen = false
	freeze_timer = 0.0
	is_active = true
	visible = true
	set_physics_process(true)

func deactivate() -> void:
	is_active = false
	visible = false
	set_physics_process(false)
	global_position = Vector2(-9999, -9999)

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Freeze handling
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0:
			is_frozen = false
			visual.modulate = Color.WHITE
		else:
			return

	# Register in spatial hash (all enemies register as "enemy" for weapon targeting)
	if collision_manager:
		collision_manager.register(self, "enemy")

	# Apply knockback
	if knockback_velocity.length_squared() > 1.0:
		global_position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, knockback_decay * delta)

	# Movement based on behavior
	match behavior:
		"direct":
			_move_direct(delta)
		"erratic":
			_move_erratic(delta)
		"orbit":
			_move_orbit(delta)
		"straight_line":
			_move_straight(delta)
		"drone_deployer":
			_move_direct(delta)
			_boss_drone_deployer(delta)
		"aoe_bombarder":
			_move_direct(delta)
			_boss_aoe_bombarder(delta)
		"death_wall":
			_move_direct(delta)

	# Check player collision
	if target and is_instance_valid(target):
		var dist := global_position.distance_to(target.global_position)
		var my_size: float = visual.size.x / 2.0
		if dist < my_size + 16.0:
			target.take_damage(contact_damage)

func _move_direct(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return
	var dir := (target.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

func _move_erratic(delta: float) -> void:
	if is_paused:
		pause_timer -= delta
		if pause_timer <= 0:
			is_paused = false
			pause_timer = randf_range(1.0, 4.0)
		return

	pause_timer -= delta
	if pause_timer <= 0:
		is_paused = true
		pause_timer = randf_range(0.5, 2.0)
		return

	_move_direct(delta)

func _move_orbit(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return

	# Move toward orbit radius
	var to_player := target.global_position - global_position
	var dist := to_player.length()

	if dist > orbit_radius + 50.0:
		velocity = to_player.normalized() * move_speed
	elif dist < orbit_radius - 50.0:
		velocity = -to_player.normalized() * move_speed
	else:
		# Orbit around player
		orbit_angle += move_speed / orbit_radius * get_physics_process_delta_time()
		var target_pos := target.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
		velocity = (target_pos - global_position).normalized() * move_speed

	move_and_slide()

	# Shooting
	shoot_timer -= delta
	if shoot_timer <= 0:
		shoot_timer = 3.0
		_fire_at_player()

func _fire_at_player() -> void:
	if not target or not is_instance_valid(target):
		return
	if game_manager_ref and game_manager_ref.has_method("spawn_enemy_projectile"):
		game_manager_ref.spawn_enemy_projectile(global_position, target.global_position, contact_damage)

func _move_straight(delta: float) -> void:
	velocity = hazard_direction * move_speed
	move_and_slide()
	hazard_lifetime -= delta
	if hazard_lifetime <= 0:
		enemy_died.emit(0, global_position)
		deactivate()

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, knockback_force: float = 0.0) -> void:
	current_hp -= amount
	# Flash white briefly
	visual.modulate = Color(2.0, 2.0, 2.0)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.1)

	# Show damage number
	if game_manager_ref and game_manager_ref.has_method("show_damage_number"):
		game_manager_ref.show_damage_number(global_position + Vector2(0, -20), amount)

	if knockback_force > 0 and not knockback_immune:
		knockback_velocity += knockback_dir * knockback_force

	if current_hp <= 0:
		enemy_died.emit(xp_value, global_position)
		deactivate()

	# Update boss HP bar
	if is_boss and boss_hp_callback.is_valid():
		boss_hp_callback.call(current_hp, max_hp)

func apply_freeze(duration: float) -> void:
	is_frozen = true
	freeze_timer = duration
	visual.modulate = Color(0.5, 0.8, 1.0)

func _boss_drone_deployer(delta: float) -> void:
	drone_timer -= delta
	if drone_timer <= 0:
		drone_timer = drone_interval
		# Spawn 3 fast mini-drones
		if game_manager_ref and game_manager_ref.has_method("spawn_boss_drones"):
			game_manager_ref.spawn_boss_drones(global_position, 3)

func _boss_aoe_bombarder(delta: float) -> void:
	bombard_timer -= delta
	if bombard_timer <= 0:
		bombard_timer = bombard_interval
		if not target or not is_instance_valid(target):
			return
		if game_manager_ref and game_manager_ref.has_method("spawn_boss_aoe"):
			game_manager_ref.spawn_boss_aoe(global_position, target.global_position)
