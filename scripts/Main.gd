extends Node2D

# Node references
@onready var player: Player = $Player
@onready var game_camera: GameCamera = $GameCamera
@onready var floor_generator: FloorGenerator = $FloorGenerator
@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall
@onready var background: ParallaxBackground = $ParallaxBackground if has_node("ParallaxBackground") else null

# UI references
@onready var hud: HUD = $UI/HUD
@onready var touch_controls: TouchControls = $UI/TouchControls
@onready var game_over_screen: GameOverScreen = $UI/GameOver

# Game settings
@export var tower_width: float = 440.0
@export var tower_left_margin: float = 20.0
@export var start_y: float = 750.0

# Background theming
var tower_background: ColorRect = null
var tower_glow: ColorRect = null
var left_wall_visual: ColorRect = null
var right_wall_visual: ColorRect = null
var left_wall_glow: ColorRect = null
var right_wall_glow: ColorRect = null
var current_background_zone: int = -1

# Combo system
var combo_system: ComboSystem

# Power-up manager
var power_up_manager: PowerUpManager

# Settings panel
var settings_panel: SettingsPanel

# Zone tracking
var current_zone: String = ""

# Player spawn position for distance calculation
var player_start_y: float = 0.0

func _ready() -> void:
	setup_game()
	connect_signals()
	
	# IMPORTANT: Initialize floor generator BEFORE the wait
	# so there's ground for the player during the countdown
	if floor_generator and game_camera:
		floor_generator.initialize(game_camera, start_y)
	
	await get_tree().create_timer(0.5).timeout
	start_game()

func _process(_delta: float) -> void:
	if not GameManager.is_game_active:
		return
	
	# Update distance from starting point
	if player:
		var distance = max(0.0, player_start_y - player.global_position.y) / 10.0  # Convert to meters
		GameManager.update_distance(distance)
	
	# Update HUD with current zone
	if floor_generator and hud:
		var zone = floor_generator.get_current_zone_name()
		if zone != current_zone:
			current_zone = zone
			hud.set_zone(zone)
			# Also update touch controls
			if touch_controls:
				touch_controls.set_phase(zone)
	
	# Update touch controls with camera speed
	if game_camera and touch_controls:
		touch_controls.set_speed(game_camera.get_scroll_speed())
	
	# Update background color based on distance
	update_background_theme()

func setup_game() -> void:
	# Setup combo system
	combo_system = ComboSystem.new()
	add_child(combo_system)
	
	# Setup power-up manager
	power_up_manager = PowerUpManager.new()
	add_child(power_up_manager)
	
	# Setup settings panel
	settings_panel = SettingsPanel.new()
	settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # Work when paused
	$UI.add_child(settings_panel)
	
	# Position walls
	if left_wall:
		left_wall.position = Vector2(tower_left_margin, 0)
	if right_wall:
		right_wall.position = Vector2(tower_left_margin + tower_width, 0)
	
	# Setup camera
	if game_camera:
		game_camera.player = player
	
	# Setup floor generator
	if floor_generator:
		floor_generator.tower_width = tower_width
		floor_generator.tower_left_margin = tower_left_margin
	
	# Setup touch controls
	if touch_controls:
		touch_controls.set_player(player)
	
	# Position player at start - ON TOP of the first floor
	if player:
		var center_x = tower_left_margin + tower_width / 2.0
		player.global_position = Vector2(center_x, start_y - 60)
	
	# Get background references for color changing
	tower_background = get_node_or_null("TowerBackground")
	tower_glow = get_node_or_null("TowerGlow")
	if left_wall:
		left_wall_visual = left_wall.get_node_or_null("Visual")
		left_wall_glow = left_wall.get_node_or_null("GlowEdge")
	if right_wall:
		right_wall_visual = right_wall.get_node_or_null("Visual")
		right_wall_glow = right_wall.get_node_or_null("GlowEdge")

