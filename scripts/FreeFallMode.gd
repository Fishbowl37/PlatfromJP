extends Node2D

# Free Fall Mode - TIME ATTACK with Progressive Difficulty!
# Fall as deep as possible before time runs out.
# New challenges unlock at deeper depths!

# Node references
@onready var player: Player = $Player
@onready var game_camera: GameCamera = $GameCamera
@onready var obstacle_container: Node2D = $ObstacleContainer
@onready var hud: HUD = $UI/HUD
@onready var touch_controls: TouchControls = $UI/TouchControls
@onready var game_over_screen: GameOverScreen = $UI/GameOver

# Game settings
@export var tower_width: float = 440.0
@export var tower_left_margin: float = 20.0

# Time attack settings
@export var starting_time: float = 15.0
@export var time_per_coin: float = 1.5
@export var checkpoint_interval: float = 800.0
@export var time_per_checkpoint: float = 5.0

# Depth milestones for new features
const DEPTH_ADVANCED_OBSTACLES: float = 1500.0  # Zigzag, closing gates, vertical movers
const DEPTH_HAZARD_ZONES: float = 2500.0        # Wind, speed boost, narrow corridors
const DEPTH_VISUAL_EFFECTS: float = 5000.0      # Screen shake, fog
const DEPTH_POWERUPS: float = 7500.0            # Shrink, slow-mo, trap coins

# Obstacle settings
@export var obstacle_pool_size: int = 30
@export var min_obstacle_spacing: float = 180.0
@export var max_obstacle_spacing: float = 280.0
@export var base_obstacle_width: float = 80.0
@export var max_obstacle_width: float = 280.0

# Current state
var time_remaining: float = 0.0
var depth_reached: float = 0.0
var max_depth: float = 0.0
var score: int = 0
var is_game_active: bool = false
var start_y: float = 0.0

# Checkpoints
var next_checkpoint_depth: float = 0.0
var checkpoints_reached: int = 0

# Obstacle pooling
var obstacle_pool: Array[Node2D] = []
var active_obstacles: Array[Node2D] = []
var next_obstacle_y: float = 0.0

# Coin pooling
var coin_pool: Array[Area2D] = []
var active_coins: Array[Area2D] = []
var coins_collected: int = 0

# Hazard zones
var wind_zones: Array[Dictionary] = []
var speed_zones: Array[Dictionary] = []
var current_wind_force: float = 0.0
var current_speed_multiplier: float = 1.0

# Visual effects
var fog_overlay: ColorRect = null
var current_fog_alpha: float = 0.0
var screen_shake_intensity: float = 0.0

# Power-ups
var is_shrunk: bool = false
var shrink_timer: float = 0.0
var original_player_scale: Vector2 = Vector2.ONE
var is_slowmo: bool = false
var slowmo_timer: float = 0.0

# Difficulty tracking
var difficulty_level: int = 0
var last_pattern_type: int = 0

# UI elements
var menu_button: Button = null
var timer_label: Label = null

# Zone visuals
var zone_container: Node2D = null

func _ready() -> void:
	setup_game()
	create_obstacle_pool()
	create_coin_pool()
	create_zone_container()
	create_fog_overlay()
	create_menu_button()
	create_timer_display()
	
	if player:
		player.player_died.connect(_on_player_died)
		original_player_scale = player.scale
	
	if game_over_screen:
		game_over_screen.restart_requested.connect(_on_restart)
		game_over_screen.menu_requested.connect(_on_menu)
	
	if touch_controls:
		touch_controls.set_player(player)
	
	if hud:
		hud.set_zone("TIME ATTACK")
	
	await get_tree().create_timer(0.5).timeout
	start_game()

func setup_game() -> void:
	if player:
		var center_x = tower_left_margin + tower_width / 2.0
		player.global_position = Vector2(center_x, 100)
		start_y = player.global_position.y

func create_zone_container() -> void:
	zone_container = Node2D.new()
	zone_container.z_index = -1
	add_child(zone_container)

func create_fog_overlay() -> void:
	fog_overlay = ColorRect.new()
	fog_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	fog_overlay.z_index = 100
	fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var canvas = CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	
	fog_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fog_overlay)

