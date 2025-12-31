extends Area2D
class_name WindZone

signal wind_zone_expired(zone: WindZone)

enum WindDirection { LEFT, RIGHT }

@export var wind_direction: WindDirection = WindDirection.RIGHT
@export var wind_strength: float = 250.0  # Force applied to player
@export var zone_width: float = 440.0     # Full tower width by default
@export var zone_height: float = 400.0    # Height of the wind zone
@export var gusting: bool = false          # Whether wind gusts on/off
@export var gust_on_time: float = 2.0      # Time wind is active
@export var gust_off_time: float = 1.0     # Time wind is inactive
@export var lifetime: float = 0.0          # 0 = infinite

# Visual settings
const WIND_LINE_COLOR_LEFT = Color(0.3, 0.6, 1.0, 0.4)
const WIND_LINE_COLOR_RIGHT = Color(1.0, 0.6, 0.3, 0.4)
const WIND_LINE_COUNT = 20  # More lines for taller zones
const WIND_LINE_SPEED = 450.0

# State
var is_active: bool = true
var player_in_zone: bool = false
var player_ref: Player = null
var gust_timer: float = 0.0
var is_gust_active: bool = true
var lifetime_timer: float = 0.0
var tower_left: float = 20.0
var tower_right: float = 460.0

# Visual elements
var wind_lines: Array[ColorRect] = []
var zone_indicator: ColorRect = null
var direction_arrows: Array[ColorRect] = []

func _ready() -> void:
	# Setup collision shape
	setup_collision()
	
	# Create visual effects
	create_visuals()
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set collision
	collision_layer = 0
	collision_mask = 1  # Detect player (layer 1)

func setup_collision() -> void:
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(zone_width, zone_height)
	collision.shape = shape
	add_child(collision)

func create_visuals() -> void:
	var dir_mult = 1.0 if wind_direction == WindDirection.RIGHT else -1.0
	var wind_color = WIND_LINE_COLOR_RIGHT if wind_direction == WindDirection.RIGHT else WIND_LINE_COLOR_LEFT
	
	# Zone background indicator (subtle)
	zone_indicator = ColorRect.new()
	zone_indicator.size = Vector2(zone_width, zone_height)
	zone_indicator.position = Vector2(-zone_width / 2, -zone_height / 2)
	zone_indicator.color = Color(wind_color.r, wind_color.g, wind_color.b, 0.08)
	zone_indicator.z_index = -5
	add_child(zone_indicator)
	
	# Create animated wind lines
	for i in range(WIND_LINE_COUNT):
		var line = ColorRect.new()
		line.size = Vector2(randf_range(40, 80), 3)
		line.color = wind_color
		line.z_index = -4
		
		# Random starting position within zone
		var start_x = randf_range(-zone_width / 2, zone_width / 2)
		var start_y = randf_range(-zone_height / 2, zone_height / 2)
		line.position = Vector2(start_x, start_y)
		
		add_child(line)
		wind_lines.append(line)
	
	# Direction arrows (static indicators) - scale count with zone height
	var arrow_count = max(3, int(zone_height / 200))  # One arrow every ~200 pixels
	for i in range(arrow_count):
		var arrow = create_arrow(dir_mult)
		var y_pos = -zone_height / 2 + (zone_height / (arrow_count + 1)) * (i + 1)
		arrow.position = Vector2(0, y_pos)
		add_child(arrow)
		direction_arrows.append(arrow)

func create_arrow(direction: float) -> ColorRect:
	var arrow = ColorRect.new()
	arrow.size = Vector2(20, 8)
	arrow.color = Color(1, 1, 1, 0.15)
	arrow.pivot_offset = Vector2(10, 4)
	if direction < 0:
		arrow.rotation = PI  # Point left
	arrow.z_index = -4
	return arrow

