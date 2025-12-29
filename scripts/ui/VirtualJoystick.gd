extends Control
class_name VirtualJoystick

signal joystick_input(direction: Vector2)
signal joystick_released
signal jump_triggered

@export_group("Joystick Settings")
@export var joystick_radius: float = 80.0  # Outer ring radius
@export var knob_radius: float = 35.0      # Inner knob radius
@export var dead_zone: float = 0.15        # Dead zone threshold
@export var jump_threshold: float = 0.5    # How far up to trigger jump
@export var follow_finger: bool = true     # Joystick follows finger when dragged far
@export var return_speed: float = 15.0     # How fast knob returns to center

@export_group("Visual Settings")
@export var base_color: Color = Color(1, 1, 1, 0.15)
@export var knob_color: Color = Color(1, 1, 1, 0.4)
@export var active_color: Color = Color(0.4, 0.8, 1.0, 0.6)
@export var jump_color: Color = Color(0.4, 1.0, 0.5, 0.7)
@export var outline_color: Color = Color(1, 1, 1, 0.3)

# Internal state
var touch_index: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var knob_position: Vector2 = Vector2.ZERO
var current_output: Vector2 = Vector2.ZERO
var is_active: bool = false
var original_position: Vector2 = Vector2.ZERO
var can_jump: bool = true  # Prevents repeated jumps while holding up
var is_jump_zone: bool = false  # Visual feedback for jump zone

# Visual elements
var base_ring: Control
var knob: Control
var jump_indicator: Control

func _ready() -> void:
	original_position = position
	joystick_center = size / 2
	knob_position = joystick_center
	
	create_visuals()
	set_process(true)

func create_visuals() -> void:
	# Base ring (outer circle)
	base_ring = Control.new()
	base_ring.name = "BaseRing"
	base_ring.custom_minimum_size = Vector2(joystick_radius * 2, joystick_radius * 2)
	base_ring.size = base_ring.custom_minimum_size
	base_ring.position = joystick_center - Vector2(joystick_radius, joystick_radius)
	add_child(base_ring)
	base_ring.draw.connect(_draw_base_ring)
	
	# Jump zone indicator (top arc)
	jump_indicator = Control.new()
	jump_indicator.name = "JumpIndicator"
	jump_indicator.custom_minimum_size = Vector2(joystick_radius * 2, joystick_radius * 2)
	jump_indicator.size = jump_indicator.custom_minimum_size
	jump_indicator.position = joystick_center - Vector2(joystick_radius, joystick_radius)
	add_child(jump_indicator)
	jump_indicator.draw.connect(_draw_jump_indicator)
	
	# Knob (inner circle)
	knob = Control.new()
	knob.name = "Knob"
	knob.custom_minimum_size = Vector2(knob_radius * 2, knob_radius * 2)
	knob.size = knob.custom_minimum_size
	knob.position = joystick_center - Vector2(knob_radius, knob_radius)
	knob.pivot_offset = Vector2(knob_radius, knob_radius)
	add_child(knob)
	knob.draw.connect(_draw_knob)

func _draw_base_ring() -> void:
	var center = Vector2(joystick_radius, joystick_radius)
	var color = active_color if is_active else base_color
	if is_jump_zone:
		color = jump_color
	
	# Outer ring fill
	base_ring.draw_circle(center, joystick_radius, Color(color.r, color.g, color.b, color.a * 0.3))
	
	# Outer ring border
	var segments = 64
	var prev_point = center + Vector2(joystick_radius - 2, 0)
	for i in range(1, segments + 1):
		var angle = (float(i) / segments) * TAU
		var point = center + Vector2(cos(angle), sin(angle)) * (joystick_radius - 2)
		base_ring.draw_line(prev_point, point, outline_color, 3.0, true)
		prev_point = point
	
	# Inner circle guide (center marker)
	base_ring.draw_circle(center, 8, Color(1, 1, 1, 0.15))
	
	# Direction arrows
	var arrow_color = Color(1, 1, 1, 0.25) if not is_active else Color(1, 1, 1, 0.4)
	var arrow_dist = joystick_radius * 0.65
	var arrow_size = 10.0
	
	# Left arrow
	_draw_arrow_on(base_ring, center + Vector2(-arrow_dist, 0), Vector2.LEFT, arrow_size, arrow_color)
	# Right arrow  
	_draw_arrow_on(base_ring, center + Vector2(arrow_dist, 0), Vector2.RIGHT, arrow_size, arrow_color)
	# Up arrow (jump indicator)
	var up_color = jump_color if is_jump_zone else arrow_color
	_draw_arrow_on(base_ring, center + Vector2(0, -arrow_dist), Vector2.UP, arrow_size * 1.2, up_color)

func _draw_arrow_on(target: Control, pos: Vector2, dir: Vector2, arrow_size: float, color: Color) -> void:
	var tip = pos + dir * arrow_size
	var base1 = pos + dir.rotated(2.3) * arrow_size * 0.6
	var base2 = pos + dir.rotated(-2.3) * arrow_size * 0.6
	target.draw_polygon([tip, base1, base2], [color])

func _draw_jump_indicator() -> void:
	if not is_active:
		return
	
	var center = Vector2(joystick_radius, joystick_radius)
	
	# Draw jump zone arc at top
	var jump_zone_color = jump_color if is_jump_zone else Color(0.4, 1.0, 0.5, 0.2)
	var arc_radius = joystick_radius - 5
	
	# Arc from -120 to -60 degrees (top portion)
	jump_indicator.draw_arc(center, arc_radius, deg_to_rad(-120), deg_to_rad(-60), 24, jump_zone_color, 4.0, true)

