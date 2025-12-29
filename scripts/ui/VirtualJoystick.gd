extends Control
class_name VirtualJoystick

signal joystick_input(direction: Vector2)
signal joystick_released
signal jump_triggered

@export_group("Sensitivity")
@export var horizontal_sensitivity: float = 0.03  # Lower = more sensitive
@export var jump_drag_threshold: float = 25.0     # Pixels to drag up for jump

# Internal state
var touch_index: int = -1
var touch_start_position: Vector2 = Vector2.ZERO
var current_touch_position: Vector2 = Vector2.ZERO
var current_output: Vector2 = Vector2.ZERO
var is_active: bool = false
var can_jump: bool = true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

func _process(_delta: float) -> void:
	if not is_active and current_output != Vector2.ZERO:
		current_output = Vector2.ZERO
		joystick_input.emit(current_output)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)

func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		# Ignore top 12% (UI)
		var viewport_size = get_viewport().get_visible_rect().size
		if touch.position.y < viewport_size.y * 0.12:
			return
		
		if touch_index == -1:
			touch_index = touch.index
			touch_start_position = touch.position
			current_touch_position = touch.position
			is_active = true
			can_jump = true
	else:
		if touch.index == touch_index:
			touch_index = -1
			is_active = false
			can_jump = true
			current_output = Vector2.ZERO
			joystick_input.emit(current_output)
			joystick_released.emit()

func _handle_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != touch_index or not is_active:
		return
	
	current_touch_position = drag.position
	var delta = current_touch_position - touch_start_position
	
	# HORIZONTAL: Independent, based purely on X drag
	# This allows full horizontal speed regardless of vertical position
	var horizontal = clamp(delta.x * horizontal_sensitivity, -1.0, 1.0)
	
	# Apply subtle curve for fine control
	horizontal = sign(horizontal) * pow(abs(horizontal), 0.8)
	
	current_output.x = horizontal
	
	# JUMP: Based on upward drag (negative Y)
	# Completely independent from horizontal
	if delta.y < -jump_drag_threshold and can_jump:
		jump_triggered.emit()
		can_jump = false
	elif delta.y > -jump_drag_threshold * 0.5:
		# Reset jump when finger moves back down
		can_jump = true
	
	joystick_input.emit(current_output)

func get_output() -> Vector2:
	return current_output

func get_horizontal_output() -> float:
	return current_output.x
