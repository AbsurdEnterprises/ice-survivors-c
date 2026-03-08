extends Node2D

enum GameState { MENU, PLAYING, PAUSED, LEVEL_UP, GAME_OVER, VICTORY }

signal state_changed(new_state: GameState)
signal time_updated(elapsed_minutes: float)

var current_state = GameState.MENU
var elapsed_time = 0.0  # seconds
var kill_count = 0
var gold_earned = 0

# Node references
var player: CharacterBody2D
var camera: Camera2D
var enemy_spawner: Node
var weapon_system: Node
var hud: CanvasLayer
var level_up_screen: Control
var collision_manager: Node

# Pools
var enemy_pool: Node
var projectile_pool: Node
var xp_pool: Node

# Treasure chests
var chest_scene: PackedScene
var active_chests = []

# Damage numbers
var damage_numbers: Node2D

# Background tiles
var bg_tiles: Node2D
var tile_size = 256
var tiles_x = 12
var tiles_y = 8
var active_tiles = {}

# Destructible spawning
var destructible_scene: PackedScene
var destructible_spawn_distance = 512.0  # spawn density: 1 per 512x512 area
var spawned_destructible_cells = {}

# Boss tracking
var boss_01_spawned = false
var boss_02_spawned = false
var boss_final_spawned = false

# Surge tracking
const SURGE_TIMES = [5.0, 10.0, 15.0, 20.0, 25.0]
const SURGE_COUNTS = [40, 80, 120, 160, 200]
var surges_triggered = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	chest_scene = preload("res://scenes/treasure_chest.tscn")
	destructible_scene = preload("res://scenes/destructible.tscn")
	_setup_references()
	_start_game()

func _setup_references() -> void:
	player = $Player
	camera = $Camera
	camera.follow_target = player
	enemy_spawner = $EnemySpawner
	weapon_system = $WeaponSystem
	hud = $HUD
	level_up_screen = $LevelUpScreen
	collision_manager = $CollisionManager
	enemy_pool = $EnemyPool
	projectile_pool = $ProjectilePool
	xp_pool = $XPPool
	bg_tiles = $Background

	# Damage numbers
	damage_numbers = $DamageNumbers

	# Connect player signals
	player.player_damaged.connect(_on_player_damaged)
	player.player_died.connect(_on_player_died)
	player.player_healed.connect(_on_player_healed)
	player.xp_collected.connect(_on_xp_collected)
	player.level_up.connect(_on_player_level_up)

	# Connect level-up screen
	level_up_screen.selection_made.connect(on_level_up_selection_made)

	# Initialize subsystems
	enemy_spawner.initialize(player, enemy_pool, collision_manager, self)
	weapon_system.initialize(player, projectile_pool, collision_manager, self)
	xp_pool.initialize(player)

func _start_game() -> void:
	var char_id = GameConfig.character_id
	var meta_stats = GameConfig.meta_stats
	player.initialize(char_id, meta_stats)
	elapsed_time = 0.0
	kill_count = 0
	gold_earned = 0
	boss_01_spawned = false
	boss_02_spawned = false
	boss_final_spawned = false
	surges_triggered.clear()

	# Initialize HUD
	hud.update_hp(player.current_hp, player.max_hp)
	hud.update_xp(0, player.get_xp_needed(), 1)
	hud.update_timer(0.0)
	hud.update_kills(0)

	_change_state(GameState.PLAYING)

func _physics_process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return

	elapsed_time += delta
	var elapsed_minutes = elapsed_time / 60.0
	time_updated.emit(elapsed_minutes)

	# Register player in spatial hash
	collision_manager.register(player, "player")

	# Update background tiles
	_update_background()

	# Update HUD
	hud.update_timer(elapsed_time)
	hud.update_kills(kill_count)

	# Spawn destructibles near player
	_spawn_destructibles_around_player()

	# Check boss spawns
	_check_boss_spawns(elapsed_minutes)

	# Check surges
	_check_surges(elapsed_minutes)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and current_state == GameState.GAME_OVER:
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif event.keycode == KEY_M and current_state == GameState.GAME_OVER:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		elif event.keycode == KEY_ESCAPE:
			if current_state == GameState.PLAYING:
				_change_state(GameState.PAUSED)
			elif current_state == GameState.PAUSED:
				_change_state(GameState.PLAYING)

func _update_background() -> void:
	var cam_pos = camera.global_position
	var center_tile_x = int(floor(cam_pos.x / tile_size))
	var center_tile_y = int(floor(cam_pos.y / tile_size))

	var needed_tiles = {}
	for x in range(center_tile_x - tiles_x / 2, center_tile_x + tiles_x / 2 + 1):
		for y in range(center_tile_y - tiles_y / 2, center_tile_y + tiles_y / 2 + 1):
			var key = Vector2i(x, y)
			needed_tiles[key] = true
			if key not in active_tiles:
				_create_tile(key)

	# Remove out-of-range tiles
	var to_remove: Array[Vector2i] = []
	for key in active_tiles:
		if key not in needed_tiles:
			to_remove.append(key)
	for key in to_remove:
		active_tiles[key].queue_free()
		active_tiles.erase(key)