func _draw_knob() -> void:
	var center = Vector2(knob_radius, knob_radius)
	var color = knob_color
	if is_active:
		color = jump_color if is_jump_zone else active_color
	
	# Knob shadow
	knob.draw_circle(center + Vector2(2, 2), knob_radius - 2, Color(0, 0, 0, 0.3))
	
	# Knob fill
	knob.draw_circle(center, knob_radius - 2, color)
	
	# Knob highlight
	knob.draw_circle(center - Vector2(knob_radius * 0.3, knob_radius * 0.3), knob_radius * 0.25, Color(1, 1, 1, 0.35))
	
	# Knob border
	var segments = 32
	var prev_point = center + Vector2(knob_radius - 2, 0)
	var border_color = Color(1, 1, 1, 0.6) if is_active else Color(1, 1, 1, 0.3)
	for i in range(1, segments + 1):
		var angle = (float(i) / segments) * TAU
		var point = center + Vector2(cos(angle), sin(angle)) * (knob_radius - 2)
		knob.draw_line(prev_point, point, border_color, 2.0, true)
		prev_point = point

func _process(delta: float) -> void:
	if not is_active:
		# Smoothly return knob to center
		knob_position = knob_position.lerp(joystick_center, delta * return_speed)
		update_knob_visual()
		
		# Reset output when not active
		if current_output != Vector2.ZERO:
			current_output = current_output.lerp(Vector2.ZERO, delta * return_speed)
			if current_output.length() < 0.01:
				current_output = Vector2.ZERO
			joystick_input.emit(current_output)
		
		# Reset jump state
		can_jump = true
		if is_jump_zone:
			is_jump_zone = false
			queue_redraw_all()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch = event as InputEventScreenTouch
		
		if touch.pressed:
			# Check if touch is within our area
			var local_pos = get_local_touch_position(touch.position)
			if is_touch_in_joystick_area(local_pos):
				touch_index = touch.index
				is_active = true
				can_jump = true  # Reset jump ability on new touch
				handle_touch_position(local_pos)
				queue_redraw_all()
		else:
			if touch.index == touch_index:
				release_joystick()
	
	elif event is InputEventScreenDrag:
		var drag = event as InputEventScreenDrag
		if drag.index == touch_index and is_active:
			var local_pos = get_local_touch_position(drag.position)
			handle_touch_position(local_pos)

func get_local_touch_position(screen_pos: Vector2) -> Vector2:
	return screen_pos - global_position

func is_touch_in_joystick_area(local_pos: Vector2) -> bool:
	# Check if within the overall control bounds with generous padding
	var expanded_size = size + Vector2(60, 60)
	var expanded_rect = Rect2(-Vector2(30, 30), expanded_size)
	return expanded_rect.has_point(local_pos)

func handle_touch_position(local_pos: Vector2) -> void:
	var delta_from_center = local_pos - joystick_center
	var distance = delta_from_center.length()
	
	# Clamp to joystick radius
	if distance > joystick_radius:
		if follow_finger:
			# Move the joystick center to follow finger
			var overflow = distance - joystick_radius
			joystick_center += delta_from_center.normalized() * overflow * 0.5
			delta_from_center = local_pos - joystick_center
			distance = delta_from_center.length()
		else:
			delta_from_center = delta_from_center.normalized() * joystick_radius
			distance = joystick_radius
	
	knob_position = joystick_center + delta_from_center
	
	# Calculate normalized output (-1 to 1)
	var normalized_distance = distance / joystick_radius
	
	if normalized_distance < dead_zone:
		current_output = Vector2.ZERO
	else:
		# Remap from dead_zone..1 to 0..1
		var remapped = (normalized_distance - dead_zone) / (1.0 - dead_zone)
		current_output = delta_from_center.normalized() * remapped
	
	# Check for jump (upward movement)
	var was_jump_zone = is_jump_zone
	is_jump_zone = current_output.y < -jump_threshold
	
	if is_jump_zone and can_jump:
		# Trigger jump!
		jump_triggered.emit()
		can_jump = false  # Prevent repeated jumps until release or move down
	elif current_output.y > -jump_threshold * 0.5:
		# Allow jump again when user moves knob back down
		can_jump = true
	
	# Update visuals if jump zone changed
	if was_jump_zone != is_jump_zone:
		queue_redraw_all()
	
	update_knob_visual()
	joystick_input.emit(current_output)

func update_knob_visual() -> void:
	if knob:
		knob.position = knob_position - Vector2(knob_radius, knob_radius)
		
		# Scale knob slightly when active
		var target_scale = Vector2(1.1, 1.1) if is_active else Vector2(1.0, 1.0)
		knob.scale = knob.scale.lerp(target_scale, 0.2)
		knob.queue_redraw()
		
	if base_ring:
		base_ring.position = joystick_center - Vector2(joystick_radius, joystick_radius)
		
	if jump_indicator:
		jump_indicator.position = joystick_center - Vector2(joystick_radius, joystick_radius)

func release_joystick() -> void:
	touch_index = -1
	is_active = false
	is_jump_zone = false
	joystick_center = size / 2  # Reset center
	can_jump = true
	joystick_released.emit()
	queue_redraw_all()

func queue_redraw_all() -> void:
	if base_ring:
		base_ring.queue_redraw()
	if knob:
		knob.queue_redraw()
	if jump_indicator:
		jump_indicator.queue_redraw()

func get_output() -> Vector2:
	return current_output

func get_horizontal_output() -> float:
	return current_output.x
