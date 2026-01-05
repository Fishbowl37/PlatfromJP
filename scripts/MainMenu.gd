extends Control

@onready var character_sprite: AnimatedSprite2D = $CenterContainer/CharacterDisplay/AnimatedSprite2D
@onready var play_button: Button = $ButtonContainer/PlayButton
@onready var free_fall_button: Button = $ButtonContainer/SecondaryButtons/FreeFallButton
@onready var settings_button: Button = $ButtonContainer/BottomRow/SettingsButton
@onready var skins_button: Button = $ButtonContainer/BottomRow/SkinsButton
@onready var themes_button: Button = $ButtonContainer/BottomRow/ThemesButton
@onready var leaderboard_button: Button = $ButtonContainer/BottomRow/LeaderboardButton

var float_tween: Tween
var base_position: Vector2

# Panels
var settings_panel: SettingsPanel
var skins_panel: SkinsPanel
var themes_panel: ThemesPanel
var leaderboard_panel: LeaderboardPanel

# Announcement popup
var announcement_popup: AnnouncementPopup
var pending_announcements: Array = []

# Skin manager reference
var skin_manager: Node = null

# Gem display
var gem_label: Label = null

# Google Sign-In button
var google_signin_button: Button = null

# Name change dialog
var name_change_dialog: CanvasLayer = null

func _ready() -> void:
	_setup_panels()
	_setup_character_animation()
	_setup_buttons()
	_setup_gem_display()
	_setup_remote_config()
	_setup_banner_ads()
	_start_floating_animation()
	_animate_entrance()

func _exit_tree() -> void:
	if float_tween:
		float_tween.kill()
	
	# Hide banner when leaving menu
	if has_node("/root/AdsManager"):
		var ads_manager = get_node("/root/AdsManager")
		ads_manager.set_banner_visible(false)

func _notification(what: int) -> void:
	# Show banner when menu becomes visible
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		if has_node("/root/AdsManager"):
			var ads_manager = get_node("/root/AdsManager")
			if ads_manager.should_show_banner_in_menu():
				ads_manager.set_banner_visible(true)

func _setup_panels() -> void:
	# Setup settings panel
	settings_panel = SettingsPanel.new()
	settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(settings_panel)
	
	# Setup skins panel
	skins_panel = SkinsPanel.new()
	skins_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(skins_panel)
	
	# Setup themes panel
	themes_panel = ThemesPanel.new()
	themes_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	themes_panel.theme_selected.connect(_on_theme_selected)
	add_child(themes_panel)
	
	# Setup leaderboard panel
	leaderboard_panel = LeaderboardPanel.new()
	leaderboard_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(leaderboard_panel)
	
	# Setup announcement popup
	announcement_popup = AnnouncementPopup.new()
	announcement_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	announcement_popup.closed.connect(_on_announcement_closed)
	add_child(announcement_popup)
	
	# Setup skin manager
	_setup_skin_manager()

func _setup_skin_manager() -> void:
	# Use the global GameManager's skin manager
	if GameManager and GameManager.skin_manager:
		skin_manager = GameManager.skin_manager
		skin_manager.skin_changed.connect(_on_skin_changed)
	
	# Pass skin manager to skins panel
	if skins_panel and skin_manager:
		skins_panel.set_skin_manager(skin_manager)
	
	# Update character with current skin
	_update_character_skin()

