extends CanvasLayer
class_name ThemesPanel

signal closed
signal theme_selected(theme_id: String)

var is_open: bool = false
var theme_buttons: Dictionary = {}
var selected_theme: String = "classic"
var preview_rect: ColorRect = null

# Theme definitions
const THEMES = {
	"classic": {
		"name": "Classic Tower",
		"description": "The original dark purple aesthetic",
		"icon": "🏰",
		"unlocked": true,
		"price": 0,
		"colors": {
			"bg": Color(0.02, 0.015, 0.06),
			"tower": Color(0.06, 0.04, 0.14),
			"wall": Color(0.1, 0.06, 0.25),
			"glow": Color(0.6, 0.3, 1),
			"platform": Color(0.5, 0.3, 0.8)
		}
	},
	"neon_city": {
		"name": "Neon City",
		"description": "Cyberpunk vibes with hot pink",
		"icon": "🌃",
		"unlocked": true,
		"price": 0,
		"colors": {
			"bg": Color(0.05, 0.02, 0.08),
			"tower": Color(0.08, 0.03, 0.12),
			"wall": Color(0.15, 0.05, 0.2),
			"glow": Color(1, 0.2, 0.6),
			"platform": Color(0.9, 0.3, 0.7)
		}
	},
	"ocean_depths": {
		"name": "Ocean Depths",
		"description": "Deep sea blues and teals",
		"icon": "🌊",
		"unlocked": true,
		"price": 0,
		"colors": {
			"bg": Color(0.01, 0.04, 0.08),
			"tower": Color(0.02, 0.08, 0.15),
			"wall": Color(0.05, 0.15, 0.25),
			"glow": Color(0.2, 0.8, 1),
			"platform": Color(0.3, 0.7, 0.9)
		}
	},
	"volcanic": {
		"name": "Volcanic",
		"description": "Hot lava and molten rock",
		"icon": "🌋",
		"unlocked": true,
		"price": 0,
		"colors": {
			"bg": Color(0.06, 0.02, 0.01),
			"tower": Color(0.12, 0.04, 0.02),
			"wall": Color(0.2, 0.08, 0.04),
			"glow": Color(1, 0.5, 0.1),
			"platform": Color(0.9, 0.4, 0.2)
		}
	},
	"forest": {
		"name": "Enchanted Forest",
		"description": "Mystical greens and nature",
		"icon": "🌲",
		"unlocked": true,
		"price": 0,
		"colors": {
			"bg": Color(0.02, 0.05, 0.03),
			"tower": Color(0.04, 0.1, 0.05),
			"wall": Color(0.08, 0.18, 0.1),
			"glow": Color(0.4, 1, 0.5),
			"platform": Color(0.5, 0.85, 0.4)
		}
	},
	"arctic": {
		"name": "Arctic",
		"description": "Frozen ice and snow",
		"icon": "❄️",
		"unlocked": true,
		"price": 0,
		"colors": {
			"bg": Color(0.04, 0.06, 0.1),
			"tower": Color(0.08, 0.12, 0.18),
			"wall": Color(0.15, 0.2, 0.3),
			"glow": Color(0.7, 0.9, 1),
			"platform": Color(0.8, 0.95, 1)
		}
	},
	"sunset": {
		"name": "Sunset",
		"description": "Warm orange and purple sky",
		"icon": "🌅",
		"unlocked": true,
		"price": 0,
		"colors": {
			"bg": Color(0.08, 0.03, 0.06),
			"tower": Color(0.15, 0.06, 0.1),
			"wall": Color(0.25, 0.1, 0.15),
			"glow": Color(1, 0.6, 0.3),
			"platform": Color(0.95, 0.5, 0.4)
		}
	},
	"midnight": {
		"name": "Midnight",
		"description": "Deep black with silver",
		"icon": "🌙",
		"unlocked": true,
		"price": 0,
		"colors": {
			"bg": Color(0.02, 0.02, 0.04),
			"tower": Color(0.05, 0.05, 0.08),
			"wall": Color(0.1, 0.1, 0.15),
			"glow": Color(0.7, 0.7, 0.85),
			"platform": Color(0.6, 0.6, 0.75)
		}
	}
}

var current_theme: String = "classic"

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_load_theme()

func _load_theme() -> void:
	var config = ConfigFile.new()
	if config.load("user://icy_tower_save.cfg") == OK:
		current_theme = config.get_value("settings", "theme", "classic")

func _save_theme() -> void:
	var config = ConfigFile.new()
	config.load("user://icy_tower_save.cfg")
	config.set_value("settings", "theme", current_theme)
	config.save("user://icy_tower_save.cfg")

func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()

