extends StaticBody2D
class_name Floor

signal floor_crumbled(floor_node: Floor)
signal spring_activated(floor_node: Floor)

enum FloorType {
	NORMAL,
	CRUMBLING,
	MOVING,
	SPRING,
	ICE
}

@export var floor_number: int = 0
@export var floor_width: float = 120.0
@export var floor_type: FloorType = FloorType.NORMAL

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $Visual
@onready var top_edge: ColorRect = $TopEdge if has_node("TopEdge") else null
@onready var highlight: ColorRect = $Highlight if has_node("Highlight") else null
@onready var left_cap: ColorRect = $LeftCap if has_node("LeftCap") else null
@onready var right_cap: ColorRect = $RightCap if has_node("RightCap") else null

# Floor type colors - MORE DISTINCT
const NORMAL_COLOR = Color(0.2, 0.35, 0.55)
const NORMAL_TOP = Color(0.35, 0.55, 0.8)

const CRUMBLING_COLOR = Color(0.6, 0.25, 0.2)      # Red/brown - danger!
const CRUMBLING_TOP = Color(0.8, 0.4, 0.3)

const MOVING_COLOR = Color(0.2, 0.5, 0.6)          # Teal/cyan
const MOVING_TOP = Color(0.3, 0.7, 0.8)

const SPRING_COLOR = Color(0.2, 0.55, 0.25)        # Green - helpful!
const SPRING_TOP = Color(0.4, 0.8, 0.4)

const ICE_COLOR = Color(0.6, 0.85, 0.95)           # Light blue/white
const ICE_TOP = Color(0.8, 0.95, 1.0)

# Moving platform settings
var move_direction: float = 1.0
var move_speed: float = 100.0
var move_range: float = 80.0
var start_x: float = 0.0
var tower_left: float = 20.0
var tower_right: float = 460.0

# Crumbling platform settings
var is_crumbling: bool = false
var crumble_delay: float = 0.5
var player_touched: bool = false

# Spring platform settings
var spring_boost: float = 1.6
var is_spring_compressing: bool = false

# Floor label for milestones
var floor_label: Label = null

func _ready() -> void:
	update_visual()

func _process(delta: float) -> void:
	match floor_type:
		FloorType.MOVING:
			handle_moving(delta)
		FloorType.SPRING:
			animate_spring_idle(delta)
		FloorType.CRUMBLING:
			animate_crumbling_idle(delta)
		FloorType.ICE:
			animate_ice_shimmer(delta)

func setup(number: int, width: float = 120.0, type: FloorType = FloorType.NORMAL) -> void:
	floor_number = number
	floor_width = width
	floor_type = type
	
	# Reset state
	is_crumbling = false
	is_spring_compressing = false
	player_touched = false
	scale = Vector2.ONE
	rotation = 0
	
	# Clean up old label
	if floor_label != null:
		floor_label.queue_free()
		floor_label = null
	
	# Adjust collision shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape = collision_shape.shape.duplicate()
		var shape = collision_shape.shape as RectangleShape2D
		shape.size = Vector2(floor_width, 16)
	
	# Make collision active
	collision_shape.disabled = false
	modulate = Color(1, 1, 1, 1)
	
	# Store start position for moving platforms
	start_x = global_position.x
	move_direction = 1.0 if randf() > 0.5 else -1.0
	
	update_visual()
	
	# Floor label for milestones
	if floor_number > 0 and floor_number % 50 == 0:
		create_floor_label()

func update_visual() -> void:
	var base_color: Color
	var top_color: Color
	
	match floor_type:
		FloorType.NORMAL:
			base_color = NORMAL_COLOR
			top_color = NORMAL_TOP
		FloorType.CRUMBLING:
			base_color = CRUMBLING_COLOR
			top_color = CRUMBLING_TOP
		FloorType.MOVING:
			base_color = MOVING_COLOR
			top_color = MOVING_TOP
		FloorType.SPRING:
			base_color = SPRING_COLOR
			top_color = SPRING_TOP
		FloorType.ICE:
			base_color = ICE_COLOR
			top_color = ICE_TOP
	
	# Milestone coloring overrides
	if floor_number > 0 and floor_number % 50 == 0:
		base_color = Color(0.9, 0.7, 0.2)
		top_color = Color(1.0, 0.85, 0.3)
	elif floor_number > 0 and floor_number % 10 == 0:
		base_color = Color(0.35, 0.65, 0.4)
		top_color = Color(0.5, 0.8, 0.5)
	
	# Update visuals
	if visual:
		visual.size = Vector2(floor_width, 16)
		visual.position = Vector2(-floor_width / 2, -8)
		visual.color = base_color
	
	if top_edge:
		top_edge.size = Vector2(floor_width, 3)
		top_edge.position = Vector2(-floor_width / 2, -8)
		top_edge.color = top_color
	
	if highlight:
		highlight.size = Vector2(floor_width - 4, 1)
		highlight.position = Vector2(-floor_width / 2 + 2, -7)
		highlight.color = Color(top_color.r, top_color.g, top_color.b, 0.6)
	
	if left_cap:
		left_cap.size = Vector2(4, 12)
		left_cap.position = Vector2(-floor_width / 2 - 2, -6)
		left_cap.color = base_color.darkened(0.15)
	
	if right_cap:
		right_cap.size = Vector2(4, 12)
		right_cap.position = Vector2(floor_width / 2 - 2, -6)
		right_cap.color = base_color.darkened(0.15)