func _setup_gem_display() -> void:
	# Create gem display container in top-right corner
	var gem_container = PanelContainer.new()
	gem_container.name = "GemContainer"
	
	# Style the container
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.18, 0.9)
	style.border_color = Color(0.2, 0.8, 0.9, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	gem_container.add_theme_stylebox_override("panel", style)
	
	# Position in top-right
	gem_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gem_container.position = Vector2(-120, 12)
	gem_container.size = Vector2(100, 36)
	
	# Create the label
	gem_label = Label.new()
	gem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gem_label.add_theme_font_size_override("font_size", 18)
	gem_label.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
	gem_container.add_child(gem_label)
	
	add_child(gem_container)
	_update_gem_display()
	
	# Connect to skin manager's coins_changed signal to update display
	if skin_manager:
		skin_manager.coins_changed.connect(_on_coins_changed)
	
	# Setup Google Sign-In button
	_setup_google_signin_button()

func _update_gem_display() -> void:
	if gem_label and skin_manager:
		var coins = skin_manager.get_coins()
		gem_label.text = "💎 %d" % coins

func _on_coins_changed(_new_amount: int) -> void:
	_update_gem_display()

func _setup_google_signin_button() -> void:
	# Check if we should show the button
	if not has_node("/root/AuthManager"):
		return
	
	var auth_manager = get_node("/root/AuthManager")
	
	# Don't show if already linked
	if auth_manager.is_linked():
		return
	
	# Create the button
	var button = Button.new()
	button.name = "GoogleSignInButton"
	button.text = "🔗 Link Account  +500 💎"
	button.custom_minimum_size = Vector2(200, 42)
	
	# Style the button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.12, 0.25, 0.95)
	btn_style.border_color = Color(0.95, 0.7, 0.2, 0.8)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.2, 0.15, 0.3, 0.95)
	btn_hover.border_color = Color(1.0, 0.8, 0.3, 1.0)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(12)
	button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.1, 0.08, 0.2, 0.95)
	btn_pressed.border_color = Color(0.8, 0.6, 0.2, 0.8)
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(12)
	button.add_theme_stylebox_override("pressed", btn_pressed)
	
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(1, 0.95, 0.9))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	
	# Position below the bottom row buttons
	button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	button.position = Vector2(-100, -70)
	
	button.pressed.connect(_on_google_signin_pressed)
	
	add_child(button)
	google_signin_button = button
	
	# Connect to auth signals
	auth_manager.account_linked.connect(_on_account_linked)
	auth_manager.link_reward_granted.connect(_on_link_reward_granted)
	
	# Animate entrance
	button.modulate.a = 0
	button.position.y += 30
	var target_y = button.position.y - 30
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.6)
	tween.tween_property(button, "position:y", target_y, 0.4)
	tween.parallel().tween_property(button, "modulate:a", 1.0, 0.3)

func _on_google_signin_pressed() -> void:
	if not has_node("/root/AuthManager"):
		return
	
	var auth_manager = get_node("/root/AuthManager")
	
	# Button press effect
	_button_press_effect(google_signin_button)
	
	# Start Google Sign-In
	print("MainMenu: User requested Google Sign-In")
	auth_manager.link_with_google()

func _on_account_linked(success: bool) -> void:
	if success:
		# Hide the button with animation
		if google_signin_button:
			var tween = create_tween()
			tween.tween_property(google_signin_button, "modulate:a", 0.0, 0.3)
			tween.tween_property(google_signin_button, "position:y", google_signin_button.position.y + 30, 0.3)
			tween.tween_callback(func(): 
				if google_signin_button:
					google_signin_button.queue_free()
					google_signin_button = null
			)
		
		# Show name change dialog after a short delay
		await get_tree().create_timer(0.5).timeout
		_show_name_change_dialog()

func _on_link_reward_granted(diamonds: int) -> void:
	# Show reward popup
	_show_reward_popup(diamonds)
	# Update gem display
	_update_gem_display()

func _show_reward_popup(diamonds: int) -> void:
	# Create floating "+500 💎" animation
	var popup = Label.new()
	popup.text = "+%d 💎" % diamonds
	popup.add_theme_font_size_override("font_size", 28)
	popup.add_theme_color_override("font_color", Color(0.3, 1.0, 0.95))
	popup.add_theme_color_override("font_outline_color", Color(0.1, 0.3, 0.4))
	popup.add_theme_constant_override("outline_size", 3)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Position at center of screen
	var vp = get_viewport().get_visible_rect().size
	popup.position = Vector2(vp.x / 2 - 60, vp.y / 2 - 50)
	popup.size = Vector2(120, 50)
	
	add_child(popup)
	
	# Animate: float up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 80, 1.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.chain().tween_callback(popup.queue_free)

