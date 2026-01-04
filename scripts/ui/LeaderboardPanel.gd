extends CanvasLayer
class_name LeaderboardPanel

signal closed

var is_open: bool = false
var score_items: Array = []
var scroll_container: ScrollContainer = null
var scores_container: VBoxContainer = null
var loading_label: Label = null
var player_rank_label: Label = null

# Tab system
var current_mode: String = "tower"
var tab_buttons: Dictionary = {}
var tab_container: HBoxContainer = null

# Panel references for repositioning
var panel_x: float = 0.0
var panel_y: float = 0.0
var panel_width: float = 0.0

# Reference to managers
var leaderboard_manager: Node = null
var auth_manager: Node = null

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	# Connect to managers
	await get_tree().process_frame
	_connect_managers()

func _connect_managers() -> void:
	if has_node("/root/LeaderboardManager"):
		leaderboard_manager = get_node("/root/LeaderboardManager")
		leaderboard_manager.leaderboard_loaded.connect(_on_leaderboard_loaded)
		leaderboard_manager.leaderboard_error.connect(_on_leaderboard_error)
	
	if has_node("/root/AuthManager"):
		auth_manager = get_node("/root/AuthManager")

func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()

func open_panel() -> void:
	if is_open:
		return
	
	is_open = true
	visible = true
	score_items.clear()
	current_mode = "tower"  # Default to tower mode
	
	var vp = get_viewport().get_visible_rect().size
	var pw = 340.0
	var ph = 560.0  # Slightly taller to accommodate tabs
	var px = (vp.x - pw) / 2.0
	var py = (vp.y - ph) / 2.0
	
	# Store for later reference
	panel_x = px
	panel_y = py
	panel_width = pw
	
	# === OVERLAY ===
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.position = Vector2.ZERO
	overlay.size = vp
	overlay.gui_input.connect(_on_overlay_input)
	add_child(overlay)
	
	# === MAIN PANEL with gradient border ===
	var panel_outer = ColorRect.new()
	panel_outer.color = Color(1.0, 0.85, 0.2, 0.9)  # Gold border
	panel_outer.position = Vector2(px - 2, py - 2)
	panel_outer.size = Vector2(pw + 4, ph + 4)
	add_child(panel_outer)
	
	var panel = ColorRect.new()
	panel.color = Color(0.08, 0.05, 0.15)
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	add_child(panel)
	
	# Inner glow overlay
	var inner_glow = ColorRect.new()
	inner_glow.color = Color(0.15, 0.1, 0.25, 0.6)
	inner_glow.position = Vector2(px, py)
	inner_glow.size = Vector2(pw, 70)
	add_child(inner_glow)
	
	# === CLOSE BUTTON ===
	var close_btn = Button.new()
	close_btn.text = "×"
	close_btn.position = Vector2(px + 10, py + 8)
	close_btn.size = Vector2(32, 32)
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8))
	close_btn.add_theme_color_override("font_hover_color", Color(1, 0.4, 0.4))
	close_btn.pressed.connect(close_panel)
	add_child(close_btn)
	
	# === TITLE ===
	var title = Label.new()
	title.text = "🏆 LEADERBOARD"
	title.position = Vector2(px, py + 12)
	title.size = Vector2(pw, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	add_child(title)
	
	# === TAB BUTTONS ===
	_create_tabs(px, py + 48, pw)
	
	# === PLAYER RANK DISPLAY ===
	player_rank_label = Label.new()
	player_rank_label.name = "PlayerRankLabel"
	player_rank_label.position = Vector2(px + 15, py + 95)
	player_rank_label.size = Vector2(pw - 30, 24)
	player_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_rank_label.add_theme_font_size_override("font_size", 13)
	player_rank_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(player_rank_label)
	_update_player_rank_label()
	
	# === COLUMN HEADERS ===
	var header_y = py + 122
	_create_header_label("#", px + 15, header_y, 30, HORIZONTAL_ALIGNMENT_CENTER)
	_create_header_label("PLAYER", px + 50, header_y, 160, HORIZONTAL_ALIGNMENT_LEFT)
	_create_header_label("SCORE", px + 215, header_y, 110, HORIZONTAL_ALIGNMENT_RIGHT)
	
	# Divider line
	var divider = ColorRect.new()
	divider.color = Color(0.3, 0.25, 0.45, 0.8)
	divider.position = Vector2(px + 15, header_y + 22)
	divider.size = Vector2(pw - 30, 1)
	add_child(divider)
	
	# === SCROLL CONTAINER FOR SCORES ===
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(px + 10, header_y + 28)
	scroll_container.size = Vector2(pw - 20, ph - 190)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)
	
	scores_container = VBoxContainer.new()
	scores_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scores_container.add_theme_constant_override("separation", 2)
	scroll_container.add_child(scores_container)
	
	# === LOADING INDICATOR ===
	loading_label = Label.new()
	loading_label.text = "Loading..."
	loading_label.position = Vector2(px, py + ph / 2 - 20)
	loading_label.size = Vector2(pw, 40)
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 16)
	loading_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	add_child(loading_label)
	
	# === REFRESH BUTTON ===
	var refresh_btn = Button.new()
	refresh_btn.text = "↻ REFRESH"
	refresh_btn.position = Vector2(px + pw/2 - 60, py + ph - 50)
	refresh_btn.size = Vector2(120, 36)
	refresh_btn.add_theme_font_size_override("font_size", 13)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.15, 0.35)
	btn_style.set_corner_radius_all(18)
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.4, 0.3, 0.6)
	refresh_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.3, 0.2, 0.45)
	btn_hover.set_corner_radius_all(18)
	btn_hover.border_width_left = 1
	btn_hover.border_width_top = 1
	btn_hover.border_width_right = 1
	btn_hover.border_width_bottom = 1
	btn_hover.border_color = Color(0.5, 0.4, 0.7)
	refresh_btn.add_theme_stylebox_override("hover", btn_hover)
	
	refresh_btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.9))
	add_child(refresh_btn)
	
	# Fetch leaderboard data for current mode
	_fetch_leaderboard()

