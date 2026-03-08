extends StaticBody2D

var is_active := false
var hp := 5.0
var max_hp := 5.0
var destructible_type := "destructible_01"

@onready var visual: ColorRect = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var collision_manager: Node
var game_manager: Node

func _ready() -> void:
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if is_active and collision_manager:
		collision_manager.register(self, "destructible")

func activate(pos: Vector2, dtype: String, col_mgr: Node, game: Node) -> void:
	global_position = pos
	destructible_type = dtype
	collision_manager = col_mgr
	game_manager = game
	is_active = true
	visible = true
	set_physics_process(true)

	match dtype:
		"destructible_01":
			hp = 5.0
			max_hp = 5.0
			visual.size = Vector2(24, 24)
			visual.position = Vector2(-12, -12)
			visual.color = Color(0.6, 0.5, 0.4)
			var shape := RectangleShape2D.new()
			shape.size = Vector2(24, 24)
			collision_shape.shape = shape
		"destructible_02":
			hp = 10.0
			max_hp = 10.0
			visual.size = Vector2(32, 32)
			visual.position = Vector2(-16, -16)
			visual.color = Color(0.5, 0.4, 0.3)
			var shape := RectangleShape2D.new()
			shape.size = Vector2(32, 32)
			collision_shape.shape = shape

func take_damage(amount: float) -> void:
	if not is_active:
		return
	hp -= amount
	visual.modulate = Color(2.0, 2.0, 2.0)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.1)

	if hp <= 0:
		_drop_loot()
		is_active = false
		visible = false
		# We can queue_free destructibles since they're spawned once
		queue_free()

func _drop_loot() -> void:
	var roll := randf()

	match destructible_type:
		"destructible_01":
			# 50% nothing, 30% small_heal, 15% gold, 5% screen_nuke
			if roll < 0.50:
				return
			elif roll < 0.80:
				game_manager.player.heal(15.0)
			elif roll < 0.95:
				game_manager.on_gold_collected(randi_range(1, 3))
			else:
				_screen_nuke()
		"destructible_02":
			# 40% nothing, 25% medium_heal, 20% gold, 10% magnet, 5% screen_nuke
			if roll < 0.40:
				return
			elif roll < 0.65:
				game_manager.player.heal(30.0)
			elif roll < 0.85:
				game_manager.on_gold_collected(randi_range(2, 5))
			elif roll < 0.95:
				game_manager.xp_pool.magnet_all()
			else:
				_screen_nuke()

func _screen_nuke() -> void:
	# Destroy all non-boss enemies on screen
	var cam_pos = game_manager.camera.global_position
	var vp_half := Vector2(640, 360)
	var enemies = game_manager.enemy_pool.get_active_enemies()
	for enemy in enemies:
		if not enemy.is_boss and enemy.is_active:
			var dist = enemy.global_position - cam_pos
			if abs(dist.x) < vp_half.x and abs(dist.y) < vp_half.y:
				enemy.take_damage(99999.0)

	# Flash screen white
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.8)
	flash.size = Vector2(1280, 720)
	flash.position = Vector2.ZERO
	game_manager.hud.add_child(flash)
	var tween = game_manager.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)