func _show_name_change_dialog() -> void:
	if name_change_dialog:
		return
	
	name_change_dialog = CanvasLayer.new()
	name_change_dialog.layer = 100
	add_child(name_change_dialog)
	
	var vp = get_viewport().get_visible_rect().size
	
	# Overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.size = vp
	name_change_dialog.add_child(overlay)
	
	# Panel
	var pw = 300.0
	var ph = 220.0
	var px = (vp.x - pw) / 2.0
	var py = (vp.y - ph) / 2.0
	
	var panel = PanelContainer.new()
	panel.position = Vector2(px, py)
	panel.size = Vector2(pw, ph)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.18)
	style.border_color = Color(0.4, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	name_change_dialog.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🎉 Account Linked!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	vbox.add_child(title)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Choose your display name:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
	vbox.add_child(subtitle)
	
	# Name input
	var name_input = LineEdit.new()
	name_input.name = "NameInput"
	name_input.placeholder_text = "Enter name..."
	name_input.max_length = 16
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.custom_minimum_size = Vector2(0, 40)
	
	# Get current name
	if has_node("/root/AuthManager"):
		name_input.text = get_node("/root/AuthManager").get_display_name()
	
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.15, 0.12, 0.22)
	input_style.border_color = Color(0.3, 0.25, 0.45)
	input_style.set_border_width_all(2)
	input_style.set_corner_radius_all(8)
	input_style.content_margin_left = 10
	input_style.content_margin_right = 10
	name_input.add_theme_stylebox_override("normal", input_style)
	name_input.add_theme_font_size_override("font_size", 16)
	name_input.add_theme_color_override("font_color", Color(1, 1, 1))
	name_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.45, 0.6))
	vbox.add_child(name_input)
	
	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)
	
	# Skip button
	var skip_btn = Button.new()
	skip_btn.text = "Keep Name"
	skip_btn.custom_minimum_size = Vector2(100, 38)
	skip_btn.add_theme_font_size_override("font_size", 14)
	var skip_style = StyleBoxFlat.new()
	skip_style.bg_color = Color(0.2, 0.18, 0.28)
	skip_style.set_corner_radius_all(10)
	skip_btn.add_theme_stylebox_override("normal", skip_style)
	skip_btn.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
	skip_btn.pressed.connect(_on_name_dialog_skip)
	btn_hbox.add_child(skip_btn)
	
	# Confirm button
	var confirm_btn = Button.new()
	confirm_btn.text = "Save"
	confirm_btn.custom_minimum_size = Vector2(100, 38)
	confirm_btn.add_theme_font_size_override("font_size", 14)
	var confirm_style = StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.3, 0.6, 0.4)
	confirm_style.set_corner_radius_all(10)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	var confirm_hover = StyleBoxFlat.new()
	confirm_hover.bg_color = Color(0.35, 0.7, 0.45)
	confirm_hover.set_corner_radius_all(10)
	confirm_btn.add_theme_stylebox_override("hover", confirm_hover)
	confirm_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	confirm_btn.pressed.connect(_on_name_dialog_confirm.bind(name_input))
	btn_hbox.add_child(confirm_btn)
	
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
	
	# Focus the input
	await get_tree().create_timer(0.1).timeout
	name_input.grab_focus()

func _on_name_dialog_skip() -> void:
	_close_name_dialog()

func _on_name_dialog_confirm(name_input: LineEdit) -> void:
	var new_name = name_input.text.strip_edges()
	
	if new_name.length() >= 2 and has_node("/root/AuthManager"):
		get_node("/root/AuthManager").set_display_name(new_name)
		print("MainMenu: Display name changed to: " + new_name)
	
	_close_name_dialog()

func _close_name_dialog() -> void:
	if not name_change_dialog:
		return
	
	var tween = create_tween()
	tween.tween_property(name_change_dialog, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		if name_change_dialog:
			name_change_dialog.queue_free()
			name_change_dialog = null
	)