func open_panel() -> void:
	if is_open:
		return
	
	is_open = true
	visible = true
	theme_buttons.clear()
	selected_theme = current_theme
	
	var vp = get_viewport().get_visible_rect().size
	var pw = 340.0
	var ph = 500.0
	var px = (vp.x - pw) / 2.0
	var py = (vp.y - ph) / 2.0
	
	# === OVERLAY ===
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.gui_input.connect(_on_overlay_input)
	add_child(overlay)
	
	# === MAIN PANEL ===
	var panel_outer = ColorRect.new()
	panel_outer.color = Color(0.4, 0.8, 0.9, 0.8)
	panel_outer.position = Vector2(px - 2, py - 2)
	panel_outer.size = Vector2(pw + 4, ph + 4)
	add_child(panel_outer)
	
	var panel = ColorRect.new()
	panel.color = Color(0.1, 0.12, 0.18)
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	add_child(panel)
	
	# Header gradient
	var header_grad = ColorRect.new()
	header_grad.color = Color(0.15, 0.2, 0.3, 0.6)
	header_grad.position = Vector2(px, py)
	header_grad.size = Vector2(pw, 70)
	add_child(header_grad)
	
	# === CLOSE BUTTON ===
	var close_btn = Button.new()
	close_btn.text = "×"
	close_btn.position = Vector2(px + 10, py + 8)
	close_btn.size = Vector2(32, 32)
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	close_btn.add_theme_color_override("font_hover_color", Color(1, 0.4, 0.4))
	close_btn.pressed.connect(close_panel)
	add_child(close_btn)
	
	# === TITLE ===
	var title = Label.new()
	title.text = "THEMES"
	title.position = Vector2(px, py + 12)
	title.size = Vector2(pw, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.8, 0.95, 1))
	add_child(title)
	
	# === PREVIEW AREA ===
	var preview_y = py + 50
	var preview_h = 100
	
	var preview_border = ColorRect.new()
	preview_border.color = Color(0.3, 0.4, 0.5, 0.5)
	preview_border.position = Vector2(px + 24, preview_y - 1)
	preview_border.size = Vector2(pw - 48, preview_h + 2)
	add_child(preview_border)
	
	preview_rect = ColorRect.new()
	preview_rect.name = "PreviewBG"
	preview_rect.position = Vector2(px + 25, preview_y)
	preview_rect.size = Vector2(pw - 50, preview_h)
	add_child(preview_rect)
	
	# Mini tower preview
	var tower_preview = ColorRect.new()
	tower_preview.name = "TowerPreview"
	tower_preview.position = Vector2(px + 100, preview_y + 10)
	tower_preview.size = Vector2(140, preview_h - 20)
	add_child(tower_preview)
	
	# Wall previews
	var left_wall = ColorRect.new()
	left_wall.name = "LeftWallPreview"
	left_wall.position = Vector2(px + 95, preview_y + 10)
	left_wall.size = Vector2(8, preview_h - 20)
	add_child(left_wall)
	
	var right_wall = ColorRect.new()
	right_wall.name = "RightWallPreview"
	right_wall.position = Vector2(px + 237, preview_y + 10)
	right_wall.size = Vector2(8, preview_h - 20)
	add_child(right_wall)
	
	# Platform previews
	for i in range(3):
		var plat = ColorRect.new()
		plat.name = "PlatformPreview%d" % i
		plat.position = Vector2(px + 110 + (i * 15), preview_y + 25 + (i * 25))
		plat.size = Vector2(60 - (i * 10), 8)
		add_child(plat)
	
	# === THEME NAME ===
	var theme_name = Label.new()
	theme_name.name = "ThemeNameLabel"
	theme_name.position = Vector2(px + 20, preview_y + preview_h + 8)
	theme_name.size = Vector2(pw - 40, 24)
	theme_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	theme_name.add_theme_font_size_override("font_size", 16)
	theme_name.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	add_child(theme_name)
	
	# === THEMES GRID ===
	var grid_y = preview_y + preview_h + 40
	var grid_cols = 4
	var btn_size = 60
	var btn_spacing = 14
	var grid_width = grid_cols * btn_size + (grid_cols - 1) * btn_spacing
	var grid_x = px + (pw - grid_width) / 2
	
	var i = 0
	for theme_id in THEMES.keys():
		var theme_data = THEMES[theme_id]
		var col = i % grid_cols
		var row = i / grid_cols
		var btn_x = grid_x + col * (btn_size + btn_spacing)
		var btn_y = grid_y + row * (btn_size + btn_spacing + 8)
		
		var btn = _create_theme_button(theme_id, theme_data, Vector2(btn_x, btn_y), btn_size)
		add_child(btn)
		theme_buttons[theme_id] = btn
		i += 1
	
	# === APPLY BUTTON ===
	var apply_btn = Button.new()
	apply_btn.name = "ApplyButton"
	apply_btn.text = "APPLY"
	apply_btn.position = Vector2(px + 60, py + ph - 58)
	apply_btn.size = Vector2(pw - 120, 46)
	apply_btn.add_theme_font_size_override("font_size", 18)
	apply_btn.pressed.connect(_on_apply_pressed)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.6, 0.8)
	btn_style.set_corner_radius_all(23)
	apply_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.4, 0.75, 0.95)
	btn_hover.set_corner_radius_all(23)
	apply_btn.add_theme_stylebox_override("hover", btn_hover)
	
	apply_btn.add_theme_color_override("font_color", Color.WHITE)
	add_child(apply_btn)
	
	_update_selection()