func create_timer_display() -> void:
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	
	var timer_bg = ColorRect.new()
	timer_bg.color = Color(0.1, 0.05, 0.02, 0.9)
	timer_bg.size = Vector2(120, 50)
	timer_bg.position = Vector2(180, 65)
	ui_layer.add_child(timer_bg)
	
	var timer_border = ColorRect.new()
	timer_border.color = Color(1.0, 0.6, 0.2, 0.8)
	timer_border.size = Vector2(124, 54)
	timer_border.position = Vector2(178, 63)
	timer_border.z_index = -1
	ui_layer.add_child(timer_border)
	
	timer_label = Label.new()
	timer_label.text = "15.0"
	timer_label.position = Vector2(180, 67)
	timer_label.size = Vector2(120, 50)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	ui_layer.add_child(timer_label)

func create_menu_button() -> void:
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 15
	add_child(ui_layer)
	
	menu_button = Button.new()
	menu_button.text = "< MENU"
	menu_button.position = Vector2(15, 65)
	menu_button.custom_minimum_size = Vector2(90, 40)
	menu_button.add_theme_font_size_override("font_size", 14)
	menu_button.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.1, 0.1, 0.9)
	style.border_color = Color(0.8, 0.5, 0.3, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	menu_button.add_theme_stylebox_override("normal", style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.15, 0.1, 1.0)
	hover_style.border_color = Color(1.0, 0.6, 0.4, 0.8)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(10)
	menu_button.add_theme_stylebox_override("hover", hover_style)
	
	menu_button.pressed.connect(_on_menu)
	ui_layer.add_child(menu_button)

func create_obstacle_pool() -> void:
	for i in range(obstacle_pool_size):
		var obstacle = _create_obstacle()
		obstacle.visible = false
		obstacle_container.add_child(obstacle)
		obstacle_pool.append(obstacle)

func _create_obstacle() -> StaticBody2D:
	var obstacle = StaticBody2D.new()
	obstacle.collision_layer = 2
	obstacle.collision_mask = 0
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 20)
	collision.shape = shape
	obstacle.add_child(collision)
	
	var visual = ColorRect.new()
	visual.name = "Visual"
	visual.size = Vector2(100, 20)
	visual.position = Vector2(-50, -10)
	visual.color = Color(0.5, 0.2, 0.15)
	obstacle.add_child(visual)
	
	var top_edge = ColorRect.new()
	top_edge.name = "TopEdge"
	top_edge.size = Vector2(100, 4)
	top_edge.position = Vector2(-50, -10)
	top_edge.color = Color(0.8, 0.35, 0.25)
	obstacle.add_child(top_edge)
	
	return obstacle

func _setup_obstacle(obstacle: StaticBody2D, width: float, color_variant: int = 0) -> void:
	var collision = obstacle.get_child(0) as CollisionShape2D
	if collision and collision.shape is RectangleShape2D:
		collision.shape.size = Vector2(width, 20)
	
	var visual = obstacle.get_node("Visual") as ColorRect
	var top_edge = obstacle.get_node("TopEdge") as ColorRect
	
	if visual:
		visual.size = Vector2(width, 20)
		visual.position = Vector2(-width / 2, -10)
	
	if top_edge:
		top_edge.size = Vector2(width, 4)
		top_edge.position = Vector2(-width / 2, -10)
	
	# Color based on variant
	match color_variant:
		0:  # Normal
			if visual: visual.color = Color(0.5, 0.2, 0.15)
			if top_edge: top_edge.color = Color(0.8, 0.35, 0.25)
		1:  # Closing gate (blue)
			if visual: visual.color = Color(0.2, 0.3, 0.6)
			if top_edge: top_edge.color = Color(0.4, 0.5, 0.9)
		2:  # Vertical mover (green)
			if visual: visual.color = Color(0.2, 0.5, 0.3)
			if top_edge: top_edge.color = Color(0.4, 0.8, 0.5)
		3:  # Zigzag (purple)
			if visual: visual.color = Color(0.4, 0.2, 0.5)
			if top_edge: top_edge.color = Color(0.7, 0.4, 0.8)

func create_coin_pool() -> void:
	for i in range(25):
		var coin = _create_coin(0)  # Normal coin
		coin.visible = false
		obstacle_container.add_child(coin)
		coin_pool.append(coin)