func _create_tabs(x: float, y: float, width: float) -> void:
	tab_container = HBoxContainer.new()
	tab_container.position = Vector2(x + 15, y)
	tab_container.size = Vector2(width - 30, 38)
	tab_container.add_theme_constant_override("separation", 8)
	tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(tab_container)
	
	# Tower mode tab
	var tower_btn = _create_tab_button("🗼 TOWER", "tower")
	tab_container.add_child(tower_btn)
	tab_buttons["tower"] = tower_btn
	
	# Free Fall mode tab
	var freefall_btn = _create_tab_button("⬇️ FREE FALL", "freefall")
	tab_container.add_child(freefall_btn)
	tab_buttons["freefall"] = freefall_btn
	
	# Update initial tab appearance
	_update_tab_styles()

func _create_tab_button(text: String, mode: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 36)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_tab_pressed.bind(mode))
	return btn

func _update_tab_styles() -> void:
	for mode in tab_buttons:
		var btn = tab_buttons[mode] as Button
		var is_active = mode == current_mode
		
		var style = StyleBoxFlat.new()
		if is_active:
			# Active tab - highlighted
			style.bg_color = Color(0.25, 0.4, 0.55, 0.95)
			style.border_color = Color(0.5, 0.8, 1.0, 0.9)
			style.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			# Inactive tab - muted
			style.bg_color = Color(0.15, 0.12, 0.22, 0.8)
			style.border_color = Color(0.3, 0.25, 0.4, 0.6)
			style.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7))
		
		style.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("normal", style)
		
		# Hover style
		var hover_style = StyleBoxFlat.new()
		if is_active:
			hover_style.bg_color = Color(0.3, 0.45, 0.6, 0.95)
			hover_style.border_color = Color(0.6, 0.85, 1.0, 1.0)
			hover_style.set_border_width_all(2)
		else:
			hover_style.bg_color = Color(0.2, 0.17, 0.28, 0.9)
			hover_style.border_color = Color(0.4, 0.35, 0.5, 0.8)
			hover_style.set_border_width_all(1)
		hover_style.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("hover", hover_style)

func _on_tab_pressed(mode: String) -> void:
	if mode == current_mode:
		return
	
	current_mode = mode
	_update_tab_styles()
	_fetch_leaderboard()

func _create_header_label(text: String, x: float, y: float, width: float, align: HorizontalAlignment) -> void:
	var label = Label.new()
	label.text = text
	label.position = Vector2(x, y)
	label.size = Vector2(width, 20)
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6))
	add_child(label)

func _update_player_rank_label() -> void:
	if not player_rank_label:
		return
	
	if not leaderboard_manager:
		player_rank_label.text = ""
		return
	
	var rank = leaderboard_manager.get_player_rank(current_mode)
	var display_name = ""
	if auth_manager:
		display_name = auth_manager.get_display_name()
	
	if rank > 0:
		player_rank_label.text = "Your rank: #%d as %s" % [rank, display_name]
		if rank <= 3:
			player_rank_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		elif rank <= 10:
			player_rank_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		else:
			player_rank_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	else:
		player_rank_label.text = "Playing as: %s" % display_name if display_name else "Not ranked yet"
		player_rank_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))

