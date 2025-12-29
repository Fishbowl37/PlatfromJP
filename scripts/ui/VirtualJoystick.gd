extends Control
class_name VirtualJoystick

signal joystick_input(direction: Vector2)
signal joystick_released
signal jump_triggered

@export_group("Joystick Settings")
@export var max_drag_distance: float = 60.0  # How far to drag for full input
@export var dead_zone: float = 12.0          # Pixels of dead zone
@export var jump_threshold: float = 0.5      # How far up to trigger jump (0-1)

@export_group("Visual Feedback")
@export var show_touch_indicator: bool = true
@export var indicator_color: Color = Color(1, 1, 1, 0.3)
@export var active_color: Color = Color(0.5, 0.9, 1.0, 0.5)
@export var jump_color: Color = Color(0.4, 1.0, 0.5, 0.6)

# Internal state
var touch_index: int = -1
var touch_start_position: Vector2 = Vector2.ZERO
var current_touch_position: Vector2 = Vector2.ZERO
var current_output: Vector2 = Vector2.ZERO
var is_active: bool = false
var can_jump: bool = true
var is_in_jump_zone: bool = false

# Visual elements (subtle indicators)
var touch_indicator: Control = null
var direction_line: Control = null

func _ready() -> void:
	# Make this control fill the touch area
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	if show_touch_indicator:
		create_touch_indicator()
	
	set_process(true)

func create_touch_indicator() -> void:
	# Small circle showing where you touched
	touch_indicator = Control.new()
	touch_indicator.name = "TouchIndicator"
	touch_indicator.custom_minimum_size = Vector2(120, 120)
	touch_indicator.size = touch_indicator.custom_minimum_size
	touch_indicator.visible = false
	touch_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(touch_indicator)
	touch_indicator.draw.connect(_draw_touch_indicator)
	
	# Line showing drag direction
	direction_line = Control.new()
	direction_line.name = "DirectionLine"
	direction_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	direction_line.visible = false
	direction_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(direction_line)
	direction_line.draw.connect(_draw_direction_line)

func _draw_touch_indicator() -> void:
	var center = Vector2(60, 60)
	var color = indicator_color
	if is_in_jump_zone:
		color = jump_color
	elif is_active:
		color = active_color
	
	# Outer ring
	touch_indicator.draw_arc(center, 50, 0, TAU, 48, Color(color.r, color.g, color.b, color.a * 0.5), 2.0, true)
	
	# Inner dot (start position)
	touch_indicator.draw_circle(center, 8, Color(color.r, color.g, color.b, color.a * 0.7))
	
	# Up arrow hint
	var arrow_color = jump_color if is_in_jump_zone else Color(1, 1, 1, 0.25)
	var arrow_center = center + Vector2(0, -35)
	touch_indicator.draw_polygon([
		arrow_center + Vector2(0, -8),
		arrow_center + Vector2(-6, 2),
		arrow_center + Vector2(6, 2)
	], [arrow_color])

func _draw_direction_line() -> void:
	if not is_active:
		return
	
	var color = active_color
	if is_in_jump_zone:
		color = jump_color
	
	# Draw line from start to current
	var delta = current_touch_position - touch_start_position
	if delta.length() > dead_zone:
		# Knob position (clamped)
		var clamped_delta = delta
		if delta.length() > max_drag_distance:
			clamped_delta = delta.normalized() * max_drag_distance
		
		var knob_pos = touch_start_position + clamped_delta
		
		# Draw the knob
		direction_line.draw_circle(knob_pos, 22, color)
		direction_line.draw_arc(knob_pos, 22, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0, true)
		
		# Inner highlight
		direction_line.draw_circle(knob_pos - Vector2(6, 6), 6, Color(1, 1, 1, 0.3))

func _process(delta: float) -> void:
	if not is_active:
		# Smoothly decay output
		if current_output.length() > 0.01:
			current_output = current_output.lerp(Vector2.ZERO, delta * 15.0)
			joystick_input.emit(current_output)
		elif current_output != Vector2.ZERO:
			current_output = Vector2.ZERO
			joystick_input.emit(current_output)
		
		can_jump = true

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		handle_screen_drag(event as InputEventScreenDrag)

func handle_screen_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		# Only respond to touches in our area (lower 70% of screen for gameplay)
		var viewport_size = get_viewport().get_visible_rect().size
		if touch.position.y < viewport_size.y * 0.15:
			return  # Ignore touches in top UI area
		
		# Start new touch
		if touch_index == -1:
			touch_index = touch.index
			touch_start_position = touch.position
			current_touch_position = touch.position
			is_active = true
			can_jump = true
			is_in_jump_zone = false
			
			# Show indicator at touch position
			if touch_indicator:
				touch_indicator.position = touch_start_position - Vector2(60, 60)
				touch_indicator.visible = true
				touch_indicator.queue_redraw()
			if direction_line:
				direction_line.visible = true
				direction_line.queue_redraw()
	else:
		# Touch released
		if touch.index == touch_index:
			release_touch()

func handle_screen_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != touch_index or not is_active:
		return
	
	current_touch_position = drag.position
	
	# Calculate direction from start position
	var delta = current_touch_position - touch_start_position
	var distance = delta.length()
	
	# Apply dead zone
	if distance < dead_zone:
		current_output = Vector2.ZERO
	else:
		# Calculate normalized output
		var effective_distance = distance - dead_zone
		var normalized = min(effective_distance / (max_drag_distance - dead_zone), 1.0)
		current_output = delta.normalized() * normalized
	
	# Check for jump
	var was_jump_zone = is_in_jump_zone
	is_in_jump_zone = current_output.y < -jump_threshold
	
	if is_in_jump_zone and can_jump:
		jump_triggered.emit()
		can_jump = false
	elif current_output.y > -jump_threshold * 0.4:
		# Reset jump when moving back down
		can_jump = true
	
	# Update visuals
	if touch_indicator and was_jump_zone != is_in_jump_zone:
		touch_indicator.queue_redraw()
	if direction_line:
		direction_line.queue_redraw()
	
	joystick_input.emit(current_output)

func release_touch() -> void:
	touch_index = -1
	is_active = false
	is_in_jump_zone = false
	can_jump = true
	
	# Hide indicators with fade
	if touch_indicator:
		var tween = create_tween()
		tween.tween_property(touch_indicator, "modulate:a", 0.0, 0.15)
		tween.tween_callback(func(): 
			touch_indicator.visible = false
			touch_indicator.modulate.a = 1.0
		)
	if direction_line:
		var tween = create_tween()
		tween.tween_property(direction_line, "modulate:a", 0.0, 0.1)
		tween.tween_callback(func():
			direction_line.visible = false
			direction_line.modulate.a = 1.0
		)
	
	joystick_released.emit()

func get_output() -> Vector2:
	return current_output

func get_horizontal_output() -> float:
	return current_output.x