# Called by Player when landing on this floor
func on_player_landed(player: Player) -> void:
	if player_touched:
		return  # Already triggered
	
	player_touched = true
	
	match floor_type:
		FloorType.CRUMBLING:
			start_crumble()
		FloorType.SPRING:
			activate_spring(player)

func on_player_left() -> void:
	player_touched = false

# ========== MOVING PLATFORM ==========
func handle_moving(delta: float) -> void:
	global_position.x += move_direction * move_speed * delta
	
	var half_width = floor_width / 2
	if global_position.x - half_width <= tower_left + 5:
		global_position.x = tower_left + half_width + 5
		move_direction = 1.0
	elif global_position.x + half_width >= tower_right - 5:
		global_position.x = tower_right - half_width - 5
		move_direction = -1.0

# ========== CRUMBLING PLATFORM ==========
func start_crumble() -> void:
	if is_crumbling:
		return
	
	is_crumbling = true
	
	# Intense shake effect
	var shake_tween = create_tween()
	for i in range(8):
		var offset = 4 if i % 2 == 0 else -4
		shake_tween.tween_property(self, "position:x", position.x + offset, 0.04)
	shake_tween.tween_property(self, "position:x", position.x, 0.04)
	
	# Flash red warning
	var flash_tween = create_tween()
	flash_tween.set_loops(3)
	flash_tween.tween_property(visual, "color", Color(1, 0.2, 0.2), 0.08)
	flash_tween.tween_property(visual, "color", CRUMBLING_COLOR, 0.08)
	
	# Crumble after delay
	await get_tree().create_timer(crumble_delay).timeout
	crumble()

func crumble() -> void:
	# Disable collision immediately
	collision_shape.disabled = true
	
	# Fall and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 150, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_property(self, "rotation", randf_range(-0.3, 0.3), 0.6)
	
	floor_crumbled.emit(self)

func animate_crumbling_idle(_delta: float) -> void:
	# Subtle wobble to show instability
	if not is_crumbling and visual:
		var wobble = sin(Time.get_ticks_msec() * 0.008) * 0.02
		rotation = wobble

# ========== SPRING PLATFORM ==========
func activate_spring(player: Player) -> void:
	if is_spring_compressing:
		return
	
	is_spring_compressing = true
	
	# Compress and release animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 0.4), 0.06)
	tween.tween_property(self, "scale", Vector2(0.9, 1.4), 0.12).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Super boost the player
	var boost_force = player.base_jump_force * spring_boost * player.combo_jump_multiplier
	player.velocity.y = -boost_force
	
	# Green flash
	if visual:
		var color_tween = create_tween()
		color_tween.tween_property(visual, "color", Color(0.5, 1.0, 0.5), 0.1)
		color_tween.tween_property(visual, "color", SPRING_COLOR, 0.3)
	
	spring_activated.emit(self)
	GameManager.play_sound("jump")
	
	await get_tree().create_timer(0.3).timeout
	is_spring_compressing = false

func animate_spring_idle(_delta: float) -> void:
	# Gentle bounce to show it's bouncy
	if not is_spring_compressing:
		var bounce = sin(Time.get_ticks_msec() * 0.005) * 0.03
		scale.y = 1.0 + bounce

# ========== ICE PLATFORM ==========
func animate_ice_shimmer(_delta: float) -> void:
	# Shimmering effect
	if highlight:
		var shimmer = (sin(Time.get_ticks_msec() * 0.003) + 1) * 0.3 + 0.4
		highlight.color.a = shimmer