func _create_tile(key: Vector2i) -> void:
	var rect = ColorRect.new()
	if (key.x + key.y) % 2 == 0:
		rect.color = Color(0.85, 0.85, 0.85)
	else:
		rect.color = Color(0.80, 0.80, 0.80)
	rect.size = Vector2(tile_size, tile_size)
	rect.position = Vector2(key.x * tile_size, key.y * tile_size)
	bg_tiles.add_child(rect)
	active_tiles[key] = rect

func _spawn_destructibles_around_player() -> void:
	var cell_size = 512
	var px = int(floor(player.global_position.x / cell_size))
	var py = int(floor(player.global_position.y / cell_size))

	for x in range(px - 3, px + 4):
		for y in range(py - 3, py + 4):
			var key = Vector2i(x, y)
			if key in spawned_destructible_cells:
				continue
			spawned_destructible_cells[key] = true

			# Use deterministic seed for consistent placement
			var rng = RandomNumberGenerator.new()
			rng.seed = hash(key)
			if rng.randf() > 0.6:  # 60% chance to spawn a destructible per cell
				continue

			var dtype = "destructible_01" if rng.randf() < 0.6 else "destructible_02"
			var pos = Vector2(
				x * cell_size + rng.randf_range(64, cell_size - 64),
				y * cell_size + rng.randf_range(64, cell_size - 64)
			)

			var destr = destructible_scene.instantiate()
			add_child(destr)
			destr.activate(pos, dtype, collision_manager, self)

func _check_boss_spawns(t: float) -> void:
	if not boss_01_spawned and t >= 10.0:
		boss_01_spawned = true
		enemy_spawner.spawn_boss("boss_01")
	if not boss_02_spawned and t >= 20.0:
		boss_02_spawned = true
		enemy_spawner.spawn_boss("boss_02")
	if not boss_final_spawned and t >= 30.0:
		boss_final_spawned = true
		enemy_spawner.spawn_boss("boss_final")
		enemy_spawner.stop_spawning()

func _check_surges(t: float) -> void:
	for i in SURGE_TIMES.size():
		var surge_time: float = SURGE_TIMES[i]
		if t >= surge_time and surge_time not in surges_triggered:
			surges_triggered[surge_time] = true
			enemy_spawner.trigger_surge(SURGE_COUNTS[i])

func _change_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)

	match new_state:
		GameState.PLAYING:
			get_tree().paused = false
		GameState.PAUSED, GameState.LEVEL_UP:
			get_tree().paused = true
		GameState.GAME_OVER:
			get_tree().paused = true

func _on_player_damaged(current_hp: float, max_hp_val: float) -> void:
	hud.update_hp(current_hp, max_hp_val)
	camera.shake(3.0, 0.15)

func _on_player_died() -> void:
	_change_state(GameState.GAME_OVER)
	hud.show_game_over(elapsed_time, kill_count, gold_earned)
	# Save gold earned this run
	var meta = MetaProgression.new()
	meta.load_data()
	meta.add_gold(gold_earned)

func _on_player_healed(current_hp: float, max_hp_val: float) -> void:
	hud.update_hp(current_hp, max_hp_val)

func _on_xp_collected(current_xp: int, xp_needed: int, level: int) -> void:
	hud.update_xp(current_xp, xp_needed, level)

func _on_player_level_up(new_level: int) -> void:
	_change_state(GameState.LEVEL_UP)
	level_up_screen.show_selection(player)

func on_level_up_selection_made(item_id: String) -> void:
	if item_id.begins_with("evo_"):
		_apply_evolution(item_id)
	elif item_id.begins_with("weapon_"):
		player.add_weapon(item_id)
		weapon_system.on_weapon_added(item_id)
	elif item_id.begins_with("passive_"):
		player.add_passive(item_id)
	_change_state(GameState.PLAYING)

func on_enemy_killed(xp_value: int, enemy_position: Vector2) -> void:
	kill_count += 1
	if xp_value > 0:
		xp_pool.spawn_gem(enemy_position, xp_value)

func on_boss_killed(boss_id: String, boss_position: Vector2) -> void:
	kill_count += 1
	xp_pool.spawn_gem(boss_position, 200)
	camera.unlock()
	# Drop treasure chest
	_spawn_treasure_chest(boss_position)

func _spawn_treasure_chest(pos: Vector2) -> void:
	var chest = chest_scene.instantiate() as Area2D
	add_child(chest)
	chest.activate(pos, player)
	chest.chest_opened.connect(_on_chest_opened)
	active_chests.append(chest)

