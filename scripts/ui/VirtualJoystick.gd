extends Control
class_name VirtualJoystick

signal joystick_input(direction: Vector2)
signal joystick_released
signal jump_triggered

@export_group("Sensitivity")
@export var max_drag_distance: float = 40.0  # Smaller = more sensitive
@export var dead_zone: float = 5.0           # Very small dead zone
@export var jump_threshold: float = 0.4      # Easy to trigger jump

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

func _process(delta: float) -> void:
	if not is_active:
		# Quick decay for responsive stop
		if current_output.length() > 0.001:
			current_output = current_output.lerp(Vector2.ZERO, delta * 20.0)
			joystick_input.emit(current_output)
		elif current_output != Vector2.ZERO:
			current_output = Vector2.ZERO
			joystick_input.emit(current_output)
		can_jump = true

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)

func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		# Ignore touches in top 12% (UI area)
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
			joystick_released.emit()

func _handle_drag(drag: InputEventScreenDrag) -> void:
	if drag.index != touch_index or not is_active:
		return
	
	current_touch_position = drag.position
	
	var delta = current_touch_position - touch_start_position
	var distance = delta.length()
	
	# Very responsive - small movements register quickly
	if distance < dead_zone:
		current_output = Vector2.ZERO
	else:
		var effective_distance = distance - dead_zone
		var normalized = min(effective_distance / max_drag_distance, 1.0)
		# Apply curve for better control at low speeds
		normalized = normalized * normalized * (3.0 - 2.0 * normalized)  # Smoothstep
		current_output = delta.normalized() * normalized
	
	# Jump detection
	if current_output.y < -jump_threshold and can_jump:
		jump_triggered.emit()
		can_jump = false
	elif current_output.y > -jump_threshold * 0.3:
		can_jump = true
	
	joystick_input.emit(current_output)

func get_output() -> Vector2:
	return current_output

func get_horizontal_output() -> float:
	return current_output.x
