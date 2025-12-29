extends CanvasLayer
class_name TouchControls

signal direction_changed(direction: float)
signal jump_pressed

@export var player: Player

var joystick: VirtualJoystick
var speed_label: Label = null
var phase_label: Label = null
var current_direction: float = 0.0

func _ready() -> void:
	setup_joystick()
	setup_info_display()

func setup_joystick() -> void:
	joystick = VirtualJoystick.new()
	joystick.name = "VirtualJoystick"
	add_child(joystick)
	
	joystick.joystick_input.connect(_on_joystick_input)
	joystick.joystick_released.connect(_on_joystick_released)
	joystick.jump_triggered.connect(_on_jump_triggered)

func setup_info_display() -> void:
	var info_container = HBoxContainer.new()
	info_container.name = "InfoContainer"
	info_container.anchors_preset = Control.PRESET_CENTER_TOP
	info_container.anchor_left = 0.5
	info_container.anchor_top = 0.0
	info_container.anchor_right = 0.5
	info_container.anchor_bottom = 0.0
	info_container.offset_left = -100
	info_container.offset_top = 70
	info_container.offset_right = 100
	info_container.offset_bottom = 90
	info_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	info_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_theme_constant_override("separation", 20)
	add_child(info_container)
	
	speed_label = Label.new()
	speed_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 0.5))
	speed_label.add_theme_font_size_override("font_size", 12)
	info_container.add_child(speed_label)
	
	phase_label = Label.new()
	phase_label.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0, 0.5))
	phase_label.add_theme_font_size_override("font_size", 12)
	info_container.add_child(phase_label)

func _on_joystick_input(direction: Vector2) -> void:
	current_direction = direction.x
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
	if speed_label:
		speed_label.text = "SPEED: %d" % int(speed)
		var c: Color
		if speed >= 80:
			c = Color(1, 0.3, 0.3, 0.7)
		elif speed >= 50:
			c = Color(1, 0.7, 0.3, 0.6)
		elif speed >= 30:
			c = Color(1, 1, 0.5, 0.5)
		else:
			c = Color(0.5, 0.8, 1.0, 0.5)
		speed_label.add_theme_color_override("font_color", c)

func set_phase(phase_name: String) -> void:
	if phase_label:
		phase_label.text = phase_name

func show_controls() -> void:
	if joystick:
		joystick.visible = true

func hide_controls() -> void:
	if joystick:
		joystick.visible = false
