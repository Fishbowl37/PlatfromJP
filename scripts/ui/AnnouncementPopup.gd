extends CanvasLayer
class_name AnnouncementPopup

## Simple popup for showing Firebase announcements

signal closed(announcement_id: String)

var current_announcement: Dictionary = {}
var is_open: bool = false

func _ready() -> void:
	layer = 110  # Above other panels
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func show_announcement(announcement: Dictionary) -> void:
	if is_open:
		return
	
	current_announcement = announcement
	is_open = true
	visible = true
	
	var vp = get_viewport().get_visible_rect().size
	var pw = 300.0
	var ph = 200.0
	var px = (vp.x - pw) / 2.0
	var py = (vp.y - ph) / 2.0
	
	# Overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close())
	add_child(overlay)
	
	# Panel
	var panel = PanelContainer.new()
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.18)
	style.border_color = _get_type_color(announcement.get("type", "info"))
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	# Icon + Title
	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(title_hbox)
	
	var icon = Label.new()
	icon.text = _get_type_icon(announcement.get("type", "info"))
	icon.add_theme_font_size_override("font_size", 24)
	title_hbox.add_child(icon)
	
	var title = Label.new()
	title.text = announcement.get("title", "Announcement")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.9))
	title_hbox.add_child(title)
	
	# Message
	var message = Label.new()
	message.text = announcement.get("message", "")
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", Color(0.85, 0.8, 0.9))
	vbox.add_child(message)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# OK Button
	var ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(100, 40)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.add_theme_font_size_override("font_size", 16)
	ok_btn.pressed.connect(_close)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.5, 0.7)
	btn_style.set_corner_radius_all(20)
	ok_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.35, 0.6, 0.8)
	btn_hover.set_corner_radius_all(20)
	ok_btn.add_theme_stylebox_override("hover", btn_hover)
	
	ok_btn.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(ok_btn)
	
	# Animate entrance
	panel.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	panel.pivot_offset = Vector2(pw/2, ph/2)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.4)

func _get_type_color(type: String) -> Color:
	match type:
		"warning": return Color(1.0, 0.7, 0.2)
		"error": return Color(1.0, 0.4, 0.4)
		"success": return Color(0.4, 0.9, 0.5)
		"event": return Color(0.9, 0.5, 1.0)
		_: return Color(0.4, 0.7, 1.0)  # info

func _get_type_icon(type: String) -> String:
	match type:
		"warning": return "⚠️"
		"error": return "❌"
		"success": return "✅"
		"event": return "🎉"
		_: return "📢"  # info

func _close() -> void:
	if not is_open:
		return
	
	is_open = false
	
	var announcement_id = current_announcement.get("id", "")
	current_announcement = {}
	
	# Animate out - fade all children since CanvasLayer doesn't have modulate
	var tween = create_tween()
	for child in get_children():
		if child is CanvasItem:
			tween.parallel().tween_property(child, "modulate:a", 0.0, 0.2)
	
	tween.tween_callback(func():
		visible = false
		for child in get_children():
			child.queue_free()
		closed.emit(announcement_id)
	)
