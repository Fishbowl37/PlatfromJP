extends Node2D

# Free Fall Mode - TIME ATTACK!
# Fall as deep as possible before time runs out.
# Collect coins and reach checkpoints to add time!

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
@export var starting_time: float = 15.0        # Start with 15 seconds
@export var time_per_coin: float = 1.5         # Each coin adds 1.5 seconds
@export var checkpoint_interval: float = 800.0  # Checkpoint every 800m
@export var time_per_checkpoint: float = 5.0   # Each checkpoint adds 5 seconds

# Obstacle settings
@export var obstacle_pool_size: int = 20
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

# Rescue coin (special coin when time is critical)
var rescue_coin: Area2D = null
var rescue_coin_cooldown: float = 0.0  # Cooldown timer before next rescue coin can spawn
@export var rescue_coin_time: float = 5.0      # Time bonus from rescue coin
@export var rescue_coin_cooldown_time: float = 7.0  # Seconds before next rescue coin can spawn

# Difficulty
var difficulty_level: int = 0

# UI elements
var menu_button: Button = null
var timer_label: Label = null

func _ready() -> void:
	setup_game()
	create_obstacle_pool()
	create_coin_pool()
	create_rescue_coin()
	create_menu_button()
	create_timer_display()
	
	if player:
		player.player_died.connect(_on_player_died)
	
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

func create_timer_display() -> void:
	# Big timer display at top center
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	
	# Timer background - positioned below top bar (which ends at y=58)
	var timer_bg = ColorRect.new()
	timer_bg.color = Color(0.1, 0.05, 0.02, 0.9)
	timer_bg.size = Vector2(120, 50)
	timer_bg.position = Vector2(180, 65)
	ui_layer.add_child(timer_bg)
	
	# Timer border
	var timer_border = ColorRect.new()
	timer_border.color = Color(1.0, 0.6, 0.2, 0.8)
	timer_border.size = Vector2(124, 54)
	timer_border.position = Vector2(178, 63)
	timer_border.z_index = -1
	ui_layer.add_child(timer_border)
	
	# Timer label
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

func _setup_obstacle(obstacle: StaticBody2D, width: float) -> void:
	var collision = obstacle.get_child(0) as CollisionShape2D
	if collision and collision.shape is RectangleShape2D:
		collision.shape.size = Vector2(width, 20)
	
	var visual = obstacle.get_node("Visual") as ColorRect
	var top_edge = obstacle.get_node("TopEdge") as ColorRect
	
	if visual:
		visual.size = Vector2(width, 20)
		visual.position = Vector2(-width / 2, -10)
		var intensity = (width - base_obstacle_width) / (max_obstacle_width - base_obstacle_width)
		visual.color = Color(0.5 + intensity * 0.2, 0.2 - intensity * 0.05, 0.15 - intensity * 0.05)
	
	if top_edge:
		top_edge.size = Vector2(width, 4)
		top_edge.position = Vector2(-width / 2, -10)
		var intensity = (width - base_obstacle_width) / (max_obstacle_width - base_obstacle_width)
		top_edge.color = Color(0.8 + intensity * 0.15, 0.35 - intensity * 0.1, 0.25 - intensity * 0.1)

func create_coin_pool() -> void:
	for i in range(20):
		var coin = _create_coin()
		coin.visible = false
		obstacle_container.add_child(coin)
		coin_pool.append(coin)

func _create_coin() -> Area2D:
	var coin = Area2D.new()
	coin.collision_layer = 0
	coin.collision_mask = 1
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 28  # Larger collision area for easier collection
	collision.shape = shape
	coin.add_child(collision)
	
	# Clock/time coin visual
	var outer = Polygon2D.new()
	var points: PackedVector2Array = []
	for j in range(12):
		var angle = (TAU / 12) * j
		points.append(Vector2(cos(angle), sin(angle)) * 14)
	outer.polygon = points
	outer.color = Color(0.2, 0.9, 1.0)  # Cyan for time
	coin.add_child(outer)
	
	var inner = Polygon2D.new()
	var inner_points: PackedVector2Array = []
	for j in range(8):
		var angle = (TAU / 8) * j
		inner_points.append(Vector2(cos(angle), sin(angle)) * 8)
	inner.polygon = inner_points
	inner.color = Color(0.5, 1.0, 1.0)
	coin.add_child(inner)
	
	# Plus sign to indicate +time
	var plus_h = ColorRect.new()
	plus_h.size = Vector2(8, 2)
	plus_h.position = Vector2(-4, -1)
	plus_h.color = Color(1, 1, 1)
	coin.add_child(plus_h)
	
	var plus_v = ColorRect.new()
	plus_v.size = Vector2(2, 8)
	plus_v.position = Vector2(-1, -4)
	plus_v.color = Color(1, 1, 1)
	coin.add_child(plus_v)
	
	coin.body_entered.connect(_on_coin_collected.bind(coin))
	return coin

