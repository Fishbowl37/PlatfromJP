extends CanvasLayer
class_name SettingsPanel

signal closed

var is_open: bool = false
var sensitivity_slider: HSlider
var value_label: Label

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()

func open_panel() -> void:
	if is_open:
		return
	
	is_open = true
	visible = true
	
	var vp = get_viewport().get_visible_rect().size
	var pw = 320.0
	var ph = 260.0
	var px = (vp.x - pw) / 2.0
	var py = (vp.y - ph) / 2.0
	
	# === OVERLAY ===
	var overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.01, 0.08, 0.9)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.gui_input.connect(_on_overlay_input)
	add_child(overlay)
	
	# === GLOW LAYERS (outer to inner) ===
	# Outer glow - soft and large
	var glow3 = ColorRect.new()
	glow3.color = Color(0.4, 0.2, 1.0, 0.15)
	glow3.position = Vector2(px - 20, py - 20)
	glow3.size = Vector2(pw + 40, ph + 40)
	add_child(glow3)
	
	# Medium glow
	var glow2 = ColorRect.new()
	glow2.color = Color(0.5, 0.3, 1.0, 0.25)
	glow2.position = Vector2(px - 12, py - 12)
	glow2.size = Vector2(pw + 24, ph + 24)
	add_child(glow2)
	
	# Inner glow - bright
	var glow1 = ColorRect.new()
	glow1.color = Color(0.6, 0.4, 1.0, 0.4)
	glow1.position = Vector2(px - 6, py - 6)
	glow1.size = Vector2(pw + 12, ph + 12)
	add_child(glow1)
	
	# === BRIGHT BORDER ===
	var border = ColorRect.new()
	border.color = Color(0.7, 0.5, 1.0)
	border.position = Vector2(px - 3, py - 3)
	border.size = Vector2(pw + 6, ph + 6)
	add_child(border)
	
	# === MAIN PANEL ===
	var panel = ColorRect.new()
	panel.color = Color(0.08, 0.05, 0.18)
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	add_child(panel)
	
	# === INNER HIGHLIGHT LINE (top) ===
	var top_line = ColorRect.new()
	top_line.color = Color(0.8, 0.6, 1.0, 0.5)
	top_line.position = Vector2(px + 10, py + 3)
	top_line.size = Vector2(pw - 20, 2)
	add_child(top_line)
	
	# === CLOSE BUTTON - Minimal style ===
	var close_btn = Button.new()
	close_btn.text = "×"
	close_btn.position = Vector2(px + 10, py + 8)
	close_btn.size = Vector2(32, 32)
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.6, 0.9))
	close_btn.add_theme_color_override("font_hover_color", Color(1, 0.4, 0.4))
	close_btn.add_theme_color_override("font_pressed_color", Color(1, 0.3, 0.3))
	close_btn.pressed.connect(close_panel)
	add_child(close_btn)
	
	# === TITLE ===
	var title = Label.new()
	title.text = "SETTINGS"
	title.position = Vector2(px, py + 18)
	title.size = Vector2(pw, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title.add_theme_color_override("font_outline_color", Color(0.6, 0.3, 0.1))
	title.add_theme_constant_override("outline_size", 3)
	add_child(title)
	
	# === DIVIDER ===
	var divider = ColorRect.new()
	divider.color = Color(0.6, 0.4, 1.0, 0.6)
	divider.position = Vector2(px + 30, py + 58)
	divider.size = Vector2(pw - 60, 2)
	add_child(divider)
	
	# === SENSITIVITY LABEL ===
	var sens_label = Label.new()
	sens_label.text = "🎮  Joystick Sensitivity"
	sens_label.position = Vector2(px + 20, py + 72)
	sens_label.size = Vector2(pw - 40, 28)
	sens_label.add_theme_font_size_override("font_size", 17)
	sens_label.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	add_child(sens_label)
	
	# === SLIDER BACKGROUND ===
	var slider_bg = ColorRect.new()
	slider_bg.color = Color(0.12, 0.08, 0.25)
	slider_bg.position = Vector2(px + 15, py + 102)
	slider_bg.size = Vector2(pw - 30, 50)
	add_child(slider_bg)
	
	# Slider bg border
	var slider_border = ColorRect.new()
	slider_border.color = Color(0.4, 0.3, 0.7, 0.5)
	slider_border.position = Vector2(px + 14, py + 101)
	slider_border.size = Vector2(pw - 28, 52)
	slider_border.z_index = -1
	add_child(slider_border)
	
	# === SLIDER ===
	sensitivity_slider = HSlider.new()
	sensitivity_slider.min_value = 0.1
	sensitivity_slider.max_value = 1.0
	sensitivity_slider.step = 0.05
	sensitivity_slider.value = GameManager.get_joystick_sensitivity()
	sensitivity_slider.position = Vector2(px + 50, py + 112)
	sensitivity_slider.size = Vector2(pw - 100, 30)
	sensitivity_slider.value_changed.connect(_on_slider_changed)
	add_child(sensitivity_slider)
	
	# === LOW / HIGH with emojis ===
	var low = Label.new()
	low.text = "🐢"
	low.position = Vector2(px + 22, py + 112)
	low.add_theme_font_size_override("font_size", 20)
	add_child(low)
	
	var high = Label.new()
	high.text = "🐇"
	high.position = Vector2(px + pw - 45, py + 112)
	high.add_theme_font_size_override("font_size", 20)
	add_child(high)
	
	# === VALUE DISPLAY ===
	value_label = Label.new()
	value_label.position = Vector2(px, py + 158)
	value_label.size = Vector2(pw, 40)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 34)
	value_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.9))
	value_label.add_theme_color_override("font_outline_color", Color(0.1, 0.3, 0.3))
	value_label.add_theme_constant_override("outline_size", 2)
	_update_value(sensitivity_slider.value)
	add_child(value_label)
	
	# === DONE BUTTON ===
	var btn = Button.new()
	btn.text = "✓  DONE"
	btn.position = Vector2(px + (pw - 130) / 2, py + 205)
	btn.size = Vector2(130, 45)
	btn.add_theme_font_size_override("font_size", 19)
	btn.pressed.connect(close_panel)
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.3, 0.8, 0.5)
	btn_normal.set_corner_radius_all(22)
	btn_normal.shadow_color = Color(0.2, 0.5, 0.3, 0.5)
	btn_normal.shadow_size = 4
	btn.add_theme_stylebox_override("normal", btn_normal)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.4, 0.95, 0.6)
	btn_hover.set_corner_radius_all(22)
	btn_hover.shadow_color = Color(0.3, 0.7, 0.4, 0.6)
	btn_hover.shadow_size = 6
	btn.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.25, 0.6, 0.4)
	btn_pressed.set_corner_radius_all(22)
	btn.add_theme_stylebox_override("pressed", btn_pressed)
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	
	add_child(btn)
	
	# Pause game
	get_tree().paused = true

func close_panel() -> void:
	if not is_open:
		return
	
	is_open = false
	visible = false
	
	for child in get_children():
		child.queue_free()
	
	get_tree().paused = false
	closed.emit()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_panel()
	elif event is InputEventScreenTouch and event.pressed:
		close_panel()

func _on_slider_changed(value: float) -> void:
	GameManager.set_joystick_sensitivity(value)
	_update_value(value)

func _update_value(value: float) -> void:
	if value_label:
		value_label.text = "%d%%" % int(value * 100)
