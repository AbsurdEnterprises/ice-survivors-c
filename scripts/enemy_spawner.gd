extends Node

const B_S := 8.0
const GROWTH_RATE := 0.12
const BASE_M_CAP := 500

var spawn_timer := 0.0
var spawn_interval := 1.0  # seconds between spawn cycles
var is_spawning := true
var m_cap := BASE_M_CAP

# Surge state
var surge_remaining := 0
var surge_timer := 0.0
var surge_interval := 0.25  # spawn surge enemies over 10 seconds

var player: CharacterBody2D
var enemy_pool: Node
var collision_manager: Node
var game_manager: Node

func _ready() -> void:
	# References set by game_manager
	pass

func initialize(p: CharacterBody2D, pool: Node, col_mgr: Node, game: Node) -> void:
	player = p
	enemy_pool = pool
	collision_manager = col_mgr
	game_manager = game

func _physics_process(delta: float) -> void:
	if not is_spawning:
		return

	var time_minutes := game_manager.get_elapsed_minutes()

	# Handle surges
	if surge_remaining > 0:
		surge_timer -= delta
		if surge_timer <= 0:
			surge_timer = surge_interval
			_spawn_enemy(time_minutes)
			surge_remaining -= 1

	# Normal spawning
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = spawn_interval
		var count := _calculate_spawn_count(time_minutes)
		var active := enemy_pool.get_active_count()
		var available := m_cap - active
		count = mini(count, available)
		for i in count:
			_spawn_enemy(time_minutes)

func _calculate_spawn_count(t: float) -> int:
	var n := B_S * pow(1.0 + GROWTH_RATE, t)
	return mini(int(floor(n)), m_cap)

func _spawn_enemy(time_minutes: float) -> void:
	if enemy_pool.get_active_count() >= m_cap:
		return

	var enemy := enemy_pool.get_enemy()
	if not enemy:
		return

	var enemy_class := EnemyData.pick_enemy_class(time_minutes)

	# Don't pool hazard_05 through normal path - they're one-shot
	if enemy_class == "hazard_05":
		_spawn_hazard(time_minutes)
		enemy_pool.return_enemy(enemy)
		return

	var spawn_pos := _get_spawn_position()
	var data := {
		"class_id": enemy_class,
		"position": spawn_pos,
	}

	enemy.activate(data, player, time_minutes, collision_manager)
	enemy.enemy_died.connect(game_manager.on_enemy_killed, CONNECT_ONE_SHOT)

func _spawn_hazard(time_minutes: float) -> void:
	var enemy := enemy_pool.get_enemy()
	if not enemy:
		return

	# Spawn from left or right edge
	var from_left := randf() > 0.5
	var y_pos := player.global_position.y + randf_range(-200, 200)
	var spawn_pos: Vector2
	var direction: Vector2

	if from_left:
		spawn_pos = Vector2(player.global_position.x - 800, y_pos)
		direction = Vector2.RIGHT
	else:
		spawn_pos = Vector2(player.global_position.x + 800, y_pos)
		direction = Vector2.LEFT

	var data := {
		"class_id": "hazard_05",
		"position": spawn_pos,
		"direction": direction,
	}
	enemy.activate(data, player, time_minutes, collision_manager)
	enemy.enemy_died.connect(game_manager.on_enemy_killed, CONNECT_ONE_SHOT)

func _get_spawn_position() -> Vector2:
	if not player:
		return Vector2.ZERO

	var viewport_size := Vector2(1280, 720)
	var hw := viewport_size.x / 2.0 + 64.0
	var hh := viewport_size.y / 2.0 + 64.0

	var angle := randf() * TAU
	var spawn_x := player.global_position.x + hw * cos(angle)
	var spawn_y := player.global_position.y + hh * sin(angle)
	return Vector2(spawn_x, spawn_y)

func trigger_surge(count: int) -> void:
	surge_remaining += count
	surge_timer = 0.0
	# spread over 10 seconds
	surge_interval = 10.0 / float(count)

func spawn_boss(boss_id: String) -> void:
	var enemy := enemy_pool.get_enemy()
	if not enemy:
		return

	var spawn_pos := _get_spawn_position()
	var time_minutes := game_manager.get_elapsed_minutes()

	var boss_data := {
		"boss_id": boss_id,
		"position": spawn_pos,
		"player_level": game_manager.player.current_level,
		"game_manager": game_manager,
	}

	enemy.activate_boss(boss_data, player, time_minutes, collision_manager)

	# Connect boss death to boss-specific handler
	enemy.enemy_died.connect(func(xp: int, pos: Vector2):
		game_manager.on_boss_killed(boss_id, pos)
	, CONNECT_ONE_SHOT)

	# Boss HP callback
	enemy.boss_hp_callback = Callable(game_manager.hud, "update_boss_hp")

	# Camera shake on boss spawn
	game_manager.camera.shake(8.0, 0.3)

func stop_spawning() -> void:
	is_spawning = false
