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

# Tuning - very forgiving for mobile
const HORIZONTAL_SENSITIVITY: float = 0.04   # Pixels to full speed (25px = full)
const JUMP_THRESHOLD: float = 15.0           # Pixels up to jump (very easy)
const JUMP_RESET_THRESHOLD: float = 5.0      # Pixels to allow jump again

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch = event as InputEventScreenTouch
		if touch.pressed:
			_start_touch(touch)
		elif touch.index == touch_index:
			_end_touch()
	
	elif event is InputEventScreenDrag:
		var drag = event as InputEventScreenDrag
		if drag.index == touch_index and is_active:
			_update_touch(drag.position)

func _start_touch(touch: InputEventScreenTouch) -> void:
	# Ignore top UI area
	var viewport_size = get_viewport().get_visible_rect().size
	if touch.position.y < viewport_size.y * 0.1:
		return
	
	if touch_index == -1:
		touch_index = touch.index
		touch_start_position = touch.position
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

func _update_touch(pos: Vector2) -> void:
	var delta = pos - touch_start_position
	
	# HORIZONTAL - Super responsive
	# Small drag = proportional speed, quickly reaches full speed
	var raw_horizontal = delta.x * HORIZONTAL_SENSITIVITY
	current_horizontal = clamp(raw_horizontal, -1.0, 1.0)
	
	# Emit immediately for instant response
	joystick_input.emit(Vector2(current_horizontal, 0))
	
	# JUMP - Very easy to trigger
	# Just flick up a tiny bit while moving
	if delta.y < -JUMP_THRESHOLD and can_jump:
		jump_triggered.emit()
		can_jump = false
	elif delta.y > -JUMP_RESET_THRESHOLD:
		can_jump = true

func get_horizontal_output() -> float:
	return current_horizontal