func _create_coin(coin_type: int) -> Area2D:
	var coin = Area2D.new()
	coin.collision_layer = 0
	coin.collision_mask = 1
	coin.set_meta("coin_type", coin_type)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 28
	collision.shape = shape
	coin.add_child(collision)
	
	var outer = Polygon2D.new()
	outer.name = "Outer"
	var points: PackedVector2Array = []
	for j in range(12):
		var angle = (TAU / 12) * j
		points.append(Vector2(cos(angle), sin(angle)) * 14)
	outer.polygon = points
	coin.add_child(outer)
	
	var inner = Polygon2D.new()
	inner.name = "Inner"
	var inner_points: PackedVector2Array = []
	for j in range(8):
		var angle = (TAU / 8) * j
		inner_points.append(Vector2(cos(angle), sin(angle)) * 8)
	inner.polygon = inner_points
	coin.add_child(inner)
	
	# Icon in center
	var icon = Label.new()
	icon.name = "Icon"
	icon.position = Vector2(-6, -8)
	icon.add_theme_font_size_override("font_size", 12)
	coin.add_child(icon)
	
	_style_coin(coin, coin_type)
	
	coin.body_entered.connect(_on_coin_collected.bind(coin))
	return coin

func _style_coin(coin: Area2D, coin_type: int) -> void:
	var outer = coin.get_node("Outer") as Polygon2D
	var inner = coin.get_node("Inner") as Polygon2D
	var icon = coin.get_node("Icon") as Label
	
	coin.set_meta("coin_type", coin_type)
	
	match coin_type:
		0:  # Normal time coin (cyan)
			outer.color = Color(0.2, 0.9, 1.0)
			inner.color = Color(0.5, 1.0, 1.0)
			icon.text = "+"
			icon.add_theme_color_override("font_color", Color(1, 1, 1))
		1:  # Shrink power-up (pink)
			outer.color = Color(1.0, 0.4, 0.8)
			inner.color = Color(1.0, 0.7, 0.9)
			icon.text = "S"
			icon.add_theme_color_override("font_color", Color(0.3, 0, 0.2))
		2:  # Slow-mo (yellow)
			outer.color = Color(1.0, 0.9, 0.2)
			inner.color = Color(1.0, 1.0, 0.6)
			icon.text = "◷"
			icon.add_theme_color_override("font_color", Color(0.3, 0.2, 0))
		3:  # Trap coin (red tint - looks like normal but reddish)
			outer.color = Color(0.4, 0.7, 0.9)  # Slightly off cyan
			inner.color = Color(0.6, 0.85, 0.95)
			icon.text = "+"
			icon.add_theme_color_override("font_color", Color(1, 0.8, 0.8))

func start_game() -> void:
	is_game_active = true
	time_remaining = starting_time
	depth_reached = 0.0
	max_depth = 0.0
	score = 0
	coins_collected = 0
	difficulty_level = 0
	checkpoints_reached = 0
	next_checkpoint_depth = checkpoint_interval
	last_pattern_type = 0
	
	# Reset effects
	is_shrunk = false
	shrink_timer = 0.0
	is_slowmo = false
	slowmo_timer = 0.0
	current_wind_force = 0.0
	current_speed_multiplier = 1.0
	current_fog_alpha = 0.0
	screen_shake_intensity = 0.0
	
	if fog_overlay:
		fog_overlay.color.a = 0.0
	
	# Reset player
	if player:
		var center_x = tower_left_margin + tower_width / 2.0
		player.global_position = Vector2(center_x, 100)
		player.velocity = Vector2.ZERO
		player.modulate.a = 1.0
		player.scale = original_player_scale
		start_y = player.global_position.y
	
	# Reset camera
	if game_camera:
		game_camera.global_position = Vector2(tower_left_margin + tower_width / 2.0, 200)
	
	# Clear obstacles
	for obs in active_obstacles:
		obs.visible = false
		obstacle_pool.append(obs)
	active_obstacles.clear()
	
	# Clear coins
	for coin in active_coins:
		coin.visible = false
		coin_pool.append(coin)
	active_coins.clear()
	
	# Clear zones
	wind_zones.clear()
	speed_zones.clear()
	for child in zone_container.get_children():
		child.queue_free()
	
	next_obstacle_y = 350.0
	
	GameManager.is_game_active = true
	GameManager.current_score = 0
	
	if hud:
		hud.reset()
		hud.set_zone("TIME ATTACK")
	
	update_timer_display()