func _on_chest_opened(p: CharacterBody2D) -> void:
	# Check for eligible evolutions
	var eligible_evolutions = _get_eligible_evolutions()

	if eligible_evolutions.is_empty():
		# Fallback: gold + heal + invulnerability
		p.gold += 300
		gold_earned += 300
		p.heal(p.max_hp)
		p.is_invulnerable = true
		p.invulnerable_timer = 10.0
		p.blink_timer = 0.05
	elif eligible_evolutions.size() == 1:
		# Auto-evolve
		_apply_evolution(eligible_evolutions[0])
	else:
		# Show selection screen for multiple evolutions
		_change_state(GameState.LEVEL_UP)
		_show_evolution_selection(eligible_evolutions)

func _get_eligible_evolutions() -> Array[String]:
	var eligible: Array[String] = []
	for evo_id in WeaponData.EVOLUTIONS:
		var evo = WeaponData.EVOLUTIONS[evo_id]
		var req_weapon: String = evo["requires_weapon"]
		var req_passive = evo["requires_passive"]

		# Check weapon at max level (8)
		if req_weapon not in player.weapons:
			continue
		if player.weapon_levels.get(req_weapon, 0) < 8:
			continue

		# Check passive(s)
		if req_passive is String:
			if req_passive not in player.passives:
				continue
			if player.passive_levels.get(req_passive, 0) < 1:
				continue
		elif req_passive is Array:
			var all_met = true
			for rp in req_passive:
				if rp not in player.passives or player.passive_levels.get(rp, 0) < 1:
					all_met = false
					break
			if not all_met:
				continue

		eligible.append(evo_id)
	return eligible

func _apply_evolution(evo_id: String) -> void:
	var evo = WeaponData.EVOLUTIONS[evo_id]
	var old_weapon: String = evo["replaces"]
	weapon_system.remove_weapon(old_weapon)
	player.evolve_weapon(evo_id)
	weapon_system.on_weapon_added(evo_id)

func _show_evolution_selection(evolutions: Array[String]) -> void:
	# Reuse level-up screen for evolution selection
	level_up_screen.visible = true
	level_up_screen._clear_options()
	level_up_screen.title_label.text = "EVOLUTION! Choose one:"
	level_up_screen.current_options = evolutions
	for i in evolutions.size():
		var evo_id: String = evolutions[i]
		var evo = WeaponData.EVOLUTIONS[evo_id]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(500, 60)
		btn.text = "%s: %s" % [evo_id, evo["effect"]]
		btn.pressed.connect(level_up_screen._on_option_pressed.bind(i))
		level_up_screen.options_container.add_child(btn)
		level_up_screen.option_buttons.append(btn)

func on_gold_collected(amount: int) -> void:
	gold_earned += amount
	player.gold += amount

func spawn_enemy_projectile(from: Vector2, target: Vector2, dmg: float) -> void:
	var proj = projectile_pool.get_projectile()
	if not proj:
		return
	var dir = (target - from).normalized()
	proj.activate({
		"position": from,
		"direction": dir,
		"speed": 200.0,
		"damage": dmg,
		"lifetime": 5.0,
		"radius": 5.0,
		"color": Color(1.0, 0.2, 0.2),
		"is_enemy": true,
		"collision_manager": collision_manager,
		"pierce": 1,
		"knockback": 0.0,
	})

func spawn_boss_drones(boss_pos: Vector2, count: int) -> void:
	var time_minutes = get_elapsed_minutes()
	for i in count:
		var drone = enemy_pool.get_enemy()
		if not drone:
			return
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * 50.0
		var data = {
			"class_id": "fodder_01",
			"position": boss_pos + offset,
		}
		drone.activate(data, player, time_minutes, collision_manager, self)
		drone.move_speed = 200.0
		drone.max_hp = 30.0
		drone.current_hp = 30.0
		drone.enemy_died.connect(on_enemy_killed, CONNECT_ONE_SHOT)

func spawn_boss_aoe(from: Vector2, target_pos: Vector2) -> void:
	var proj = projectile_pool.get_projectile()
	if not proj:
		return
	proj.activate({
		"position": target_pos,
		"direction": Vector2.ZERO,
		"speed": 0.0,
		"damage": 20.0,
		"lifetime": 999.0,
		"radius": 48.0,
		"color": Color(1.0, 0.3, 0.0, 0.7),
		"is_enemy": true,
		"collision_manager": collision_manager,
		"pierce": 999,
		"knockback": 0.0,
		"is_pool": true,
		"pool_duration": 4.0,
		"pool_radius": 48.0,
	})

func show_damage_number(pos: Vector2, amount: float, is_crit: bool = false) -> void:
	if damage_numbers:
		damage_numbers.show_damage(pos, amount, is_crit)

func get_elapsed_minutes() -> float:
	return elapsed_time / 60.0
