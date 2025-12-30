extends Control
class_name VirtualJoystick

signal joystick_input(direction: Vector2)
signal joystick_released
signal jump_triggered

# Internal state
var touch_index: int = -1
var touch_start_position: Vector2 = Vector2.ZERO
var is_active: bool = false
var can_jump: bool = true
var current_horizontal: float = 0.0
var last_y: float = 0.0  # Track Y movement for flick detection

# Sensitivity tuning
# Base sensitivity - this gets multiplied by user's setting (0.1 to 1.0)
# At sensitivity 0.4 (default), ~50px = full speed
# At sensitivity 1.0 (max), ~20px = full speed  
# At sensitivity 0.1 (min), ~200px = full speed
const BASE_SENSITIVITY: float = 0.05
var horizontal_sensitivity: float = 0.02  # Calculated from user setting

const JUMP_FLICK_THRESHOLD: float = 8.0      # Tiny flick up = jump
const JUMP_VELOCITY_THRESHOLD: float = 3.0   # Or fast upward movement = jump

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Use IGNORE so GUI elements (buttons, sliders) can receive input
	# The joystick uses _input() for touch handling, not GUI events
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Get initial sensitivity from GameManager
	update_sensitivity(GameManager.get_joystick_sensitivity())
	
	# Listen for sensitivity changes
	GameManager.joystick_sensitivity_changed.connect(update_sensitivity)

func update_sensitivity(value: float) -> void:
	# Map user setting (0.1 to 1.0) to actual sensitivity
	# Higher value = more sensitive (less movement needed)
	horizontal_sensitivity = BASE_SENSITIVITY * value

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch = event as InputEventScreenTouch
		# Don't process if touch is in UI area (let buttons handle it)
		if _is_in_ui_area(touch.position):
			return
		if touch.pressed:
			_start_touch(touch)
		elif touch.index == touch_index:
			_end_touch()
	
	elif event is InputEventScreenDrag:
		var drag = event as InputEventScreenDrag
		if drag.index == touch_index and is_active:
			_update_touch(drag)

func _is_in_ui_area(pos: Vector2) -> bool:
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Top 15% of screen (HUD area)
	if pos.y < viewport_size.y * 0.15:
		return true
	
	# Top-right corner (settings button area: 80px from right, 150px from top)
	if pos.y < 150 and pos.x > viewport_size.x - 80:
		return true
	
	return false

func _start_touch(touch: InputEventScreenTouch) -> void:
	# UI area check is now done in _input() before calling this
	if touch_index == -1:
		touch_index = touch.index
		touch_start_position = touch.position
		last_y = touch.position.y
		is_active = true
		can_jump = true
		current_horizontal = 0.0

func _end_touch() -> void:
	touch_index = -1
	is_active = false
	can_jump = true
	current_horizontal = 0.0
	joystick_input.emit(Vector2.ZERO)
	joystick_released.emit()

func _update_touch(drag: InputEventScreenDrag) -> void:
	var pos = drag.position
	var delta = pos - touch_start_position
	
	# HORIZONTAL - instant response with configurable sensitivity
	current_horizontal = clamp(delta.x * horizontal_sensitivity, -1.0, 1.0)
	joystick_input.emit(Vector2(current_horizontal, 0))
	
	# JUMP - Two ways to trigger (very forgiving):
	# 1. Position-based: finger is above start point
	# 2. Velocity-based: finger moving upward quickly
	
	var y_velocity = last_y - pos.y  # Positive = moving up
	var y_offset = touch_start_position.y - pos.y  # Positive = above start
	
	if can_jump:
		# Jump if: flicked up OR moved up enough from start
		if y_velocity > JUMP_VELOCITY_THRESHOLD or y_offset > JUMP_FLICK_THRESHOLD:
			jump_triggered.emit()
			can_jump = false
			# Reset the start position so they can jump again easily
			touch_start_position.y = pos.y
	else:
		# Allow jump again when finger moves down a tiny bit
		if y_velocity < -1.0 or y_offset < 3.0:
			can_jump = true
	
	last_y = pos.y

func get_horizontal_output() -> float:
	return current_horizontal