func _physics_process(delta: float) -> void:
	if not is_game_active:
		return
	
	# Apply slowmo
	var effective_delta = delta
	if is_slowmo:
		effective_delta = delta * 0.4
		slowmo_timer -= delta
		if slowmo_timer <= 0:
			is_slowmo = false
			Engine.time_scale = 1.0
	
	# Count down timer
	time_remaining -= delta  # Real time, not affected by slowmo
	if time_remaining <= 0:
		time_remaining = 0
		_on_time_up()
		return
	
	# Update shrink effect
	if is_shrunk:
		shrink_timer -= delta
		if shrink_timer <= 0:
			is_shrunk = false
			if player:
				var tween = create_tween()
				tween.tween_property(player, "scale", original_player_scale, 0.3)
	
	# Update difficulty based on depth
	update_difficulty()
	
	# Track depth
	if player:
		depth_reached = max(0.0, (player.global_position.y - start_y) / 10.0)
		if depth_reached > max_depth:
			max_depth = depth_reached
		
		check_checkpoint()
		
		score = int(max_depth * 3) + coins_collected * 20 + checkpoints_reached * 100
		GameManager.current_score = score
		GameManager.current_distance = max_depth
	
	# Apply environmental effects
	apply_environmental_effects(delta)
	
	# Update camera with shake
	update_camera(delta)
	
	# Spawn obstacles and patterns
	spawn_obstacles()
	
	# Update all obstacle behaviors
	update_obstacles(delta)
	
	# Recycle off-screen objects
	recycle_objects()
	
	# Update visual effects
	update_visual_effects(delta)
	
	# Update displays
	update_timer_display()
	update_hud()

func update_difficulty() -> void:
	var new_level = int(max_depth / 80)
	if new_level > difficulty_level:
		difficulty_level = new_level
		
		# Show milestone messages
		if max_depth >= DEPTH_ADVANCED_OBSTACLES and max_depth < DEPTH_ADVANCED_OBSTACLES + 100:
			if hud: hud.show_combo_word("ADVANCED OBSTACLES!")
		elif max_depth >= DEPTH_HAZARD_ZONES and max_depth < DEPTH_HAZARD_ZONES + 100:
			if hud: hud.show_combo_word("HAZARD ZONES!")
		elif max_depth >= DEPTH_VISUAL_EFFECTS and max_depth < DEPTH_VISUAL_EFFECTS + 100:
			if hud: hud.show_combo_word("DARKNESS FALLS!")
		elif max_depth >= DEPTH_POWERUPS and max_depth < DEPTH_POWERUPS + 100:
			if hud: hud.show_combo_word("POWER-UPS UNLOCKED!")

func apply_environmental_effects(delta: float) -> void:
	if not player:
		return
	
	# Reset per-frame values
	current_wind_force = 0.0
	current_speed_multiplier = 1.0
	
	# Check wind zones
	for zone in wind_zones:
		if player.global_position.y > zone.start_y and player.global_position.y < zone.end_y:
			current_wind_force = zone.force
	
	# Check speed zones
	for zone in speed_zones:
		if player.global_position.y > zone.start_y and player.global_position.y < zone.end_y:
			current_speed_multiplier = zone.multiplier
	
	# Apply wind force
	if current_wind_force != 0:
		player.velocity.x += current_wind_force * delta * 60
	
	# Apply speed boost
	if current_speed_multiplier > 1.0:
		player.velocity.y = max(player.velocity.y, 400 * current_speed_multiplier)

func update_camera(delta: float) -> void:
	if not game_camera or not player:
		return
	
	var target_y = player.global_position.y + 80
	game_camera.global_position.y = lerp(game_camera.global_position.y, target_y, 6 * delta)
	game_camera.global_position.x = tower_left_margin + tower_width / 2.0
	
	# Apply screen shake (after 10000m)
	if max_depth >= DEPTH_VISUAL_EFFECTS:
		var shake_amount = min((max_depth - DEPTH_VISUAL_EFFECTS) / 5000.0, 1.0) * 3.0
		game_camera.offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
	else:
		game_camera.offset = Vector2.ZERO

func update_visual_effects(_delta: float) -> void:
	# Fog effect (after 10000m)
	if max_depth >= DEPTH_VISUAL_EFFECTS:
		var target_fog = min((max_depth - DEPTH_VISUAL_EFFECTS) / 10000.0, 0.5)
		current_fog_alpha = lerp(current_fog_alpha, target_fog, 0.02)
		if fog_overlay:
			fog_overlay.color = Color(0.02, 0.01, 0.05, current_fog_alpha)