func _setup_remote_config() -> void:
	# Connect to RemoteConfig signals if available
	if has_node("/root/RemoteConfig"):
		var remote_config = get_node("/root/RemoteConfig")
		remote_config.config_loaded.connect(_on_remote_config_loaded)
		remote_config.announcement_received.connect(_on_announcement_received)
		remote_config.ads_config_loaded.connect(_on_ads_config_loaded)
		
		# If already loaded, apply immediately
		if remote_config.is_loaded:
			_apply_feature_flags()
	else:
		# RemoteConfig not available, show all features
		pass

func _setup_banner_ads() -> void:
	# Wait a moment for AdsManager to initialize
	await get_tree().create_timer(1.0).timeout
	
	# Check if banner should be shown
	if has_node("/root/AdsManager"):
		var ads_manager = get_node("/root/AdsManager")
		if ads_manager.should_show_banner_in_menu():
			ads_manager.set_banner_visible(true)

func _on_ads_config_loaded(_ads_config: Dictionary) -> void:
	# Update banner visibility when ads config changes
	if has_node("/root/AdsManager"):
		var ads_manager = get_node("/root/AdsManager")
		if ads_manager.should_show_banner_in_menu():
			ads_manager.set_banner_visible(true)
		else:
			ads_manager.set_banner_visible(false)

func _on_remote_config_loaded(_config: Dictionary) -> void:
	_apply_feature_flags()

func _apply_feature_flags() -> void:
	if not has_node("/root/RemoteConfig"):
		return
	
	var remote_config = get_node("/root/RemoteConfig")
	
	# Toggle features based on server config
	if skins_button:
		skins_button.visible = remote_config.is_feature_enabled("skins")
	if themes_button:
		themes_button.visible = remote_config.is_feature_enabled("themes")
	if leaderboard_button:
		leaderboard_button.visible = remote_config.is_feature_enabled("leaderboard")
	if free_fall_button:
		free_fall_button.visible = remote_config.is_feature_enabled("free_fall_mode")

func _on_announcement_received(announcement: Dictionary) -> void:
	# Queue announcement to show
	pending_announcements.append(announcement)
	_show_next_announcement()

func _show_next_announcement() -> void:
	if pending_announcements.is_empty():
		return
	
	if announcement_popup and not announcement_popup.is_open:
		var next_announcement = pending_announcements.pop_front()
		announcement_popup.show_announcement(next_announcement)

func _on_announcement_closed(announcement_id: String) -> void:
	# Mark as shown in RemoteConfig
	if has_node("/root/RemoteConfig") and announcement_id != "":
		var remote_config = get_node("/root/RemoteConfig")
		remote_config.mark_announcement_shown(announcement_id)
	
	# Show next announcement if any
	_show_next_announcement()

func _update_character_skin() -> void:
	if character_sprite and skin_manager:
		var skin_data = skin_manager.get_equipped_skin_data()
		character_sprite.modulate = skin_data.get("sprite_modulate", Color(1, 1, 1))
		
		# Load custom sprite frames if skin has them
		var sprite_frames_path = skin_data.get("sprite_frames_path", "")
		if sprite_frames_path != "":
			var custom_frames = load(sprite_frames_path)
			if custom_frames:
				character_sprite.sprite_frames = custom_frames
				character_sprite.play("idle")
		else:
			# Load default sprite frames
			var default_frames = load("res://assets/sprites/player/player_frames.tres")
			if default_frames:
				character_sprite.sprite_frames = default_frames
				character_sprite.play("idle")

func _on_skin_changed(_skin_id: String) -> void:
	_update_character_skin()

func _on_theme_selected(_theme_id: String) -> void:
	# Theme has been applied - could update menu visuals here if desired
	pass

func _setup_character_animation() -> void:
	if character_sprite:
		character_sprite.play("idle")

