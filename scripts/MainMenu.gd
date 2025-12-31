extends Control

@onready var character_sprite: AnimatedSprite2D = $CenterContainer/CharacterDisplay/AnimatedSprite2D
@onready var play_button: Button = $ButtonContainer/PlayButton
@onready var stages_button: Button = $ButtonContainer/SecondaryButtons/StagesButton
@onready var competition_button: Button = $ButtonContainer/SecondaryButtons/CompetitionButton
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

# Skin manager reference
var skin_manager: Node = null

# Gem display
var gem_label: Label = null

func _ready() -> void:
	_setup_panels()
	_setup_character_animation()
	_setup_buttons()
	_setup_gem_display()
	_start_floating_animation()
	_animate_entrance()

func _exit_tree() -> void:
	if float_tween:
		float_tween.kill()

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

func _update_gem_display() -> void:
	if gem_label and skin_manager:
		var coins = skin_manager.get_coins()
		gem_label.text = "💎 %d" % coins

func _on_coins_changed(_new_amount: int) -> void:
	_update_gem_display()

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
	stages_button.pressed.connect(_on_stages_pressed)
	competition_button.pressed.connect(_on_competition_pressed)
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
	var secondary_buttons = [stages_button, competition_button]
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
	_button_press_effect(play_button)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_go_to_game)

func _go_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_stages_pressed() -> void:
	_button_press_effect(stages_button)
	_show_coming_soon("Stages")

func _on_competition_pressed() -> void:
	_button_press_effect(competition_button)
	_show_coming_soon("Competition")

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
	_show_coming_soon("Leaderboard")

func _button_press_effect(button: Button) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.08)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)

func _show_coming_soon(feature_name: String) -> void:
	print("%s - Coming soon!" % feature_name)