func spawn_obstacles() -> void:
	if not player:
		return
	
	var spawn_threshold = player.global_position.y + 700
	
	while next_obstacle_y < spawn_threshold and obstacle_pool.size() > 0:
		# Determine what type of pattern to spawn
		var pattern = determine_pattern()
		
		match pattern:
			0: spawn_normal_obstacle()
			1: spawn_zigzag_pattern()
			2: spawn_closing_gate()
			3: spawn_vertical_mover()
		
		# Maybe spawn zones (after 5000m)
		if max_depth >= DEPTH_HAZARD_ZONES:
			maybe_spawn_zone()

func determine_pattern() -> int:
	# Before 3000m, only normal obstacles
	if max_depth < DEPTH_ADVANCED_OBSTACLES:
		return 0
	
	# After 3000m, mix of patterns
	var roll = randf()
	
	# Don't repeat same pattern twice
	var pattern = 0
	if roll < 0.4:
		pattern = 0  # Normal
	elif roll < 0.6:
		pattern = 1  # Zigzag
	elif roll < 0.8:
		pattern = 2  # Closing gate
	else:
		pattern = 3  # Vertical mover
	
	if pattern == last_pattern_type and pattern != 0:
		pattern = 0  # Default to normal if repeating
	
	last_pattern_type = pattern
	return pattern

func spawn_normal_obstacle() -> void:
	if obstacle_pool.size() == 0:
		return
	
	var obstacle = obstacle_pool.pop_back()
	
	var width_bonus = difficulty_level * 8.0
	var width = randf_range(base_obstacle_width, base_obstacle_width + 40.0) + width_bonus
	width = clamp(width, base_obstacle_width, max_obstacle_width)
	
	_setup_obstacle(obstacle, width, 0)
	
	# Basic horizontal movement
	var is_moving = difficulty_level >= 2 and randf() < 0.25
	obstacle.set_meta("move_type", "horizontal" if is_moving else "none")
	obstacle.set_meta("move_dir", 1.0 if randf() > 0.5 else -1.0)
	obstacle.set_meta("move_speed", 50.0 + difficulty_level * 3)
	
	var max_x = tower_left_margin + tower_width - width / 2 - 15
	var min_x = tower_left_margin + width / 2 + 15
	var x_pos = randf_range(min_x, max_x)
	
	obstacle.global_position = Vector2(x_pos, next_obstacle_y)
	obstacle.visible = true
	active_obstacles.append(obstacle)
	
	# Spawn coins
	maybe_spawn_coin(x_pos, next_obstacle_y - 50)
	
	var spacing = randf_range(min_obstacle_spacing, max_obstacle_spacing)
	spacing = max(140, spacing - difficulty_level * 5)
	next_obstacle_y += spacing

func spawn_zigzag_pattern() -> void:
	# Create a zigzag of 3-4 obstacles forcing a specific path
	var num_obstacles = randi_range(3, 4)
	var direction = 1 if randf() > 0.5 else -1
	var current_x = tower_left_margin + tower_width / 2.0
	
	for i in range(num_obstacles):
		if obstacle_pool.size() == 0:
			break
		
		var obstacle = obstacle_pool.pop_back()
		var width = randf_range(120, 180)
		
		_setup_obstacle(obstacle, width, 3)  # Purple for zigzag
		obstacle.set_meta("move_type", "none")
		
		# Alternate sides
		if direction > 0:
			current_x = tower_left_margin + width / 2 + 20
		else:
			current_x = tower_left_margin + tower_width - width / 2 - 20
		
		direction *= -1
		
		obstacle.global_position = Vector2(current_x, next_obstacle_y)
		obstacle.visible = true
		active_obstacles.append(obstacle)
		
		# Coin in the gap
		var coin_x = tower_left_margin + tower_width - current_x + tower_left_margin
		maybe_spawn_coin(coin_x, next_obstacle_y - 30)
		
		next_obstacle_y += 120
	
	next_obstacle_y += 100  # Extra space after pattern