func _process(delta: float) -> void:
	# Handle gusting
	if gusting:
		gust_timer += delta
		if is_gust_active and gust_timer >= gust_on_time:
			is_gust_active = false
			gust_timer = 0.0
			update_gust_visual()
		elif not is_gust_active and gust_timer >= gust_off_time:
			is_gust_active = true
			gust_timer = 0.0
			update_gust_visual()
	
	# Handle lifetime
	if lifetime > 0:
		lifetime_timer += delta
		if lifetime_timer >= lifetime:
			expire()
			return
	
	# Animate wind lines
	animate_wind_lines(delta)
	
	# Apply wind force to player if in zone and wind is active
	if player_in_zone and player_ref and is_active and (not gusting or is_gust_active):
		apply_wind_force(delta)

func animate_wind_lines(delta: float) -> void:
	var dir_mult = 1.0 if wind_direction == WindDirection.RIGHT else -1.0
	var alpha_mult = 1.0 if (not gusting or is_gust_active) else 0.3
	
	for line in wind_lines:
		# Move in wind direction
		line.position.x += WIND_LINE_SPEED * dir_mult * delta
		
		# Update alpha based on gust state
		var base_alpha = 0.4 if wind_direction == WindDirection.RIGHT else 0.4
		line.color.a = base_alpha * alpha_mult
		
		# Wrap around when leaving zone
		var half_width = zone_width / 2
		if dir_mult > 0 and line.position.x > half_width:
			line.position.x = -half_width - line.size.x
			line.position.y = randf_range(-zone_height / 2, zone_height / 2)
			line.size.x = randf_range(40, 80)
		elif dir_mult < 0 and line.position.x < -half_width - line.size.x:
			line.position.x = half_width
			line.position.y = randf_range(-zone_height / 2, zone_height / 2)
			line.size.x = randf_range(40, 80)

func update_gust_visual() -> void:
	var target_alpha = 0.08 if is_gust_active else 0.02
	var tween = create_tween()
	tween.tween_property(zone_indicator, "color:a", target_alpha, 0.3)
	
	# Also fade arrows
	for arrow in direction_arrows:
		var arrow_tween = create_tween()
		var arrow_alpha = 0.15 if is_gust_active else 0.05
		arrow_tween.tween_property(arrow, "color:a", arrow_alpha, 0.3)

func apply_wind_force(delta: float) -> void:
	if not player_ref:
		return
	
	var dir_mult = 1.0 if wind_direction == WindDirection.RIGHT else -1.0
	var force = wind_strength * dir_mult
	
	# Apply more force when player is in the air (wind affects airborne more)
	if not player_ref.is_on_floor():
		force *= 1.5
	
	# Add to player's velocity
	player_ref.velocity.x += force * delta

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_zone = true
		player_ref = body
		
		# Visual feedback - brighten zone
		var tween = create_tween()
		tween.tween_property(zone_indicator, "color:a", 0.15, 0.2)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_zone = false
		player_ref = null
		
		# Visual feedback - dim zone
		var tween = create_tween()
		var target_alpha = 0.08 if is_gust_active else 0.02
		tween.tween_property(zone_indicator, "color:a", target_alpha, 0.2)

func setup(pos: Vector2, dir: WindDirection, strength: float = 250.0, height: float = 400.0, is_gusting: bool = false, life: float = 0.0) -> void:
	global_position = pos
	wind_direction = dir
	wind_strength = strength
	zone_height = height
	gusting = is_gusting
	lifetime = life
	
	# Recreate visuals with new settings
	for line in wind_lines:
		line.queue_free()
	wind_lines.clear()
	
	for arrow in direction_arrows:
		arrow.queue_free()
	direction_arrows.clear()
	
	if zone_indicator:
		zone_indicator.queue_free()
	
	# Rebuild collision
	for child in get_children():
		if child is CollisionShape2D:
			child.queue_free()
	
	setup_collision()
	create_visuals()

func set_tower_bounds(left: float, right: float) -> void:
	tower_left = left
	tower_right = right
	zone_width = right - left

func expire() -> void:
	is_active = false
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		wind_zone_expired.emit(self)
		queue_free()
	)

func get_wind_force() -> Vector2:
	if not is_active or (gusting and not is_gust_active):
		return Vector2.ZERO
	
	var dir_mult = 1.0 if wind_direction == WindDirection.RIGHT else -1.0
	return Vector2(wind_strength * dir_mult, 0)

