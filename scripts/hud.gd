extends CanvasLayer

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPBar/Label
@onready var xp_bar: ProgressBar = $XPBar
@onready var xp_label: Label = $XPBar/Label
@onready var timer_label: Label = $TimerLabel
@onready var kill_label: Label = $KillLabel
@onready var level_label: Label = $LevelLabel
@onready var boss_hp_bar: ProgressBar = $BossHPBar
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/Label

func _ready() -> void:
	boss_hp_bar.visible = false
	game_over_panel.visible = false

func update_hp(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d" % [int(current), int(maximum)]

func update_xp(current: int, needed: int, level: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current
	xp_label.text = "%d / %d" % [current, needed]
	level_label.text = "LV %d" % level

func update_timer(elapsed_seconds: float) -> void:
	var minutes = int(elapsed_seconds) / 60
	var seconds = int(elapsed_seconds) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func update_kills(count: int) -> void:
	kill_label.text = "Kills: %d" % count

func update_boss_hp(current: float, maximum: float) -> void:
	boss_hp_bar.visible = true
	boss_hp_bar.max_value = maximum
	boss_hp_bar.value = current
	if current <= 0:
		boss_hp_bar.visible = false

func show_game_over(elapsed: float, kills: int, gold: int) -> void:
	game_over_panel.visible = true
	var minutes = int(elapsed) / 60
	var seconds = int(elapsed) % 60
	game_over_label.text = "GAME OVER\n\nTime: %02d:%02d\nKills: %d\nGold earned: %d\n\nR - Restart | M - Main Menu" % [minutes, seconds, kills, gold]