func spawn_closing_gate() -> void:
	# Two obstacles that move toward each other
	if obstacle_pool.size() < 2:
		return
	
	var gap_size = randf_range(80, 120)
	var width = (tower_width - gap_size) / 2 - 20
	
	# Left gate
	var left_gate = obstacle_pool.pop_back()
	_setup_obstacle(left_gate, width, 1)  # Blue for gates
	left_gate.set_meta("move_type", "closing")
	left_gate.set_meta("move_dir", 1.0)
	left_gate.set_meta("move_speed", 30.0 + difficulty_level * 2)
	left_gate.set_meta("original_x", tower_left_margin + width / 2 + 10)
	left_gate.set_meta("max_travel", 40.0)
	left_gate.global_position = Vector2(tower_left_margin + width / 2 + 10, next_obstacle_y)
	left_gate.visible = true
	active_obstacles.append(left_gate)
	
	# Right gate
	var right_gate = obstacle_pool.pop_back()
	_setup_obstacle(right_gate, width, 1)
	right_gate.set_meta("move_type", "closing")
	right_gate.set_meta("move_dir", -1.0)
	right_gate.set_meta("move_speed", 30.0 + difficulty_level * 2)
	right_gate.set_meta("original_x", tower_left_margin + tower_width - width / 2 - 10)
	right_gate.set_meta("max_travel", 40.0)
	right_gate.global_position = Vector2(tower_left_margin + tower_width - width / 2 - 10, next_obstacle_y)
	right_gate.visible = true
	active_obstacles.append(right_gate)
	
	# Coin in the center
	maybe_spawn_coin(tower_left_margin + tower_width / 2, next_obstacle_y - 40)
	
	next_obstacle_y += randf_range(200, 280)

func spawn_vertical_mover() -> void:
	if obstacle_pool.size() == 0:
		return
	
	var obstacle = obstacle_pool.pop_back()
	var width = randf_range(100, 160)
	
	_setup_obstacle(obstacle, width, 2)  # Green for vertical
	obstacle.set_meta("move_type", "vertical")
	obstacle.set_meta("move_dir", 1.0 if randf() > 0.5 else -1.0)
	obstacle.set_meta("move_speed", 40.0 + difficulty_level * 3)
	obstacle.set_meta("original_y", next_obstacle_y)
	obstacle.set_meta("move_range", 60.0)
	
	var x_pos = randf_range(tower_left_margin + width / 2 + 20, tower_left_margin + tower_width - width / 2 - 20)
	obstacle.global_position = Vector2(x_pos, next_obstacle_y)
	obstacle.visible = true
	active_obstacles.append(obstacle)
	
	maybe_spawn_coin(x_pos, next_obstacle_y - 80)
	
	next_obstacle_y += randf_range(220, 300)

func maybe_spawn_zone() -> void:
	if randf() > 0.08:  # 8% chance per obstacle
		return
	
	var zone_type = randi() % 2
	
	match zone_type:
		0: spawn_wind_zone()
		1: spawn_speed_zone()

func spawn_wind_zone() -> void:
	var zone_height = randf_range(300, 500)
	var force = randf_range(150, 300) * (1 if randf() > 0.5 else -1)
	
	var zone = {
		"start_y": next_obstacle_y,
		"end_y": next_obstacle_y + zone_height,
		"force": force
	}
	wind_zones.append(zone)
	
	# Visual indicator
	var visual = ColorRect.new()
	visual.color = Color(0.3, 0.5, 0.8, 0.15)
	visual.size = Vector2(tower_width, zone_height)
	visual.position = Vector2(tower_left_margin, next_obstacle_y)
	zone_container.add_child(visual)
	
	# Arrow indicators
	var arrow_text = "→→→" if force > 0 else "←←←"
	var arrow = Label.new()
	arrow.text = arrow_text
	arrow.position = Vector2(tower_left_margin + tower_width / 2 - 30, next_obstacle_y + zone_height / 2)
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0, 0.6))
	zone_container.add_child(arrow)

func spawn_speed_zone() -> void:
	var zone_height = randf_range(200, 400)
	var multiplier = randf_range(1.5, 2.0)
	
	var zone = {
		"start_y": next_obstacle_y,
		"end_y": next_obstacle_y + zone_height,
		"multiplier": multiplier
	}
	speed_zones.append(zone)
	
	# Visual - red tint
	var visual = ColorRect.new()
	visual.color = Color(0.8, 0.3, 0.2, 0.15)
	visual.size = Vector2(tower_width, zone_height)
	visual.position = Vector2(tower_left_margin, next_obstacle_y)
	zone_container.add_child(visual)
	
	var label = Label.new()
	label.text = "⚡ SPEED"
	label.position = Vector2(tower_left_margin + tower_width / 2 - 40, next_obstacle_y + zone_height / 2)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3, 0.6))
	zone_container.add_child(label)

