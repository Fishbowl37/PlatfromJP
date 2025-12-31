extends CanvasLayer
class_name SkinsPanel

signal closed

var is_open: bool = false
var skin_buttons: Dictionary = {}
var selected_skin: String = ""
var preview_container: Control = null
var preview_sprite: AnimatedSprite2D = null
var skin_manager: Node = null

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()

func set_skin_manager(manager: Node) -> void:
	skin_manager = manager

func open_panel() -> void:
	if is_open:
		return
	
	is_open = true
	visible = true
	skin_buttons.clear()
	
	var vp = get_viewport().get_visible_rect().size
	var pw = 340.0
	var ph = 480.0
	var px = (vp.x - pw) / 2.0
	var py = (vp.y - ph) / 2.0
	
	# === OVERLAY ===
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.gui_input.connect(_on_overlay_input)
	add_child(overlay)
	
	# === MAIN PANEL with gradient effect ===
	var panel_outer = ColorRect.new()
	panel_outer.color = Color(1.0, 0.75, 0.3, 0.8)
	panel_outer.position = Vector2(px - 2, py - 2)
	panel_outer.size = Vector2(pw + 4, ph + 4)
	add_child(panel_outer)
	
	var panel = ColorRect.new()
	panel.color = Color(0.12, 0.08, 0.2)
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	add_child(panel)
	
	# Inner gradient overlay
	var inner_glow = ColorRect.new()
	inner_glow.color = Color(0.2, 0.1, 0.35, 0.5)
	inner_glow.position = Vector2(px, py)
	inner_glow.size = Vector2(pw, 80)
	add_child(inner_glow)
	
	# === CLOSE BUTTON - Minimal style ===
	var close_btn = Button.new()
	close_btn.text = "×"
	close_btn.position = Vector2(px + 10, py + 8)
	close_btn.size = Vector2(32, 32)
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8))
	close_btn.add_theme_color_override("font_hover_color", Color(1, 0.4, 0.4))
	close_btn.add_theme_color_override("font_pressed_color", Color(1, 0.3, 0.3))
	close_btn.pressed.connect(close_panel)
	add_child(close_btn)
	
	# === TITLE ===
	var title = Label.new()
	title.text = "SKINS"
	title.position = Vector2(px, py + 12)
	title.size = Vector2(pw, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	add_child(title)
	
	# === COINS - Top Right ===
	var coins = 0
	if skin_manager:
		coins = skin_manager.get_coins()
	var coins_label = Label.new()
	coins_label.name = "CoinsLabel"
	coins_label.text = "💎 %d" % coins
	coins_label.position = Vector2(px + pw - 75, py + 14)
	coins_label.size = Vector2(65, 28)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.add_theme_font_size_override("font_size", 14)
	coins_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	add_child(coins_label)
	
	# === PREVIEW AREA ===
	var preview_y = py + 50
	var preview_h = 120
	
	# Preview background with subtle border
	var preview_border = ColorRect.new()
	preview_border.color = Color(0.3, 0.2, 0.5, 0.5)
	preview_border.position = Vector2(px + 24, preview_y - 1)
	preview_border.size = Vector2(pw - 48, preview_h + 2)
	add_child(preview_border)
	
	var preview_bg = ColorRect.new()
	preview_bg.color = Color(0.06, 0.04, 0.12)
	preview_bg.position = Vector2(px + 25, preview_y)
	preview_bg.size = Vector2(pw - 50, preview_h)
	add_child(preview_bg)
	
	# Create a container for the preview to clip content
	preview_container = Control.new()
	preview_container.position = Vector2(px + 25, preview_y)
	preview_container.size = Vector2(pw - 50, preview_h)
	preview_container.clip_contents = true
	add_child(preview_container)
	
	# Character preview sprite - positioned relative to container
	preview_sprite = AnimatedSprite2D.new()
	# Center in container: container is (pw-50) wide, preview_h tall
	# Position relative to container's top-left
	preview_sprite.position = Vector2((pw - 50) / 2, preview_h / 2 + 20)
	preview_sprite.scale = Vector2(1.8, 1.8)
	preview_sprite.centered = true
	var frames = load("res://assets/sprites/player/player_frames.tres")
	if frames:
		preview_sprite.sprite_frames = frames
		preview_sprite.play("idle")
	preview_container.add_child(preview_sprite)
	
	# === SKIN NAME LABEL ===
	var name_label = Label.new()
	name_label.name = "SkinNameLabel"
	name_label.position = Vector2(px + 20, preview_y + preview_h + 8)
	name_label.size = Vector2(pw - 40, 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	add_child(name_label)
	
	# === SKINS GRID ===
	var grid_y = preview_y + preview_h + 38
	var grid_cols = 4
	var btn_size = 64
	var btn_spacing = 12
	var grid_width = grid_cols * btn_size + (grid_cols - 1) * btn_spacing
	var grid_x = px + (pw - grid_width) / 2
	
	var skins = _get_skins()
	var i = 0
	for skin_id in skins.keys():
		var skin_data = skins[skin_id]
		var col = i % grid_cols
		var row = i / grid_cols
		var btn_x = grid_x + col * (btn_size + btn_spacing)
		var btn_y = grid_y + row * (btn_size + btn_spacing + 4)
		
		var btn = _create_skin_button(skin_id, skin_data, Vector2(btn_x, btn_y), btn_size)
		add_child(btn)
		skin_buttons[skin_id] = btn
		i += 1
	
	# === ACTION BUTTON ===
	var action_btn = Button.new()
	action_btn.name = "ActionButton"
	action_btn.text = "EQUIP"
	action_btn.position = Vector2(px + 60, py + ph - 60)
	action_btn.size = Vector2(pw - 120, 48)
	action_btn.add_theme_font_size_override("font_size", 18)
	action_btn.pressed.connect(_on_action_pressed)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.7, 0.4)
	btn_style.set_corner_radius_all(24)
	action_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.4, 0.85, 0.5)
	btn_hover.set_corner_radius_all(24)
	action_btn.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_disabled = StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.25, 0.25, 0.3)
	btn_disabled.set_corner_radius_all(24)
	action_btn.add_theme_stylebox_override("disabled", btn_disabled)
	
	action_btn.add_theme_color_override("font_color", Color.WHITE)
	action_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	add_child(action_btn)
	
	# Initialize selection
	if skin_manager:
		selected_skin = skin_manager.get_equipped_skin()
	else:
		selected_skin = "default"
	_update_selection()

