extends CanvasLayer
class_name TouchControls

signal direction_changed(direction: float)
signal jump_pressed

@export var player: Player

@export_group("Layout Settings")
@export var joystick_bottom_margin: float = 25.0  # From bottom of screen

@export_group("Visual Feedback")
@export var show_speed_info: bool = true

# Components
var joystick: VirtualJoystick

# Info display
var speed_label: Label = null
var phase_label: Label = null

var current_direction: float = 0.0
var screen_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	
	# Wait a frame to ensure viewport is ready
	await get_tree().process_frame
	screen_size = get_viewport().get_visible_rect().size
	
	setup_joystick()
	setup_info_display()
	
	# Connect to viewport resize
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	screen_size = get_viewport().get_visible_rect().size
	position_controls()

func setup_joystick() -> void:
	joystick = VirtualJoystick.new()
	joystick.name = "VirtualJoystick"
	joystick.custom_minimum_size = Vector2(200, 200)
	joystick.size = joystick.custom_minimum_size
	
	# Configure joystick for comfortable mobile use
	joystick.joystick_radius = 75.0
	joystick.knob_radius = 32.0
	joystick.dead_zone = 0.12
	joystick.jump_threshold = 0.45  # Push up about halfway to jump
	joystick.follow_finger = true
	
	# Colors for good visibility
	joystick.base_color = Color(0.3, 0.6, 1.0, 0.2)
	joystick.knob_color = Color(0.5, 0.75, 1.0, 0.5)
	joystick.active_color = Color(0.5, 0.85, 1.0, 0.65)
	joystick.jump_color = Color(0.4, 1.0, 0.5, 0.7)
	
	add_child(joystick)
	
	# Connect signals
	joystick.joystick_input.connect(_on_joystick_input)
	joystick.joystick_released.connect(_on_joystick_released)
	joystick.jump_triggered.connect(_on_jump_triggered)
	
	position_controls()

func setup_info_display() -> void:
	# Create info container
	var info_container = HBoxContainer.new()
	info_container.name = "InfoContainer"
	info_container.anchors_preset = Control.PRESET_CENTER_TOP
	info_container.anchor_left = 0.5
	info_container.anchor_top = 0.0
	info_container.anchor_right = 0.5
	info_container.anchor_bottom = 0.0
	info_container.offset_left = -150
	info_container.offset_top = 70
	info_container.offset_right = 150
	info_container.offset_bottom = 100
	info_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	info_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_theme_constant_override("separation", 30)
	add_child(info_container)
	
	# Speed label
	speed_label = Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 0.7))
	speed_label.add_theme_font_size_override("font_size", 14)
	speed_label.text = ""
	info_container.add_child(speed_label)
	
	# Phase label
	phase_label = Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0, 0.7))
	phase_label.add_theme_font_size_override("font_size", 14)
	phase_label.text = ""
	info_container.add_child(phase_label)

func position_controls() -> void:
	if joystick:
		# Position joystick at center-bottom of screen
		joystick.position = Vector2(
			(screen_size.x - joystick.size.x) / 2,
			screen_size.y - joystick.size.y - joystick_bottom_margin
		)

func _on_joystick_input(direction: Vector2) -> void:
	# Use horizontal component for movement
	current_direction = direction.x
	
	# Apply smoothing for more responsive feel
	if abs(current_direction) < 0.08:
		current_direction = 0.0
	
	# Update player
	if player:
		player.set_touch_direction(current_direction)
	
	direction_changed.emit(current_direction)

func _on_joystick_released() -> void:
	current_direction = 0.0
	if player:
		player.set_touch_direction(0.0)
	direction_changed.emit(0.0)

func _on_jump_triggered() -> void:
	if player:
		player.trigger_touch_jump()
	jump_pressed.emit()

func set_player(p: Player) -> void:
	player = p

func get_current_direction() -> float:
	return current_direction

func set_speed(speed: float) -> void:
	if speed_label and show_speed_info:
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

func show_controls() -> void:
	if joystick:
		joystick.visible = true

func hide_controls() -> void:
	if joystick:
		joystick.visible = false