func maybe_spawn_coin(x: float, y: float) -> void:
	if randf() > 0.5 or coin_pool.size() == 0:
		return
	
	var coin = coin_pool.pop_back()
	
	# Determine coin type based on depth
	var coin_type = 0  # Normal
	if max_depth >= DEPTH_POWERUPS:
		var roll = randf()
		if roll < 0.1:
			coin_type = 1  # Shrink
		elif roll < 0.2:
			coin_type = 2  # Slow-mo
		elif roll < 0.3:
			coin_type = 3  # Trap
	
	_style_coin(coin, coin_type)
	coin.global_position = Vector2(x, y)
	coin.visible = true
	active_coins.append(coin)

func update_obstacles(delta: float) -> void:
	for obs in active_obstacles:
		var move_type = obs.get_meta("move_type", "none")
		
		match move_type:
			"horizontal":
				var dir = obs.get_meta("move_dir", 1.0)
				var speed = obs.get_meta("move_speed", 50.0)
				obs.global_position.x += dir * speed * delta
				
				var collision = obs.get_child(0) as CollisionShape2D
				var half_width = 50.0
				if collision and collision.shape is RectangleShape2D:
					half_width = collision.shape.size.x / 2
				
				if obs.global_position.x - half_width < tower_left_margin + 5:
					obs.set_meta("move_dir", 1.0)
				elif obs.global_position.x + half_width > tower_left_margin + tower_width - 5:
					obs.set_meta("move_dir", -1.0)
			
			"vertical":
				var dir = obs.get_meta("move_dir", 1.0)
				var speed = obs.get_meta("move_speed", 40.0)
				var original_y = obs.get_meta("original_y", obs.global_position.y)
				var move_range = obs.get_meta("move_range", 60.0)
				
				obs.global_position.y += dir * speed * delta
				
				if obs.global_position.y > original_y + move_range:
					obs.set_meta("move_dir", -1.0)
				elif obs.global_position.y < original_y - move_range:
					obs.set_meta("move_dir", 1.0)
			
			"closing":
				var dir = obs.get_meta("move_dir", 1.0)
				var speed = obs.get_meta("move_speed", 30.0)
				var original_x = obs.get_meta("original_x", obs.global_position.x)
				var max_travel = obs.get_meta("max_travel", 40.0)
				
				obs.global_position.x += dir * speed * delta
				
				var travel = abs(obs.global_position.x - original_x)
				if travel >= max_travel:
					obs.set_meta("move_dir", -dir)

func recycle_objects() -> void:
	if not game_camera:
		return
	
	var recycle_threshold = game_camera.global_position.y - 500
	
	var to_recycle: Array[Node2D] = []
	for obs in active_obstacles:
		if obs.global_position.y < recycle_threshold:
			to_recycle.append(obs)
	
	for obs in to_recycle:
		obs.visible = false
		active_obstacles.erase(obs)
		obstacle_pool.append(obs)
	
	var coins_to_recycle: Array[Area2D] = []
	for coin in active_coins:
		if coin.global_position.y < recycle_threshold:
			coins_to_recycle.append(coin)
	
	for coin in coins_to_recycle:
		coin.visible = false
		active_coins.erase(coin)
		coin_pool.append(coin)
	
	# Clean up old zones
	wind_zones = wind_zones.filter(func(z): return z.end_y > recycle_threshold)
	speed_zones = speed_zones.filter(func(z): return z.end_y > recycle_threshold)

func _on_coin_collected(body: Node2D, coin: Area2D) -> void:
	if body != player or not coin.visible:
		return
	
	var coin_type = coin.get_meta("coin_type", 0)
	
	match coin_type:
		0:  # Normal time coin
			coins_collected += 1
			var bonus_time = randf_range(1.5, 3.0)
			time_remaining += bonus_time
			_spawn_particles(coin.global_position, Color(0.3, 1.0, 1.0))
			_show_time_bonus("+%.1fs" % bonus_time)
		1:  # Shrink power-up
			activate_shrink()
			_spawn_particles(coin.global_position, Color(1.0, 0.4, 0.8))
		2:  # Slow-mo
			activate_slowmo()
			_spawn_particles(coin.global_position, Color(1.0, 0.9, 0.2))
		3:  # Trap coin
			time_remaining -= 3.0
			time_remaining = max(0.1, time_remaining)
			_spawn_particles(coin.global_position, Color(1.0, 0.3, 0.2))
			_show_time_bonus("-3.0s TRAP!")
			if hud:
				hud.trigger_screen_flash(Color(1.0, 0.2, 0.1, 0.4))
	
	coin.visible = false
	active_coins.erase(coin)
	coin_pool.append(coin)
	
	GameManager.play_sound("power_up")