func _setup_buttons() -> void:
	play_button.pressed.connect(_on_play_pressed)
	free_fall_button.pressed.connect(_on_free_fall_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	skins_button.pressed.connect(_on_skins_pressed)
	themes_button.pressed.connect(_on_themes_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)

func _start_floating_animation() -> void:
	var char_display = $CenterContainer/CharacterDisplay
	if char_display:
		base_position = char_display.position
		_do_float()

func _do_float() -> void:
	var char_display = $CenterContainer/CharacterDisplay
	if not is_instance_valid(char_display):
		return
	
	if float_tween:
		float_tween.kill()
	float_tween = create_tween()
	float_tween.set_trans(Tween.TRANS_SINE)
	float_tween.set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(char_display, "position:y", base_position.y - 6, 1.0)
	float_tween.tween_property(char_display, "position:y", base_position.y + 6, 1.0)
	float_tween.set_loops()

func _animate_entrance() -> void:
	# Title entrance
	var title = $TitleContainer/GameTitle
	if title:
		var original_pos = title.position
		title.position.y -= 40
		title.modulate.a = 0
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(title, "position:y", original_pos.y, 0.5)
		tween.parallel().tween_property(title, "modulate:a", 1.0, 0.35)
	
	# Play button - special entrance
	if play_button:
		var original_scale = play_button.scale
		play_button.scale = Vector2(0.8, 0.8)
		play_button.modulate.a = 0
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.2)
		tween.tween_property(play_button, "scale", original_scale, 0.4)
		tween.parallel().tween_property(play_button, "modulate:a", 1.0, 0.3)
	
	# Secondary buttons - slide in from sides
	var secondary_buttons = [free_fall_button]
	for i in range(secondary_buttons.size()):
		var btn = secondary_buttons[i]
		if btn:
			var original_x = btn.position.x
			btn.position.x += (60 if i == 1 else -60)
			btn.modulate.a = 0
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_QUAD)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_interval(0.35)
			tween.tween_property(btn, "position:x", original_x, 0.35)
			tween.parallel().tween_property(btn, "modulate:a", 1.0, 0.25)
	
	# Bottom row - fade in together
	var bottom_buttons = [settings_button, skins_button, themes_button, leaderboard_button]
	for btn in bottom_buttons:
		if btn:
			btn.modulate.a = 0
			var tween = create_tween()
			tween.tween_interval(0.5)
			tween.tween_property(btn, "modulate:a", 1.0, 0.3)
	
	# Gem display - slide in from right
	var gem_container = get_node_or_null("GemContainer")
	if gem_container:
		var original_x = gem_container.position.x
		gem_container.position.x += 80
		gem_container.modulate.a = 0
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.3)
		tween.tween_property(gem_container, "position:x", original_x, 0.4)
		tween.parallel().tween_property(gem_container, "modulate:a", 1.0, 0.3)

func _on_play_pressed() -> void:
	# Hide banner when starting game
	if has_node("/root/AdsManager"):
		var ads_manager = get_node("/root/AdsManager")
		ads_manager.set_banner_visible(false)
	
	_button_press_effect(play_button)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_go_to_game)

func _go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_free_fall_pressed() -> void:
	# Hide banner when starting game
	if has_node("/root/AdsManager"):
		var ads_manager = get_node("/root/AdsManager")
		ads_manager.set_banner_visible(false)
	
	_button_press_effect(free_fall_button)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_go_to_free_fall)

func _go_to_free_fall() -> void:
	get_tree().change_scene_to_file("res://scenes/FreeFallMode.tscn")

func _on_settings_pressed() -> void:
	_button_press_effect(settings_button)
	if settings_panel:
		settings_panel.open_panel()

func _on_skins_pressed() -> void:
	_button_press_effect(skins_button)
	if skins_panel:
		if skin_manager:
			skins_panel.set_skin_manager(skin_manager)
		skins_panel.open_panel()
		# Connect panel closed to refresh gem display
		if not skins_panel.closed.is_connected(_on_skins_panel_closed):
			skins_panel.closed.connect(_on_skins_panel_closed)

func _on_skins_panel_closed() -> void:
	_update_gem_display()

func _on_themes_pressed() -> void:
	_button_press_effect(themes_button)
	if themes_panel:
		themes_panel.open_panel()

func _on_leaderboard_pressed() -> void:
	_button_press_effect(leaderboard_button)
	if leaderboard_panel:
		leaderboard_panel.open_panel()

func _button_press_effect(button: Button) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.08)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)

func _show_coming_soon(feature_name: String) -> void:
	print("%s - Coming soon!" % feature_name)