func _fetch_leaderboard() -> void:
	if loading_label:
		loading_label.text = "Loading..."
		loading_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		loading_label.visible = true
	
	# Clear existing scores
	if scores_container:
		for child in scores_container.get_children():
			child.queue_free()
	score_items.clear()
	
	if leaderboard_manager:
		leaderboard_manager.fetch_leaderboard(current_mode)
	else:
		_show_error("Leaderboard not available")

func _on_leaderboard_loaded(scores: Array, game_mode: String) -> void:
	# Ignore if panel is closed or not for our current mode
	if not is_open or game_mode != current_mode:
		return
	
	if loading_label:
		loading_label.visible = false
	
	_update_player_rank_label()
	_populate_scores(scores)

func _on_leaderboard_error(error: String, game_mode: String) -> void:
	# Ignore if panel is closed or not for our current mode
	if not is_open or game_mode != current_mode:
		return
	
	_show_error(error)

func _show_error(message: String) -> void:
	if loading_label:
		loading_label.text = message
		loading_label.visible = true
		loading_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))

func _populate_scores(scores: Array) -> void:
	# Safety check - panel might have been closed
	if not scores_container:
		return
	
	# Clear existing items
	for child in scores_container.get_children():
		child.queue_free()
	score_items.clear()
	
	if scores.is_empty():
		var empty_label = Label.new()
		if current_mode == "tower":
			empty_label.text = "No scores yet!\nBe the first to climb!"
		else:
			empty_label.text = "No scores yet!\nBe the first to fall!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		scores_container.add_child(empty_label)
		return
	
	var current_user_id = ""
	if auth_manager:
		current_user_id = auth_manager.get_user_id()
	
	for score_data in scores:
		var item = _create_score_item(score_data, current_user_id)
		scores_container.add_child(item)
		score_items.append(item)

func _create_score_item(score_data: Dictionary, current_user_id: String) -> Control:
	var rank = score_data.get("rank", 0)
	var display_name = score_data.get("display_name", "Unknown")
	var score = score_data.get("score", 0)
	var user_id = score_data.get("user_id", "")
	var is_current_player = user_id == current_user_id and current_user_id != ""
	
	var item = PanelContainer.new()
	item.custom_minimum_size = Vector2(300, 44)
	
	var style = StyleBoxFlat.new()
	if is_current_player:
		style.bg_color = Color(0.2, 0.35, 0.5, 0.6)
		style.border_color = Color(0.4, 0.7, 1.0, 0.5)
		style.border_width_left = 2
	elif rank <= 3:
		style.bg_color = Color(0.2, 0.15, 0.1, 0.4)
	else:
		style.bg_color = Color(0.12, 0.1, 0.18, 0.3)
	style.set_corner_radius_all(6)
	item.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	item.add_child(hbox)
	
	# Rank
	var rank_label = Label.new()
	rank_label.custom_minimum_size = Vector2(35, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 14)
	
	match rank:
		1:
			rank_label.text = "🥇"
			rank_label.add_theme_font_size_override("font_size", 20)
		2:
			rank_label.text = "🥈"
			rank_label.add_theme_font_size_override("font_size", 20)
		3:
			rank_label.text = "🥉"
			rank_label.add_theme_font_size_override("font_size", 20)
		_:
			rank_label.text = str(rank)
			rank_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.7))
	hbox.add_child(rank_label)
	
	# Player name
	var name_label = Label.new()
	name_label.text = display_name
	name_label.custom_minimum_size = Vector2(140, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 14)
	if is_current_player:
		name_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	elif rank <= 3:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	else:
		name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.9))
	hbox.add_child(name_label)
	
	# Score
	var score_label = Label.new()
	score_label.text = _format_score(score)
	score_label.custom_minimum_size = Vector2(90, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 15)
	if rank == 1:
		score_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	elif rank <= 3:
		score_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	else:
		score_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	hbox.add_child(score_label)
	
	return item

func _format_score(score: int) -> String:
	var str_num = str(score)
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	return result

func _on_refresh_pressed() -> void:
	if loading_label:
		loading_label.text = "Loading..."
		loading_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		loading_label.visible = true
	
	# Clear scores while loading
	for child in scores_container.get_children():
		child.queue_free()
	score_items.clear()
	
	if leaderboard_manager:
		leaderboard_manager.fetch_leaderboard(current_mode, true)

func close_panel() -> void:
	if not is_open:
		return
	
	is_open = false
	visible = false
	loading_label = null
	player_rank_label = null
	scroll_container = null
	scores_container = null
	tab_container = null
	tab_buttons.clear()
	score_items.clear()
	
	for child in get_children():
		child.queue_free()
	
	closed.emit()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_panel()
	elif event is InputEventScreenTouch and event.pressed:
		close_panel()