func activate_shrink() -> void:
	is_shrunk = true
	shrink_timer = 5.0
	
	if player:
		var tween = create_tween()
		tween.tween_property(player, "scale", original_player_scale * 0.6, 0.2)
	
	if hud:
		hud.show_combo_word("SHRINK! 5s")

func activate_slowmo() -> void:
	is_slowmo = true
	slowmo_timer = 3.0
	Engine.time_scale = 0.5
	
	if hud:
		hud.show_combo_word("SLOW-MO! 3s")

func _show_time_bonus(text: String) -> void:
	if hud:
		hud.show_combo_word(text)
	
	if timer_label:
		var tween = create_tween()
		tween.tween_property(timer_label, "modulate", Color(0.3, 1.0, 1.0), 0.1)
		tween.tween_property(timer_label, "modulate", Color(1, 1, 1), 0.2)

func _spawn_particles(pos: Vector2, color: Color) -> void:
	for i in range(10):
		var particle = ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.color = color
		particle.pivot_offset = Vector2(3, 3)
		particle.global_position = pos - Vector2(3, 3)
		obstacle_container.add_child(particle)
		
		var angle = (TAU / 10) * i
		var end_pos = particle.global_position + Vector2(cos(angle), sin(angle)) * 40
		
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", end_pos, 0.35)
		tween.tween_property(particle, "modulate:a", 0.0, 0.35)
		tween.chain().tween_callback(particle.queue_free)

func check_checkpoint() -> void:
	if max_depth >= next_checkpoint_depth:
		checkpoints_reached += 1
		time_remaining += time_per_checkpoint
		next_checkpoint_depth += checkpoint_interval
		
		_show_checkpoint_bonus()
		GameManager.play_sound("power_up")

func _show_checkpoint_bonus() -> void:
	if hud:
		hud.show_combo_word("+%.1fs CHECKPOINT!" % time_per_checkpoint)
		hud.trigger_screen_flash(Color(0.2, 1.0, 0.5, 0.3))

func update_timer_display() -> void:
	if timer_label:
		timer_label.text = "%.1f" % time_remaining
		
		if time_remaining <= 3.0:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
			if fmod(time_remaining, 0.5) < 0.25:
				timer_label.modulate = Color(1.2, 0.8, 0.8)
			else:
				timer_label.modulate = Color(1, 1, 1)
		elif time_remaining <= 5.0:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			timer_label.modulate = Color(1, 1, 1)
		else:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
			timer_label.modulate = Color(1, 1, 1)

func update_hud() -> void:
	if hud:
		hud.set_score(score)
		hud.set_distance(max_depth)
		
		# Show current zone/effect
		if is_slowmo:
			hud.set_zone("SLOW-MO")
		elif is_shrunk:
			hud.set_zone("SHRUNK")
		elif current_wind_force != 0:
			hud.set_zone("WIND ZONE")
		elif current_speed_multiplier > 1:
			hud.set_zone("SPEED ZONE")
		elif max_depth >= DEPTH_VISUAL_EFFECTS:
			hud.set_zone("THE DEPTHS")
		else:
			var progress = (max_depth - (next_checkpoint_depth - checkpoint_interval)) / checkpoint_interval
			if progress > 0.8:
				hud.set_zone("CHECKPOINT NEAR!")
			else:
				hud.set_zone("TIME ATTACK")

func _on_time_up() -> void:
	if not is_game_active:
		return
	
	is_game_active = false
	GameManager.is_game_active = false
	Engine.time_scale = 1.0
	
	if game_over_screen:
		game_over_screen.show_game_over(score, max_depth, GameManager.best_score, "DEPTH")

func _on_player_died() -> void:
	if not is_game_active:
		return
	
	is_game_active = false
	GameManager.is_game_active = false
	Engine.time_scale = 1.0
	
	if game_over_screen:
		game_over_screen.show_game_over(score, max_depth, GameManager.best_score, "DEPTH")

func _on_restart() -> void:
	Engine.time_scale = 1.0
	start_game()

func _on_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_menu()