func _create_theme_button(theme_id: String, theme_data: Dictionary, pos: Vector2, size: int) -> Control:
	var container = Control.new()
	container.position = pos
	container.size = Vector2(size, size + 16)
	
	var is_current = theme_id == current_theme
	var colors = theme_data.get("colors", {})
	
	var btn = Button.new()
	btn.name = "Button"
	btn.position = Vector2.ZERO
	btn.size = Vector2(size, size)
	btn.pressed.connect(_on_theme_selected.bind(theme_id))
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = colors.get("tower", Color(0.1, 0.1, 0.15))
	btn_style.set_corner_radius_all(10)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = colors.get("glow", Color(0.5, 0.5, 0.6))
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_style)
	btn.add_theme_stylebox_override("pressed", btn_style)
	container.add_child(btn)
	
	# Icon
	var icon = Label.new()
	icon.text = theme_data.get("icon", "🎨")
	icon.position = Vector2(0, 8)
	icon.size = Vector2(size, size - 16)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 24)
	container.add_child(icon)
	
	# Current indicator
	if is_current:
		var check = Label.new()
		check.text = "✓"
		check.position = Vector2(0, size + 2)
		check.size = Vector2(size, 14)
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.add_theme_font_size_override("font_size", 10)
		check.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		container.add_child(check)
	
	return container

func _on_theme_selected(theme_id: String) -> void:
	selected_theme = theme_id
	_update_selection()

func _update_selection() -> void:
	var theme_data = THEMES.get(selected_theme, THEMES["classic"])
	var colors = theme_data.get("colors", {})
	
	# Update preview colors
	if preview_rect:
		preview_rect.color = colors.get("bg", Color(0.02, 0.02, 0.05))
	
	var tower = get_node_or_null("TowerPreview")
	if tower:
		tower.color = colors.get("tower", Color(0.06, 0.04, 0.14))
	
	var left = get_node_or_null("LeftWallPreview")
	var right = get_node_or_null("RightWallPreview")
	if left:
		left.color = colors.get("wall", Color(0.1, 0.06, 0.25))
	if right:
		right.color = colors.get("wall", Color(0.1, 0.06, 0.25))
	
	for i in range(3):
		var plat = get_node_or_null("PlatformPreview%d" % i)
		if plat:
			plat.color = colors.get("platform", Color(0.5, 0.3, 0.8))
	
	# Update name label
	var name_label = get_node_or_null("ThemeNameLabel")
	if name_label:
		var name_text = theme_data.get("name", selected_theme)
		if selected_theme == current_theme:
			name_label.text = "%s (Current)" % name_text
			name_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
		else:
			name_label.text = name_text
			name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	
	# Update button borders
	for theme_id in theme_buttons.keys():
		var btn_container = theme_buttons[theme_id]
		var btn = btn_container.get_node_or_null("Button") as Button
		if not btn:
			continue
		
		var t_data = THEMES.get(theme_id, {})
		var t_colors = t_data.get("colors", {})
		
		var style = StyleBoxFlat.new()
		style.bg_color = t_colors.get("tower", Color(0.1, 0.1, 0.15))
		style.set_corner_radius_all(10)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		
		if theme_id == selected_theme:
			style.border_color = Color(1, 0.9, 0.4)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
		else:
			style.border_color = t_colors.get("glow", Color(0.5, 0.5, 0.6))
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
	
	# Update apply button
	var apply_btn = get_node_or_null("ApplyButton")
	if apply_btn:
		if selected_theme == current_theme:
			apply_btn.text = "APPLIED"
			apply_btn.disabled = true
		else:
			apply_btn.text = "APPLY"
			apply_btn.disabled = false

func _on_apply_pressed() -> void:
	current_theme = selected_theme
	_save_theme()
	theme_selected.emit(current_theme)
	_update_selection()
	
	# Rebuild buttons to update checkmarks
	for child in get_children():
		child.queue_free()
	theme_buttons.clear()
	
	# Reopen with updated state
	is_open = false
	call_deferred("open_panel")

func get_current_theme() -> String:
	return current_theme

func get_theme_colors(theme_id: String = "") -> Dictionary:
	if theme_id.is_empty():
		theme_id = current_theme
	if theme_id in THEMES:
		return THEMES[theme_id].get("colors", {})
	return THEMES["classic"].get("colors", {})

func close_panel() -> void:
	if not is_open:
		return
	
	is_open = false
	visible = false
	preview_rect = null
	
	for child in get_children():
		child.queue_free()
	
	closed.emit()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_panel()
	elif event is InputEventScreenTouch and event.pressed:
		close_panel()

