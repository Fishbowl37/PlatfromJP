extends CanvasLayer
class_name TouchControls

signal direction_changed(direction: float)
signal jump_pressed

@export var player: Player

@export_group("Control Mode")
enum ControlMode { SPLIT_SCREEN, VIRTUAL_BUTTONS, SWIPE }
@export var control_mode: ControlMode = ControlMode.SPLIT_SCREEN

@export_group("Visual Feedback")
@export var show_touch_indicators: bool = true
@export var indicator_opacity: float = 0.3

@onready var left_indicator: ColorRect = $LeftIndicator
@onready var right_indicator: ColorRect = $RightIndicator
@onready var left_button: TouchScreenButton = $LeftButton if has_node("LeftButton") else null
@onready var right_button: TouchScreenButton = $RightButton if has_node("RightButton") else null
@onready var jump_button: TouchScreenButton = $JumpButton if has_node("JumpButton") else null
@onready var speed_label: Label = $InfoContainer/SpeedLabel
@onready var phase_label: Label = $InfoContainer/PhaseLabel

var current_direction: float = 0.0
var active_touches: Dictionary = {}  # touch_index -> side ("left" or "right")
var screen_width: float = 0.0

func _ready() -> void:
	screen_width = get_viewport().get_visible_rect().size.x
	setup_controls()

func setup_controls() -> void:
	match control_mode:
		ControlMode.SPLIT_SCREEN:
			setup_split_screen()
		ControlMode.VIRTUAL_BUTTONS:
			setup_virtual_buttons()
		ControlMode.SWIPE:
			setup_swipe()
	
	update_indicators()

func setup_split_screen() -> void:
	# Split screen mode: left half = move left, right half = move right
	# Tap anywhere = jump (while holding direction)
	if left_indicator:
		left_indicator.visible = show_touch_indicators
		left_indicator.size = Vector2(screen_width / 2, get_viewport().get_visible_rect().size.y)
		left_indicator.position = Vector2.ZERO
		left_indicator.modulate.a = 0
	
	if right_indicator:
		right_indicator.visible = show_touch_indicators
		right_indicator.size = Vector2(screen_width / 2, get_viewport().get_visible_rect().size.y)
		right_indicator.position = Vector2(screen_width / 2, 0)
		right_indicator.modulate.a = 0

func setup_virtual_buttons() -> void:
	# Virtual buttons mode uses TouchScreenButton nodes
	if left_indicator:
		left_indicator.visible = false
	if right_indicator:
		right_indicator.visible = false

func setup_swipe() -> void:
	# Swipe mode: horizontal swipe to change direction
	if left_indicator:
		left_indicator.visible = false
	if right_indicator:
		right_indicator.visible = false

func _input(event: InputEvent) -> void:
	if control_mode == ControlMode.SPLIT_SCREEN:
		handle_split_screen_input(event)

func handle_split_screen_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch = event as InputEventScreenTouch
		
		if touch.pressed:
			# New touch - determine side and register
			var side = "left" if touch.position.x < screen_width / 2 else "right"
			active_touches[touch.index] = side
			
			# Always trigger jump on new touch
			trigger_jump()
			
			update_direction()
			update_indicators()
		else:
			# Touch released
			active_touches.erase(touch.index)
			update_direction()
			update_indicators()
	
	elif event is InputEventScreenDrag:
		var drag = event as InputEventScreenDrag
		
		# Update side if finger moved to other half
		if active_touches.has(drag.index):
			var new_side = "left" if drag.position.x < screen_width / 2 else "right"
			if active_touches[drag.index] != new_side:
				active_touches[drag.index] = new_side
				update_direction()
				update_indicators()

func update_direction() -> void:
	var left_pressed = false
	var right_pressed = false
	
	for side in active_touches.values():
		if side == "left":
			left_pressed = true
		elif side == "right":
			right_pressed = true
	
	# Calculate direction
	if left_pressed and right_pressed:
		current_direction = 0.0  # Both pressed = no movement
	elif left_pressed:
		current_direction = -1.0
	elif right_pressed:
		current_direction = 1.0
	else:
		current_direction = 0.0
	
	# Update player
	if player:
		player.set_touch_direction(current_direction)
	
	direction_changed.emit(current_direction)

func trigger_jump() -> void:
	if player:
		player.trigger_touch_jump()
	jump_pressed.emit()

func update_indicators() -> void:
	if not show_touch_indicators:
		return
	
	var left_active = false
	var right_active = false
	
	for side in active_touches.values():
		if side == "left":
			left_active = true
		elif side == "right":
			right_active = true
	
	if left_indicator:
		var target_alpha = indicator_opacity if left_active else 0.0
		var tween = create_tween()
		tween.tween_property(left_indicator, "modulate:a", target_alpha, 0.1)
	
	if right_indicator:
		var target_alpha = indicator_opacity if right_active else 0.0
		var tween = create_tween()
		tween.tween_property(right_indicator, "modulate:a", target_alpha, 0.1)

func set_player(p: Player) -> void:
	player = p

func get_current_direction() -> float:
	return current_direction

func set_speed(speed: float) -> void:
	if speed_label:
		speed_label.text = "SPEED: %d" % int(speed)
		
		# Color based on speed
		var speed_color: Color
		if speed >= 80:
			speed_color = Color(1, 0.3, 0.3, 0.9)  # Red - fast!
		elif speed >= 50:
			speed_color = Color(1, 0.7, 0.3, 0.8)  # Orange
		elif speed >= 30:
			speed_color = Color(1, 1, 0.5, 0.7)    # Yellow
		else:
			speed_color = Color(0.5, 0.8, 1.0, 0.7)  # Default cyan
		
		speed_label.add_theme_color_override("font_color", speed_color)

func set_phase(phase_name: String) -> void:
	if phase_label:
		phase_label.text = phase_name