func create_rescue_coin() -> void:
	# Special golden rescue coin - appears when time is critical
	rescue_coin = Area2D.new()
	rescue_coin.collision_layer = 0
	rescue_coin.collision_mask = 1
	rescue_coin.visible = false
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 35  # Larger collision for easy pickup
	collision.shape = shape
	rescue_coin.add_child(collision)
	
	# Outer glow ring
	var glow = Polygon2D.new()
	var glow_points: PackedVector2Array = []
	for j in range(16):
		var angle = (TAU / 16) * j
		glow_points.append(Vector2(cos(angle), sin(angle)) * 24)
	glow.polygon = glow_points
	glow.color = Color(1.0, 0.8, 0.2, 0.4)
	glow.name = "Glow"
	rescue_coin.add_child(glow)
	
	# Main coin body - golden
	var outer = Polygon2D.new()
	var points: PackedVector2Array = []
	for j in range(12):
		var angle = (TAU / 12) * j
		points.append(Vector2(cos(angle), sin(angle)) * 18)
	outer.polygon = points
	outer.color = Color(1.0, 0.85, 0.2)
	rescue_coin.add_child(outer)
	
	# Inner shine
	var inner = Polygon2D.new()
	var inner_points: PackedVector2Array = []
	for j in range(8):
		var angle = (TAU / 8) * j
		inner_points.append(Vector2(cos(angle), sin(angle)) * 10)
	inner.polygon = inner_points
	inner.color = Color(1.0, 0.95, 0.5)
	rescue_coin.add_child(inner)
	
	# "+5" text indicator
	var plus_label = Label.new()
	plus_label.text = "+5"
	plus_label.position = Vector2(-12, -10)
	plus_label.add_theme_font_size_override("font_size", 14)
	plus_label.add_theme_color_override("font_color", Color(0.3, 0.15, 0.0))
	rescue_coin.add_child(plus_label)
	
	rescue_coin.body_entered.connect(_on_rescue_coin_collected)
	obstacle_container.add_child(rescue_coin)

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
	
	# Reset player
	if player:
		var center_x = tower_left_margin + tower_width / 2.0
		player.global_position = Vector2(center_x, 100)
		player.velocity = Vector2.ZERO
		player.modulate.a = 1.0
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
	
	next_obstacle_y = 350.0
	
	# Reset rescue coin state
	rescue_coin_cooldown = 0.0
	if rescue_coin:
		rescue_coin.visible = false
	
	GameManager.is_game_active = true
	GameManager.current_score = 0
	
	if hud:
		hud.reset()
		hud.set_zone("TIME ATTACK")
	
	update_timer_display()

func _physics_process(delta: float) -> void:
	if not is_game_active:
		return
	
	# Count down timer
	time_remaining -= delta
	if time_remaining <= 0:
		time_remaining = 0
		_on_time_up()
		return
	
	# Update difficulty based on depth
	update_difficulty()
	
	# Track depth
	if player:
		depth_reached = max(0.0, (player.global_position.y - start_y) / 10.0)
		if depth_reached > max_depth:
			max_depth = depth_reached
		
		# Check for checkpoint
		check_checkpoint()
		
		# Calculate score
		score = int(max_depth * 3) + coins_collected * 20 + checkpoints_reached * 100
		GameManager.current_score = score
		GameManager.current_distance = max_depth
	
	# Update camera
	update_camera(delta)
	
	# Check for rescue coin spawn
	check_rescue_coin()
	
	# Spawn obstacles
	spawn_obstacles()
	
	# Update moving obstacles
	update_moving_obstacles(delta)
	
	# Recycle off-screen objects
	recycle_objects()
	
	# Update displays
	update_timer_display()
	update_hud()