func connect_signals() -> void:
	# Player signals
	if player:
		player.floor_landed.connect(_on_player_floor_landed)
		player.player_died.connect(_on_player_died)
		player.mega_jump_triggered.connect(_on_mega_jump_triggered)
	
	# Camera signals
	if game_camera:
		game_camera.player_fell_off_screen.connect(_on_player_fell)
	
	# GameManager signals
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.distance_changed.connect(_on_distance_changed)
	GameManager.danger_level_changed.connect(_on_danger_changed)
	
	# Combo system signals
	if combo_system:
		combo_system.combo_triggered.connect(_on_combo_triggered)
		combo_system.super_combo.connect(_on_super_combo)
		combo_system.combo_streak_started.connect(_on_streak_started)
		combo_system.combo_streak_ended.connect(_on_streak_ended)
	
	# Power-up manager signals
	if power_up_manager:
		power_up_manager.power_up_activated.connect(_on_power_up_activated)
		power_up_manager.power_up_expired.connect(_on_power_up_expired)
		power_up_manager.shield_used.connect(_on_shield_used)
		power_up_manager.score_multiplier_changed.connect(_on_score_multiplier_changed)
		power_up_manager.mega_jump_changed.connect(_on_mega_jump_changed)
	
	# Floor generator signals
	if floor_generator:
		floor_generator.power_up_spawned.connect(_on_power_up_spawned)
	
	# Game over screen signals
	if game_over_screen:
		game_over_screen.restart_requested.connect(_on_restart_requested)
		game_over_screen.menu_requested.connect(_on_menu_requested)
	
	# HUD settings button
	if hud:
		hud.settings_requested.connect(_on_settings_requested)

func start_game() -> void:
	GameManager.start_game()
	current_zone = ""
	
	# Store player's starting position for distance calculation
	if player:
		player_start_y = player.global_position.y
	
	# Floor generator is already initialized in _ready() for first launch
	# For restarts, it's re-initialized in restart_game()
	
	# Initialize combo system
	if combo_system:
		combo_system.initialize(start_y)
	
	# Initialize power-up manager
	if power_up_manager:
		power_up_manager.initialize(player, game_camera, floor_generator)
		power_up_manager.reset()
	
	# Reset camera
	if game_camera:
		var center_x = tower_left_margin + tower_width / 2.0
		game_camera.reset(Vector2(center_x, start_y - 200))
	
	# Reset HUD and show initial zone
	if hud:
		hud.reset()
		hud.set_zone("LEARNING")
	
	# Reset touch controls info
	if touch_controls:
		touch_controls.set_phase("LEARNING")
		touch_controls.set_speed(0)

func _on_player_floor_landed(floor_y: float) -> void:
	# Process with combo system for scoring
	if combo_system:
		var score = combo_system.on_floor_landed(floor_y)
		if score > 0:
			# Apply power-up score multiplier
			if power_up_manager:
				score = int(score * power_up_manager.get_score_multiplier())
			GameManager.add_score(score)

func _on_player_died() -> void:
	end_game()

func _on_mega_jump_triggered() -> void:
	# Screen shake and flash for mega jump
	if hud:
		hud.trigger_screen_shake(12.0)
		hud.trigger_screen_flash(Color(0.3, 1.0, 0.5, 0.35))

func _on_player_fell() -> void:
	# Check if shield can save us
	if power_up_manager and power_up_manager.try_use_shield():
		# Shield saved us! Push player back up with a big bounce
		if player and game_camera:
			# Teleport player to safe position above camera bottom
			var safe_y = game_camera.global_position.y + 200
			player.global_position.y = safe_y
			player.velocity.y = -player.base_jump_force * 2.0
			player.velocity.x = 0
		return
	
	if player:
		player.die()

func end_game() -> void:
	GameManager.end_game()
	
	if game_camera:
		game_camera.pause_scrolling()
	
	if game_over_screen:
		game_over_screen.show_game_over(
			GameManager.current_score,
			GameManager.current_distance,
			GameManager.best_score
		)

func _on_restart_requested() -> void:
	restart_game()

func _on_menu_requested() -> void:
	restart_game()

func _on_settings_requested() -> void:
	if settings_panel:
		settings_panel.open_panel()