func _get_skins() -> Dictionary:
	if skin_manager and skin_manager.has_method("get_all_skins"):
		return skin_manager.get_all_skins()
	return {
		"default": {"name": "Classic", "price": 0, "icon": "🧍", "sprite_modulate": Color(1, 1, 1)},
		"golden": {"name": "Golden", "price": 1000, "icon": "👑", "sprite_modulate": Color(1, 0.9, 0.5)},
		"neon": {"name": "Neon", "price": 1500, "icon": "⚡", "sprite_modulate": Color(0.7, 1, 0.9)},
		"fire": {"name": "Fire", "price": 2000, "icon": "🔥", "sprite_modulate": Color(1, 0.7, 0.5)},
		"ice": {"name": "Ice", "price": 2000, "icon": "❄️", "sprite_modulate": Color(0.8, 0.95, 1)},
		"shadow": {"name": "Shadow", "price": 2500, "icon": "🌑", "sprite_modulate": Color(0.5, 0.4, 0.6)},
		"rainbow": {"name": "Rainbow", "price": 5000, "icon": "🌈", "sprite_modulate": Color(1, 1, 1)},
		"ghost": {"name": "Ghost", "price": 3000, "icon": "👻", "sprite_modulate": Color(0.9, 0.9, 1, 0.85)}
	}