func check_checkpoint() -> void:
	if max_depth >= next_checkpoint_depth:
		checkpoints_reached += 1
		time_remaining += time_per_checkpoint
		next_checkpoint_depth += checkpoint_interval
		
		# Visual/audio feedback
		_show_checkpoint_bonus()
		GameManager.play_sound("power_up")

func _show_checkpoint_bonus() -> void:
	if hud:
		hud.show_combo_word("+%.1fs CHECKPOINT!" % time_per_checkpoint)
		hud.trigger_screen_flash(Color(0.2, 1.0, 0.5, 0.3))

func check_rescue_coin() -> void:
	if not player:
		return
	
	# Decrease cooldown
	if rescue_coin_cooldown > 0:
		rescue_coin_cooldown -= get_physics_process_delta_time()
	
	# Only spawn if: time is below 5 sec AND cooldown has passed AND rescue coin isn't already visible
	if time_remaining < 5.0 and rescue_coin_cooldown <= 0 and not rescue_coin.visible:
		spawn_rescue_coin()

func spawn_rescue_coin() -> void:
	if not rescue_coin or rescue_coin.visible:
		return
	
	# Start cooldown for next rescue coin
	rescue_coin_cooldown = rescue_coin_cooldown_time
	
	# Spawn ahead of the player
	var spawn_y = player.global_position.y + 300
	var spawn_x = randf_range(tower_left_margin + 40, tower_left_margin + tower_width - 40)
	
	rescue_coin.global_position = Vector2(spawn_x, spawn_y)
	rescue_coin.visible = true
	
	# Pulse animation for the glow
	var glow = rescue_coin.get_node_or_null("Glow")
	if glow:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(glow, "modulate:a", 0.5, 0.3)
		tween.tween_property(glow, "modulate:a", 1.0, 0.3)
	
	# Show alert
	if hud:
		hud.show_combo_word("RESCUE COIN!")
		hud.trigger_screen_flash(Color(1.0, 0.85, 0.2, 0.3))

func _on_rescue_coin_collected(body: Node2D) -> void:
	if body != player or not rescue_coin.visible:
		return
	
	time_remaining += rescue_coin_time
	rescue_coin.visible = false
	
	# Big celebration effect
	_spawn_rescue_particles(rescue_coin.global_position)
	
	if hud:
		hud.show_combo_word("+%.0fs RESCUED!" % rescue_coin_time)
		hud.trigger_screen_flash(Color(1.0, 0.9, 0.3, 0.4))
	
	# Flash the timer gold
	if timer_label:
		var tween = create_tween()
		tween.tween_property(timer_label, "modulate", Color(1.0, 0.85, 0.2), 0.15)
		tween.tween_property(timer_label, "modulate", Color(1, 1, 1), 0.3)
	
	GameManager.play_sound("power_up")

func _spawn_rescue_particles(pos: Vector2) -> void:
	for i in range(16):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = Color(1.0, 0.85, 0.2, 1.0)
		particle.pivot_offset = Vector2(4, 4)
		particle.global_position = pos - Vector2(4, 4)
		obstacle_container.add_child(particle)
		
		var angle = (TAU / 16) * i
		var end_pos = particle.global_position + Vector2(cos(angle), sin(angle)) * 60
		
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", end_pos, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.5)
		tween.chain().tween_callback(particle.queue_free)

func update_difficulty() -> void:
	var new_level = int(max_depth / 80)
	if new_level > difficulty_level:
		difficulty_level = new_level

func update_camera(delta: float) -> void:
	if not game_camera or not player:
		return
	
	var target_y = player.global_position.y + 80
	game_camera.global_position.y = lerp(game_camera.global_position.y, target_y, 6 * delta)
	game_camera.global_position.x = tower_left_margin + tower_width / 2.0