func restart_game() -> void:
	if player:
		var center_x = tower_left_margin + tower_width / 2.0
		player.reset(Vector2(center_x, start_y - 60))
		player.set_combo_jump_active(false)
	
	# Reset background
	current_background_zone = -1
	update_background_theme()
	
	# Reset and re-initialize floor generator
	if floor_generator:
		floor_generator.reset()
		if game_camera:
			floor_generator.initialize(game_camera, start_y)
	
	if combo_system:
		combo_system.reset()
	
	if power_up_manager:
		power_up_manager.reset()
	
	current_zone = ""
	start_game()

# UI Update callbacks
func _on_score_changed(new_score: int) -> void:
	if hud:
		hud.set_score(new_score)

func _on_distance_changed(distance: float) -> void:
	if hud:
		hud.set_distance(distance)

func _on_danger_changed(level: float) -> void:
	if hud:
		hud.set_danger_level(level)

# ========== COMBO CALLBACKS ==========

func _on_combo_triggered(floors_skipped: int) -> void:
	var streak = combo_system.get_streak_count() if combo_system else 1
	
	if hud:
		hud.set_combo(floors_skipped)
	
	# Calculate position relative to viewport (HUD uses viewport coordinates)
	var effect_pos = Vector2(240, 400)  # Default center-ish
	if player and game_camera:
		# Convert player world position to screen position
		var camera_pos = game_camera.global_position
		var viewport_size = get_viewport().get_visible_rect().size
		effect_pos.x = player.global_position.x  # X is roughly the same
		effect_pos.y = viewport_size.y / 2 + (player.global_position.y - camera_pos.y) * 0.5
		effect_pos.y = clamp(effect_pos.y, 100, viewport_size.y - 100)
	
	if hud:
		var combo_word = get_combo_word(floors_skipped, streak)
		hud.show_combo_word(combo_word)
		hud.trigger_combo_celebration(effect_pos)

func _on_super_combo(floors_skipped: int) -> void:
	# Extra screen shake for super combos
	if hud:
		hud.trigger_screen_shake(8.0)
		hud.trigger_screen_flash(Color(1, 0.8, 0.2, 0.3))

func _on_streak_started() -> void:
	if player:
		player.set_combo_jump_active(true)
	
	if hud:
		hud.set_streak_active(true)

func _on_streak_ended(streak_count: int) -> void:
	if player:
		player.set_combo_jump_active(false)
	
	if hud:
		hud.set_combo(0)
		hud.set_streak_active(false)
	
	if streak_count >= 3 and hud:
		hud.show_combo_word("STREAK x%d!" % streak_count)

func get_combo_word(floors_skipped: int, streak: int) -> String:
	if floors_skipped >= 12:
		return "ULTRA!"
	elif floors_skipped >= 8:
		return "MEGA!"
	elif floors_skipped >= 5:
		return "SUPER!"
	elif floors_skipped >= 3:
		if streak >= 3:
			return "GREAT x%d!" % streak
		return "GREAT!"
	else:
		if streak >= 3:
			return "NICE x%d!" % streak
		return "NICE!"

# ========== POWER-UP CALLBACKS ==========

func _on_power_up_spawned(power_up: PowerUp, _floor_node: Floor) -> void:
	# Connect the power-up to the manager
	if power_up_manager:
		power_up.collected.connect(power_up_manager.on_power_up_collected)

func _on_power_up_activated(type: PowerUp.Type, duration: float) -> void:
	if hud:
		hud.show_power_up_activated(type, duration)
	
	# Visual feedback for specific power-ups
	match type:
		PowerUp.Type.SHIELD:
			if player:
				player.set_shield_active(true)
		PowerUp.Type.MEGA_JUMP:
			# Visual pulse on player when mega jump activates
			if player and player.sprite:
				var tween = player.create_tween()
				tween.tween_property(player.sprite, "modulate", Color(0.5, 1.0, 0.5), 0.1)
				tween.tween_property(player.sprite, "modulate", Color(1, 1, 1), 0.3)