func is_ice_platform() -> bool:
	return floor_type == FloorType.ICE

# ========== UTILITIES ==========
func create_floor_label() -> void:
	floor_label = Label.new()
	floor_label.text = str(floor_number)
	floor_label.add_theme_font_size_override("font_size", 24)
	floor_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	floor_label.add_theme_constant_override("outline_size", 4)
	floor_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	floor_label.position = Vector2(floor_width / 2 + 15, -20)
	add_child(floor_label)

func get_floor_width() -> float:
	return floor_width

func set_tower_bounds(left: float, right: float) -> void:
	tower_left = left
	tower_right = right

# ========== MEGA JUMP BREAK ==========
func mega_break() -> void:
	# Already crumbling/broken
	if is_crumbling or collision_shape.disabled:
		return
	
	is_crumbling = true
	collision_shape.disabled = true
	
	# Get platform colors for debris
	var base_color = NORMAL_COLOR
	match floor_type:
		FloorType.CRUMBLING: base_color = CRUMBLING_COLOR
		FloorType.MOVING: base_color = MOVING_COLOR
		FloorType.SPRING: base_color = SPRING_COLOR
		FloorType.ICE: base_color = ICE_COLOR
	
	# Create debris chunks that FLY APART dramatically
	var num_debris = 8
	for i in range(num_debris):
		var debris = ColorRect.new()
		var chunk_width = floor_width / num_debris
		debris.size = Vector2(chunk_width - 4, 14)
		
		# Color variation from platform color
		var color_var = randf_range(-0.1, 0.1)
		debris.color = Color(
			clamp(base_color.r + color_var, 0, 1),
			clamp(base_color.g + color_var, 0, 1),
			clamp(base_color.b + color_var, 0, 1),
			1.0
		)
		debris.pivot_offset = debris.size / 2
		
		# Start position - spread along platform width
		var start_x = -floor_width / 2 + chunk_width * i + chunk_width / 2
		debris.position = global_position + Vector2(start_x, 0) - debris.size / 2
		debris.z_index = 5
		get_parent().add_child(debris)
		
		# Each piece flies in a different direction - spread outward from center
		var spread_direction = (start_x / (floor_width / 2))  # -1 to 1 based on position
		var angle = -PI/2 + spread_direction * PI/3 + randf_range(-0.3, 0.3)  # Fan out upward
		var fly_speed = randf_range(200, 350)
		var end_pos = debris.position + Vector2(cos(angle), sin(angle)) * fly_speed
		
		# Add gravity fall after initial burst
		var gravity_end = end_pos + Vector2(0, randf_range(100, 200))
		
		var tween = get_tree().create_tween()
		# Fast initial burst outward
		tween.tween_property(debris, "position", end_pos, 0.2).set_ease(Tween.EASE_OUT)
		# Then fall with gravity
		tween.tween_property(debris, "position", gravity_end, 0.4).set_ease(Tween.EASE_IN)
		
		# Rotation and fade in parallel
		var spin_tween = get_tree().create_tween()
		spin_tween.set_parallel(true)
		spin_tween.tween_property(debris, "rotation", randf_range(-TAU, TAU), 0.6)
		spin_tween.tween_property(debris, "modulate:a", 0.0, 0.4).set_delay(0.2)
		spin_tween.tween_property(debris, "scale", Vector2(0.5, 0.5), 0.6)
		spin_tween.chain().tween_callback(debris.queue_free)
	
	# Small dust puff at break point
	for i in range(6):
		var dust = ColorRect.new()
		dust.size = Vector2(8, 8)
		dust.color = Color(1, 1, 1, 0.6)
		dust.pivot_offset = Vector2(4, 4)
		dust.position = global_position + Vector2(randf_range(-floor_width/3, floor_width/3), randf_range(-5, 5))
		dust.z_index = 4
		get_parent().add_child(dust)
		
		var dust_end = dust.position + Vector2(randf_range(-30, 30), randf_range(-40, -10))
		var dust_tween = get_tree().create_tween()
		dust_tween.set_parallel(true)
		dust_tween.tween_property(dust, "position", dust_end, 0.3).set_ease(Tween.EASE_OUT)
		dust_tween.tween_property(dust, "modulate:a", 0.0, 0.3)
		dust_tween.tween_property(dust, "scale", Vector2(2, 2), 0.3)
		dust_tween.chain().tween_callback(dust.queue_free)
	
	# Hide the original platform instantly
	modulate.a = 0
	
	floor_crumbled.emit(self)