func spawn_obstacles() -> void:
	if not player:
		return
	
	var spawn_threshold = player.global_position.y + 600
	
	while next_obstacle_y < spawn_threshold and obstacle_pool.size() > 0:
		var obstacle = obstacle_pool.pop_back()
		
		# Width increases with difficulty
		var width_bonus = difficulty_level * 12.0
		var width = randf_range(base_obstacle_width, base_obstacle_width + 50.0) + width_bonus
		width = clamp(width, base_obstacle_width, max_obstacle_width)
		
		_setup_obstacle(obstacle, width)
		
		# Moving obstacles
		var is_moving = difficulty_level >= 2 and randf() < 0.25
		obstacle.set_meta("moving", is_moving)
		obstacle.set_meta("move_dir", 1.0 if randf() > 0.5 else -1.0)
		
		var max_x = tower_left_margin + tower_width - width / 2 - 15
		var min_x = tower_left_margin + width / 2 + 15
		var x_pos = randf_range(min_x, max_x)
		
		obstacle.global_position = Vector2(x_pos, next_obstacle_y)
		obstacle.visible = true
		active_obstacles.append(obstacle)
		
		# Spawn time coins more frequently - they're important!
		if randf() < 0.45 and coin_pool.size() > 0:
			var coin = coin_pool.pop_back()
			var coin_x = randf_range(tower_left_margin + 25, tower_left_margin + tower_width - 25)
			coin.global_position = Vector2(coin_x, next_obstacle_y - 50)
			coin.visible = true
			active_coins.append(coin)
		
		var spacing = randf_range(min_obstacle_spacing, max_obstacle_spacing)
		spacing = max(140, spacing - difficulty_level * 8)
		next_obstacle_y += spacing

func update_moving_obstacles(delta: float) -> void:
	for obs in active_obstacles:
		if obs.get_meta("moving", false):
			var dir = obs.get_meta("move_dir", 1.0)
			var speed = 50.0 + difficulty_level * 5
			obs.global_position.x += dir * speed * delta
			
			var collision = obs.get_child(0) as CollisionShape2D
			var half_width = 50.0
			if collision and collision.shape is RectangleShape2D:
				half_width = collision.shape.size.x / 2
			
			if obs.global_position.x - half_width < tower_left_margin + 5:
				obs.set_meta("move_dir", 1.0)
			elif obs.global_position.x + half_width > tower_left_margin + tower_width - 5:
				obs.set_meta("move_dir", -1.0)

func recycle_objects() -> void:
	if not game_camera:
		return
	
	var recycle_threshold = game_camera.global_position.y - 400
	
	var to_recycle: Array[Node2D] = []
	for obs in active_obstacles:
		if obs.global_position.y < recycle_threshold:
			to_recycle.append(obs)
	
	for obs in to_recycle:
		obs.visible = false
		obs.set_meta("moving", false)
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

func _on_coin_collected(body: Node2D, coin: Area2D) -> void:
	if body != player or not coin.visible:
		return
	
	coins_collected += 1
	time_remaining += time_per_coin
	
	coin.visible = false
	active_coins.erase(coin)
	coin_pool.append(coin)
	
	_spawn_time_particles(coin.global_position)
	_show_time_bonus()
	GameManager.play_sound("power_up")

func _show_time_bonus() -> void:
	# Flash the timer
	if timer_label:
		var tween = create_tween()
		tween.tween_property(timer_label, "modulate", Color(0.3, 1.0, 1.0), 0.1)
		tween.tween_property(timer_label, "modulate", Color(1, 1, 1), 0.2)

func _spawn_time_particles(pos: Vector2) -> void:
	for i in range(10):
		var particle = ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.color = Color(0.3, 1.0, 1.0, 0.9)
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

func update_timer_display() -> void:
	if timer_label:
		timer_label.text = "%.1f" % time_remaining
		
		# Color based on time remaining
		if time_remaining <= 3.0:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
			# Pulse when critical
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
		
		# Show checkpoint progress
		var progress_to_next = (max_depth - (next_checkpoint_depth - checkpoint_interval)) / checkpoint_interval
		if progress_to_next > 0.8:
			hud.set_zone("CHECKPOINT NEAR!")
		else:
			hud.set_zone("TIME ATTACK")

func _on_time_up() -> void:
	if not is_game_active:
		return
	
	is_game_active = false
	GameManager.is_game_active = false
	
	if game_over_screen:
		game_over_screen.show_game_over(score, max_depth, GameManager.best_score, "DEPTH")

func _on_player_died() -> void:
	if not is_game_active:
		return
	
	is_game_active = false
	GameManager.is_game_active = false
	
	if game_over_screen:
		game_over_screen.show_game_over(score, max_depth, GameManager.best_score, "DEPTH")

func _on_restart() -> void:
	start_game()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_menu()