func _on_power_up_expired(type: PowerUp.Type) -> void:
	if hud:
		hud.remove_power_up_indicator(type)
	
	# Clear player states
	match type:
		PowerUp.Type.SHIELD:
			if player:
				player.set_shield_active(false)
		PowerUp.Type.MEGA_JUMP:
			if player:
				player.set_mega_jump_active(false)

func _on_shield_used() -> void:
	if hud:
		hud.show_shield_used()
	if player:
		player.set_shield_active(false)

func _on_score_multiplier_changed(multiplier: float) -> void:
	if hud:
		hud.set_score_multiplier(multiplier)

func _on_mega_jump_changed(active: bool) -> void:
	if player:
		player.set_mega_jump_active(active)

# ========== BACKGROUND THEMING ==========

const ZONE_THEMES = [
	# Zone 0: Learning (0-299) - Deep Purple/Blue
	{
		"tower": Color(0.06, 0.04, 0.14),
		"glow": Color(0.1, 0.06, 0.2, 0.5),
		"wall": Color(0.1, 0.06, 0.25),
		"wall_glow": Color(0.6, 0.3, 1, 0.6)
	},
	# Zone 1: Moving (300-599) - Teal/Cyan
	{
		"tower": Color(0.04, 0.1, 0.12),
		"glow": Color(0.06, 0.15, 0.18, 0.5),
		"wall": Color(0.06, 0.15, 0.2),
		"wall_glow": Color(0.3, 0.8, 1, 0.6)
	},
	# Zone 2: Crumbling (600-899) - Deep Red/Orange
	{
		"tower": Color(0.12, 0.04, 0.04),
		"glow": Color(0.18, 0.06, 0.04, 0.5),
		"wall": Color(0.2, 0.08, 0.06),
		"wall_glow": Color(1, 0.4, 0.3, 0.6)
	},
	# Zone 3: Ice (900-1199) - Light Blue/White
	{
		"tower": Color(0.08, 0.1, 0.14),
		"glow": Color(0.12, 0.18, 0.25, 0.5),
		"wall": Color(0.15, 0.2, 0.28),
		"wall_glow": Color(0.7, 0.9, 1, 0.7)
	},
	# Zone 4: Spring (1200-1499) - Green/Nature
	{
		"tower": Color(0.04, 0.1, 0.05),
		"glow": Color(0.06, 0.15, 0.08, 0.5),
		"wall": Color(0.08, 0.18, 0.1),
		"wall_glow": Color(0.4, 1, 0.5, 0.6)
	},
	# Zone 5: Endgame (1500+) - Hot Pink/Neon
	{
		"tower": Color(0.12, 0.03, 0.1),
		"glow": Color(0.2, 0.05, 0.15, 0.6),
		"wall": Color(0.2, 0.06, 0.18),
		"wall_glow": Color(1, 0.3, 0.8, 0.7)
	}
]

func update_background_theme() -> void:
	# Use distance to determine zone (each zone is ~300 meters)
	var distance = GameManager.current_distance
	var zone_index = int(distance / 300.0)
	zone_index = mini(zone_index, ZONE_THEMES.size() - 1)
	
	# Only update if zone changed
	if zone_index == current_background_zone:
		return
	
	current_background_zone = zone_index
	var theme = ZONE_THEMES[zone_index]
	
	# Animate color transitions
	var duration = 1.5
	
	if tower_background:
		var tween = get_tree().create_tween()
		tween.tween_property(tower_background, "color", theme["tower"], duration)
	
	if tower_glow:
		var tween = get_tree().create_tween()
		tween.tween_property(tower_glow, "color", theme["glow"], duration)
	
	if left_wall_visual:
		var tween = get_tree().create_tween()
		tween.tween_property(left_wall_visual, "color", theme["wall"], duration)
	
	if right_wall_visual:
		var tween = get_tree().create_tween()
		tween.tween_property(right_wall_visual, "color", theme["wall"], duration)
	
	if left_wall_glow:
		var tween = get_tree().create_tween()
		tween.tween_property(left_wall_glow, "color", theme["wall_glow"], duration)
	
	if right_wall_glow:
		var tween = get_tree().create_tween()
		tween.tween_property(right_wall_glow, "color", theme["wall_glow"], duration)