func _create_skin_button(skin_id: String, skin_data: Dictionary, pos: Vector2, size: int) -> Control:
	var container = Control.new()
	container.position = pos
	container.size = Vector2(size, size + 16)
	
	var is_unlocked = true
	var is_equipped = false
	if skin_manager:
		is_unlocked = skin_manager.is_skin_unlocked(skin_id)
		is_equipped = skin_manager.get_equipped_skin() == skin_id
	
	var btn = Button.new()
	btn.name = "Button"
	btn.position = Vector2.ZERO
	btn.size = Vector2(size, size)
	btn.pressed.connect(_on_skin_selected.bind(skin_id))
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.1, 0.25) if is_unlocked else Color(0.1, 0.08, 0.15)
	btn_style.set_corner_radius_all(12)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.4, 0.3, 0.6, 0.6) if is_unlocked else Color(0.25, 0.2, 0.35, 0.4)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_style)
	btn.add_theme_stylebox_override("pressed", btn_style)
	container.add_child(btn)
	
	# Icon
	var icon = Label.new()
	icon.text = skin_data.get("icon", "?")
	icon.position = Vector2(0, 8)
	icon.size = Vector2(size, size - 16)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 26)
	if not is_unlocked:
		icon.modulate = Color(0.4, 0.4, 0.4, 0.6)
	container.add_child(icon)
	
	# Price or equipped indicator
	var info_label = Label.new()
	info_label.position = Vector2(0, size + 2)
	info_label.size = Vector2(size, 14)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 9)
	if is_equipped:
		info_label.text = "✓"
		info_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	elif is_unlocked:
		info_label.text = ""
	else:
		info_label.text = "%d" % skin_data.get("price", 0)
		info_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9, 0.8))
	container.add_child(info_label)
	
	# Lock icon overlay
	if not is_unlocked:
		var lock = Label.new()
		lock.text = "🔒"
		lock.position = Vector2(size - 18, 4)
		lock.add_theme_font_size_override("font_size", 11)
		container.add_child(lock)
	
	return container

func _on_skin_selected(skin_id: String) -> void:
	selected_skin = skin_id
	_update_selection()

func _update_selection() -> void:
	var skins = _get_skins()
	var equipped = ""
	if skin_manager:
		equipped = skin_manager.get_equipped_skin()
	
	# Update button borders
	for skin_id in skin_buttons.keys():
		var btn_container = skin_buttons[skin_id]
		var btn = btn_container.get_node_or_null("Button") as Button
		if not btn:
			continue
		
		var is_unlocked = skin_manager.is_skin_unlocked(skin_id) if skin_manager else true
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.1, 0.25) if is_unlocked else Color(0.1, 0.08, 0.15)
		style.set_corner_radius_all(12)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		
		if skin_id == selected_skin:
			style.border_color = Color(1.0, 0.8, 0.3)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
		elif skin_id == equipped:
			style.border_color = Color(0.4, 1.0, 0.5, 0.8)
		else:
			style.border_color = Color(0.4, 0.3, 0.6, 0.6) if is_unlocked else Color(0.25, 0.2, 0.35, 0.4)
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
	
	# Update preview
	if preview_sprite and selected_skin in skins:
		var skin_data = skins[selected_skin]
		preview_sprite.modulate = skin_data.get("sprite_modulate", Color(1, 1, 1))
	
	# Update name label
	var name_label = get_node_or_null("SkinNameLabel")
	if name_label and selected_skin in skins:
		var skin_data = skins[selected_skin]
		var skin_name = skin_data.get("name", selected_skin)
		if selected_skin == equipped:
			name_label.text = "%s (Equipped)" % skin_name
			name_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		else:
			name_label.text = skin_name
			name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	
	# Update action button
	var action_btn = get_node_or_null("ActionButton")
	if action_btn:
		var is_unlocked = skin_manager.is_skin_unlocked(selected_skin) if skin_manager else true
		var can_afford = skin_manager.can_afford_skin(selected_skin) if skin_manager else false
		var price = skins[selected_skin].get("price", 0) if selected_skin in skins else 0
		
		if selected_skin == equipped:
			action_btn.text = "EQUIPPED"
			action_btn.disabled = true
		elif is_unlocked:
			action_btn.text = "EQUIP"
			action_btn.disabled = false
		elif can_afford:
			action_btn.text = "BUY (%d 💎)" % price
			action_btn.disabled = false
		else:
			action_btn.text = "NEED %d 💎" % price
			action_btn.disabled = true

func _on_action_pressed() -> void:
	if not skin_manager:
		return
	
	if skin_manager.is_skin_unlocked(selected_skin):
		skin_manager.equip_skin(selected_skin)
	else:
		if skin_manager.unlock_skin(selected_skin):
			skin_manager.equip_skin(selected_skin)
			var coins_label = get_node_or_null("CoinsLabel")
			if coins_label:
				coins_label.text = "💎 %d" % skin_manager.get_coins()
	
	_update_selection()

func close_panel() -> void:
	if not is_open:
		return
	
	is_open = false
	visible = false
	preview_sprite = null
	preview_container = null
	
	for child in get_children():
		child.queue_free()
	
	closed.emit()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_panel()
	elif event is InputEventScreenTouch and event.pressed:
		close_panel()
