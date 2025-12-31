extends CanvasLayer
class_name HUD

# Top bar elements
@onready var score_label: Label = $SpinContainer/TopBar/MarginContainer/HBoxContainer/ScoreContainer/ScoreLabel
@onready var distance_label: Label = $SpinContainer/TopBar/MarginContainer/HBoxContainer/DistanceContainer/DistanceLabel
@onready var streak_indicator: Control = $SpinContainer/TopBar/MarginContainer/HBoxContainer/StreakIndicator
@onready var streak_icon: Label = $SpinContainer/TopBar/MarginContainer/HBoxContainer/StreakIndicator/StreakIcon

# Combo display
@onready var combo_container: PanelContainer = $SpinContainer/ComboContainer
@onready var combo_label: Label = $SpinContainer/ComboContainer/VBoxContainer/ComboLabel
@onready var combo_bar: ProgressBar = $SpinContainer/ComboContainer/VBoxContainer/ComboBar

# Effects
@onready var spin_container: Control = $SpinContainer
@onready var star_particles: GPUParticles2D = $StarParticles if has_node("StarParticles") else null

var current_score: int = 0
var current_distance: float = 0.0
var current_combo: int = 0
var streak_active: bool = false
var current_zone: String = ""
var current_danger: float = 0.0
var score_multiplier: float = 1.0

# Dynamic UI elements (created at runtime)
var danger_vignette: ColorRect = null
var screen_shake_offset: Vector2 = Vector2.ZERO
var shake_intensity: float = 0.0

# Power-up indicators
var power_up_container: HBoxContainer = null
var active_power_up_indicators: Dictionary = {}  # PowerUp.Type -> indicator node

# Pulse animation for streak icon
var streak_pulse_tween: Tween

func _ready() -> void:
	create_danger_vignette()
	create_power_up_container()
	update_display()
	if streak_icon:
		start_streak_pulse()

func _exit_tree() -> void:
	if streak_pulse_tween:
		streak_pulse_tween.kill()

func _process(delta: float) -> void:
	# Update screen shake
	if shake_intensity > 0:
		shake_intensity = max(0, shake_intensity - delta * 10)
		screen_shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		if spin_container:
			spin_container.position = screen_shake_offset
	elif spin_container and spin_container.position != Vector2.ZERO:
		spin_container.position = Vector2.ZERO
	
	# Update danger vignette
	update_danger_vignette()

func create_power_up_container() -> void:
	power_up_container = HBoxContainer.new()
	power_up_container.position = Vector2(10, 62)
	power_up_container.add_theme_constant_override("separation", 8)
	add_child(power_up_container)

func create_danger_vignette() -> void:
	danger_vignette = ColorRect.new()
	danger_vignette.anchors_preset = Control.PRESET_FULL_RECT
	danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_vignette.color = Color(1, 0, 0, 0)
	danger_vignette.z_index = -1
	add_child(danger_vignette)

func update_danger_vignette() -> void:
	if danger_vignette and current_danger > 0:
		# Pulsing red edge effect when in danger
		var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1) * 0.5
		var alpha = current_danger * 0.3 * (0.5 + pulse * 0.5)
		danger_vignette.color = Color(1, 0.1, 0.1, alpha)
	elif danger_vignette:
		danger_vignette.color.a = 0

func start_streak_pulse() -> void:
	if streak_pulse_tween:
		streak_pulse_tween.kill()
	if not is_instance_valid(streak_icon):
		return
	streak_pulse_tween = get_tree().create_tween().set_loops()
	streak_pulse_tween.tween_property(streak_icon, "scale", Vector2(1.2, 1.2), 0.3).set_ease(Tween.EASE_IN_OUT)
	streak_pulse_tween.tween_property(streak_icon, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_IN_OUT)

func update_display() -> void:
	if score_label:
		score_label.text = format_number(current_score)
	if distance_label:
		distance_label.text = format_distance(current_distance)
	update_combo_display()

func format_distance(dist: float) -> String:
	if dist >= 1000:
		return "%.1fkm" % (dist / 1000.0)
	return "%dm" % int(dist)

func format_number(num: int) -> String:
	var str_num = str(num)
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	return result

func update_combo_display() -> void:
	if combo_container:
		combo_container.visible = current_combo >= 2
	if combo_label and current_combo >= 2:
		combo_label.text = "x%d COMBO" % current_combo
		
		var combo_color: Color
		if current_combo >= 10:
			combo_color = Color(1, 0.3, 0.8)
		elif current_combo >= 5:
			combo_color = Color(1, 0.5, 0.1)
		else:
			combo_color = Color(1, 0.9, 0.3)
		
		combo_label.add_theme_color_override("font_color", combo_color)

# ========== PUBLIC SETTERS ==========

func set_combo(floors_skipped: int) -> void:
	current_combo = floors_skipped
	update_combo_display()
	
	if floors_skipped >= 2 and combo_container:
		var tween = get_tree().create_tween()
		combo_container.scale = Vector2(0.5, 0.5)
		tween.tween_property(combo_container, "scale", Vector2(1.1, 1.1), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(combo_container, "scale", Vector2(1.0, 1.0), 0.1)

func set_streak_active(active: bool) -> void:
	streak_active = active
	if streak_indicator:
		streak_indicator.visible = active
		if active:
			var tween = get_tree().create_tween()
			streak_indicator.scale = Vector2.ZERO
			streak_indicator.modulate.a = 0.0
			tween.set_parallel(true)
			tween.tween_property(streak_indicator, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
			tween.tween_property(streak_indicator, "modulate:a", 1.0, 0.2)

func set_score(score: int) -> void:
	var old_score = current_score
	current_score = score
	
	if score_label:
		score_label.text = format_number(score)
		
		if score > old_score:
			var tween = get_tree().create_tween()
			score_label.pivot_offset = score_label.size / 2
			tween.tween_property(score_label, "scale", Vector2(1.15, 1.15), 0.08)
			tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.12)
			
			if score - old_score >= 50:
				var color_tween = get_tree().create_tween()
				score_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
				color_tween.tween_property(score_label, "theme_override_colors/font_color", Color(1, 1, 1), 0.3)

func set_distance(distance: float) -> void:
	var old_distance = current_distance
	current_distance = distance
	
	if distance_label:
		distance_label.text = format_distance(distance)
		
		# Celebrate every 100m milestone
		var old_hundred = int(old_distance / 100)
		var new_hundred = int(distance / 100)
		if new_hundred > old_hundred and new_hundred > 0:
			var tween = get_tree().create_tween()
			distance_label.pivot_offset = distance_label.size / 2
			tween.tween_property(distance_label, "scale", Vector2(1.3, 1.3), 0.1)
			tween.tween_property(distance_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC)
			
			var color_tween = get_tree().create_tween()
			distance_label.add_theme_color_override("font_color", Color(0.2, 1, 0.8))
			color_tween.tween_property(distance_label, "theme_override_colors/font_color", Color(0.4, 1, 0.9), 0.4)

func set_zone(zone_name: String) -> void:
	if zone_name == current_zone:
		return
	
	var old_zone = current_zone
	current_zone = zone_name
	
	# Show zone announcement if entering a new zone (not first zone)
	if old_zone != "" and zone_name != old_zone:
		show_zone_announcement(zone_name)

func set_danger_level(level: float) -> void:
	current_danger = clamp(level, 0.0, 1.0)

func set_score_multiplier(multiplier: float) -> void:
	score_multiplier = multiplier
	# Could add visual feedback when 2x is active

# ========== POWER-UP INDICATORS ==========

func show_power_up_activated(type: int, duration: float) -> void:
	# Show pickup text for all power-ups
	show_power_up_text(type)
	
	# Only create persistent indicator for timed power-ups (duration > 0)
	if duration <= 0:
		return
	
	# Create indicator for this power-up
	var indicator = create_power_up_indicator(type, duration)
	
	if type in active_power_up_indicators:
		# Update existing indicator - remove old one
		var old_indicator = active_power_up_indicators[type]
		if is_instance_valid(old_indicator):
			old_indicator.queue_free()
	
	active_power_up_indicators[type] = indicator
	power_up_container.add_child(indicator)
	
	# Animate entry
	indicator.scale = Vector2.ZERO
	var tween = get_tree().create_tween()
	tween.tween_property(indicator, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
	tween.tween_property(indicator, "scale", Vector2(1.0, 1.0), 0.1)

func create_power_up_indicator(type: int, duration: float) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(50, 50)
	container.pivot_offset = Vector2(25, 25)
	
	# Background
	var bg = ColorRect.new()
	bg.size = Vector2(46, 46)
	bg.position = Vector2(2, 2)
	bg.color = Color(0, 0, 0, 0.6)
	container.add_child(bg)
	
	# Get config
	var config = get_power_up_config(type)
	
	# Colored border
	var border = ColorRect.new()
	border.size = Vector2(50, 50)
	border.position = Vector2.ZERO
	border.color = config["color"]
	border.z_index = -1
	container.add_child(border)
	
	# Icon
	var icon = Label.new()
	icon.text = config["icon"]
	icon.add_theme_font_size_override("font_size", 28)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.size = Vector2(50, 40)
	icon.position = Vector2(0, 0)
	container.add_child(icon)
	
	# Duration bar (if has duration)
	if duration > 0:
		var bar_bg = ColorRect.new()
		bar_bg.size = Vector2(44, 6)
		bar_bg.position = Vector2(3, 42)
		bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
		container.add_child(bar_bg)
		
		var bar_fill = ColorRect.new()
		bar_fill.name = "BarFill"
		bar_fill.size = Vector2(44, 6)
		bar_fill.position = Vector2(3, 42)
		bar_fill.color = config["color"]
		container.add_child(bar_fill)
		
		# Animate bar drain
		var bar_tween = get_tree().create_tween()
		bar_tween.tween_property(bar_fill, "size:x", 0.0, duration)
		var hud_ref = self
		bar_tween.tween_callback(func(): 
			if is_instance_valid(hud_ref):
				hud_ref.remove_power_up_indicator(type)
		)
	
	return container

func get_power_up_config(type: int) -> Dictionary:
	match type:
		0:  # SHIELD
			return {"icon": "🛡️", "color": Color(0.3, 0.7, 1.0), "name": "SHIELD"}
		1:  # TIME_STOP
			return {"icon": "⏱️", "color": Color(1.0, 0.9, 0.3), "name": "TIME STOP"}
		2:  # SCORE_2X
			return {"icon": "✨", "color": Color(1.0, 0.5, 0.8), "name": "2X SCORE"}
		3:  # MEGA_JUMP
			return {"icon": "🚀", "color": Color(0.4, 1.0, 0.4), "name": "MEGA JUMP"}
		4:  # COIN
			return {"icon": "💎", "color": Color(0.2, 0.9, 1.0), "name": "BONUS"}
		_:
			return {"icon": "?", "color": Color(1, 1, 1), "name": "UNKNOWN"}

func remove_power_up_indicator(type: int) -> void:
	if type in active_power_up_indicators:
		var indicator = active_power_up_indicators[type]
		if is_instance_valid(indicator):
			var tween = get_tree().create_tween()
			tween.tween_property(indicator, "scale", Vector2.ZERO, 0.2)
			tween.tween_property(indicator, "modulate:a", 0.0, 0.1)
			tween.tween_callback(indicator.queue_free)
		active_power_up_indicators.erase(type)

func show_power_up_text(type: int) -> void:
	var config = get_power_up_config(type)
	var viewport_size = get_viewport().get_visible_rect().size
	
	var label = Label.new()
	label.text = config["name"] + "!"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", config["color"])
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(viewport_size.x, 50)
	label.position = Vector2(0, viewport_size.y / 2 - 100)
	label.pivot_offset = Vector2(viewport_size.x / 2, 25)
	add_child(label)
	
	# Animate
	label.scale = Vector2(0.5, 0.5)
	label.modulate.a = 0.0
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 1.0, 0.1)
	
	tween.chain().tween_interval(0.6)
	
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.3)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	
	tween.chain().tween_callback(label.queue_free)

func show_shield_used() -> void:
	remove_power_up_indicator(0)  # SHIELD type
	
	# Show "SHIELD USED!" text
	var viewport_size = get_viewport().get_visible_rect().size
	
	var label = Label.new()
	label.text = "SHIELD SAVED YOU!"
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(viewport_size.x, 50)
	label.position = Vector2(0, viewport_size.y / 2)
	label.pivot_offset = Vector2(viewport_size.x / 2, 25)
	add_child(label)
	
	# Flash screen blue
	trigger_screen_flash(Color(0.3, 0.7, 1.0, 0.4))
	trigger_screen_shake(8.0)
	
	var tween = get_tree().create_tween()
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.2).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_interval(0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)

func clear_power_up_indicators() -> void:
	for type in active_power_up_indicators.keys():
		var indicator = active_power_up_indicators[type]
		if is_instance_valid(indicator):
			indicator.queue_free()
	active_power_up_indicators.clear()

func add_combo(floors_jumped: int) -> int:
	if floors_jumped > 1:
		current_combo += 1
		update_combo_display()
		return current_combo
	else:
		reset_combo()
		return 1

func reset_combo() -> void:
	current_combo = 0
	update_combo_display()

# ========== SCREEN EFFECTS ==========

func trigger_screen_shake(intensity: float = 5.0) -> void:
	shake_intensity = max(shake_intensity, intensity)

func trigger_screen_flash(color: Color = Color(1, 1, 1, 0.3)) -> void:
	var flash = ColorRect.new()
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = color
	flash.z_index = 100
	add_child(flash)
	
	var tween = get_tree().create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

# ========== ZONE ANNOUNCEMENT ==========

func show_zone_announcement(zone_name: String) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Zone-specific colors and subtitles
	var zone_color: Color
	var zone_color_dark: Color
	var subtitle_text: String
	var icon_text: String
	
	match zone_name:
		"LEARNING":
			zone_color = Color(0.3, 0.9, 0.4)
			zone_color_dark = Color(0.1, 0.4, 0.15)
			subtitle_text = "Master the basics!"
			icon_text = "📚"
		"MOVING ZONE":
			zone_color = Color(0.2, 0.85, 1.0)
			zone_color_dark = Color(0.05, 0.3, 0.5)
			subtitle_text = "Platforms are sliding!"
			icon_text = "↔️"
		"CRUMBLING ZONE":
			zone_color = Color(1.0, 0.4, 0.2)
			zone_color_dark = Color(0.4, 0.1, 0.05)
			subtitle_text = "Don't stop moving!"
			icon_text = "💥"
		"ICE ZONE":
			zone_color = Color(0.7, 0.95, 1.0)
			zone_color_dark = Color(0.2, 0.4, 0.5)
			subtitle_text = "Watch your footing!"
			icon_text = "❄️"
		"SPRING ZONE":
			zone_color = Color(0.4, 1.0, 0.4)
			zone_color_dark = Color(0.1, 0.4, 0.1)
			subtitle_text = "Bounce to the sky!"
			icon_text = "🚀"
		"ENDGAME":
			zone_color = Color(1.0, 0.2, 0.4)
			zone_color_dark = Color(0.5, 0.05, 0.15)
			subtitle_text = "SURVIVE IF YOU CAN!"
			icon_text = "🔥"
		_:
			zone_color = Color(1, 1, 1)
			zone_color_dark = Color(0.3, 0.3, 0.3)
			subtitle_text = ""
			icon_text = ""
	
	# Create main container
	var container = Control.new()
	container.size = Vector2(viewport_size.x, 200)
	container.position = Vector2(0, viewport_size.y / 2 - 100)
	container.pivot_offset = Vector2(viewport_size.x / 2, 100)
	container.z_index = 50
	
	# Dark background with colored edges
	var bg = ColorRect.new()
	bg.size = Vector2(viewport_size.x, 130)
	bg.position = Vector2(0, 35)
	bg.color = Color(0, 0, 0, 0.85)
	container.add_child(bg)
	
	# Top accent line
	var top_line = ColorRect.new()
	top_line.size = Vector2(viewport_size.x, 4)
	top_line.position = Vector2(0, 35)
	top_line.color = zone_color
	container.add_child(top_line)
	
	# Bottom accent line
	var bottom_line = ColorRect.new()
	bottom_line.size = Vector2(viewport_size.x, 4)
	bottom_line.position = Vector2(0, 161)
	bottom_line.color = zone_color
	container.add_child(bottom_line)
	
	# Glow overlay
	var glow = ColorRect.new()
	glow.size = Vector2(viewport_size.x, 130)
	glow.position = Vector2(0, 35)
	glow.color = Color(zone_color.r, zone_color.g, zone_color.b, 0.1)
	glow.name = "Glow"
	container.add_child(glow)
	
	# Icon
	var icon = Label.new()
	icon.text = icon_text
	icon.add_theme_font_size_override("font_size", 42)
	icon.position = Vector2(viewport_size.x / 2 - 150, 55)
	icon.size = Vector2(60, 60)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(icon)
	
	# Zone name with glow
	var title_glow = Label.new()
	title_glow.text = zone_name
	title_glow.add_theme_font_size_override("font_size", 52)
	title_glow.add_theme_color_override("font_color", Color(zone_color.r, zone_color.g, zone_color.b, 0.4))
	title_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_glow.position = Vector2(0, 50)
	title_glow.size = Vector2(viewport_size.x, 70)
	container.add_child(title_glow)
	
	# Zone name main
	var title = Label.new()
	title.text = zone_name
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", zone_color)
	title.add_theme_color_override("font_outline_color", zone_color_dark)
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 50)
	title.size = Vector2(viewport_size.x, 70)
	container.add_child(title)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = subtitle_text
	subtitle.name = "Subtitle"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	subtitle.add_theme_constant_override("outline_size", 3)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 120)
	subtitle.size = Vector2(viewport_size.x, 40)
	container.add_child(subtitle)
	
	# Icon on right side
	var icon2 = Label.new()
	icon2.text = icon_text
	icon2.add_theme_font_size_override("font_size", 42)
	icon2.position = Vector2(viewport_size.x / 2 + 90, 55)
	icon2.size = Vector2(60, 60)
	icon2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(icon2)
	
	add_child(container)
	
	# ===== ANIMATION WITH EXTENDED FLICKER =====
	container.scale = Vector2(1.5, 0)
	container.modulate.a = 0
	
	var tween = get_tree().create_tween()
	
	# Slam in
	tween.set_parallel(true)
	tween.tween_property(container, "scale", Vector2(1, 1), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(container, "modulate:a", 1.0, 0.1)
	
	# Screen effects on entry
	tween.chain().tween_callback(func(): trigger_screen_shake(6.0))
	tween.tween_callback(func(): trigger_screen_flash(Color(zone_color.r, zone_color.g, zone_color.b, 0.5)))
	
	# Hold visible for user to read
	tween.tween_interval(0.6)
	
	# ===== FLICKER SEQUENCE (6 flickers spread out) =====
	
	# Flicker 1 - Strong
	tween.tween_property(container, "modulate:a", 0.0, 0.04)
	tween.tween_property(container, "modulate:a", 1.0, 0.04)
	tween.tween_callback(func(): trigger_screen_flash(Color(zone_color.r, zone_color.g, zone_color.b, 0.3)))
	
	tween.tween_interval(0.5)
	
	# Flicker 2
	tween.tween_property(container, "modulate:a", 0.0, 0.04)
	tween.tween_property(container, "modulate:a", 1.0, 0.04)
	tween.tween_callback(func(): trigger_screen_flash(Color(zone_color.r, zone_color.g, zone_color.b, 0.25)))
	
	tween.tween_interval(0.5)
	
	# Flicker 3 - Double flash
	tween.tween_property(container, "modulate:a", 0.0, 0.03)
	tween.tween_property(container, "modulate:a", 1.0, 0.03)
	tween.tween_property(container, "modulate:a", 0.0, 0.03)
	tween.tween_property(container, "modulate:a", 1.0, 0.03)
	tween.tween_callback(func(): trigger_screen_flash(Color(zone_color.r, zone_color.g, zone_color.b, 0.2)))
	
	tween.tween_interval(0.5)
	
	# Flicker 4
	tween.tween_property(container, "modulate:a", 0.0, 0.04)
	tween.tween_property(container, "modulate:a", 1.0, 0.04)
	tween.tween_callback(func(): trigger_screen_flash(Color(zone_color.r, zone_color.g, zone_color.b, 0.15)))
	
	tween.tween_interval(0.5)
	
	# Flicker 5 - Triple flash
	tween.tween_property(container, "modulate:a", 0.0, 0.03)
	tween.tween_property(container, "modulate:a", 1.0, 0.03)
	tween.tween_property(container, "modulate:a", 0.0, 0.03)
	tween.tween_property(container, "modulate:a", 1.0, 0.03)
	tween.tween_property(container, "modulate:a", 0.0, 0.03)
	tween.tween_property(container, "modulate:a", 1.0, 0.03)
	tween.tween_callback(func(): trigger_screen_flash(Color(zone_color.r, zone_color.g, zone_color.b, 0.2)))
	
	tween.tween_interval(0.5)
	
	# Flicker 6 - Final
	tween.tween_property(container, "modulate:a", 0.0, 0.04)
	tween.tween_property(container, "modulate:a", 1.0, 0.04)
	tween.tween_callback(func(): trigger_screen_flash(Color(zone_color.r, zone_color.g, zone_color.b, 0.1)))
	
	# Glow pulse effect (more loops for longer duration)
	var glow_tween = get_tree().create_tween().set_loops(8)
	glow_tween.tween_property(glow, "color:a", 0.3, 0.25)
	glow_tween.tween_property(glow, "color:a", 0.08, 0.25)
	
	# Final hold before exit
	tween.tween_interval(0.8)
	
	# Slide out
	tween.set_parallel(true)
	tween.tween_property(container, "scale", Vector2(0.8, 0), 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(container, "modulate:a", 0.0, 0.2)
	
	tween.chain().tween_callback(container.queue_free)

# ========== COMBO EFFECTS ==========

func trigger_combo_celebration(player_screen_pos: Vector2) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Use provided position, or default to center of screen
	var effect_pos = player_screen_pos
	if effect_pos.x <= 0 or effect_pos.x >= viewport_size.x or effect_pos.y <= 0 or effect_pos.y >= viewport_size.y:
		effect_pos = Vector2(viewport_size.x / 2, viewport_size.y / 2)
	
	# Clean celebration - top bar flash + sparkles
	flash_top_bar()
	spawn_sparkle_burst(effect_pos)

func flash_top_bar() -> void:
	var top_bar = $SpinContainer/TopBar
	if top_bar:
		var tween = get_tree().create_tween()
		top_bar.modulate = Color(1.5, 1.3, 2.0)
		tween.tween_property(top_bar, "modulate", Color(1, 1, 1), 0.3)

func spawn_confetti_at(pos: Vector2) -> void:
	# Lighter sparkle burst effect - less intrusive than confetti
	spawn_sparkle_burst(pos)

func spawn_sparkle_burst(pos: Vector2) -> void:
	# Balanced sparkle effect - visible but not overwhelming
	var sparkle_chars = ["✦", "✧", "★"]
	var colors = [
		Color(1, 0.9, 0.3),   # Bright gold
		Color(1, 1, 0.5),     # Light yellow
		Color(1, 0.8, 0.2),   # Orange gold
	]
	
	# 10 sparkles in a ring pattern
	var num_sparkles = 10
	
	for i in range(num_sparkles):
		var sparkle = Label.new()
		sparkle.text = sparkle_chars[i % sparkle_chars.size()]
		sparkle.add_theme_font_size_override("font_size", 16)
		sparkle.add_theme_color_override("font_color", colors[i % colors.size()])
		sparkle.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0, 0.5))
		sparkle.add_theme_constant_override("outline_size", 2)
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sparkle.size = Vector2(20, 20)
		sparkle.position = pos - Vector2(10, 10)
		sparkle.pivot_offset = Vector2(10, 10)
		sparkle.z_index = 100
		
		add_child(sparkle)
		
		# Spread evenly in a circle
		var angle = (TAU / num_sparkles) * i - PI / 2  # Start from top
		var distance = 40
		var end_pos = pos + Vector2(cos(angle), sin(angle)) * distance - Vector2(10, 10)
		
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		# Scale up from small
		sparkle.scale = Vector2(0.3, 0.3)
		tween.tween_property(sparkle, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
		# Move outward
		tween.tween_property(sparkle, "position", end_pos, 0.3).set_ease(Tween.EASE_OUT)
		# Fade out after brief visible moment
		tween.tween_property(sparkle, "modulate:a", 0.0, 0.2).set_delay(0.15)
		
		tween.chain().tween_callback(sparkle.queue_free)

func spawn_floating_bonus_at(pos: Vector2) -> void:
	# Simplified - just 1-2 floating bonus indicators
	var bonus_texts = ["✦", "★"]
	var colors = [Color(1, 0.85, 0.3), Color(1, 1, 0.6)]
	
	for i in range(2):
		var bonus_label = Label.new()
		bonus_label.text = bonus_texts[i % bonus_texts.size()]
		bonus_label.add_theme_font_size_override("font_size", 18)
		bonus_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		bonus_label.add_theme_constant_override("outline_size", 2)
		bonus_label.add_theme_color_override("font_color", colors[i % colors.size()])
		
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		bonus_label.position = pos + offset
		bonus_label.scale = Vector2.ZERO
		
		add_child(bonus_label)
		
		var angle = randf_range(-PI * 0.8, -PI * 0.2)
		var distance = randf_range(50, 120)
		var end_pos = bonus_label.position + Vector2(cos(angle), sin(angle)) * distance
		
		var tween = get_tree().create_tween()
		tween.tween_property(bonus_label, "scale", Vector2(1.1, 1.1), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		tween.set_parallel(true)
		tween.tween_property(bonus_label, "position", end_pos, 0.6)
		tween.tween_property(bonus_label, "modulate:a", 0.0, 0.4).set_delay(0.2)
		tween.tween_property(bonus_label, "scale", Vector2(0.5, 0.5), 0.4).set_delay(0.2)
		
		tween.chain().tween_callback(bonus_label.queue_free)

func show_combo_word(word: String = "") -> void:
	if word.is_empty():
		var random_words = ["NICE!", "GREAT!", "SUPER!", "AWESOME!"]
		word = random_words[randi() % random_words.size()]
	
	var viewport_size = get_viewport().get_visible_rect().size
	var container = Control.new()
	container.size = Vector2(viewport_size.x, 100)
	container.position = Vector2(0, 140)
	container.pivot_offset = Vector2(viewport_size.x / 2, 50)
	
	var glow_label = Label.new()
	glow_label.text = word
	glow_label.add_theme_font_size_override("font_size", 56)
	glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glow_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var word_label = Label.new()
	word_label.text = word
	word_label.add_theme_font_size_override("font_size", 56)
	word_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	word_label.add_theme_constant_override("outline_size", 5)
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var color_pairs = [
		[Color(1, 0.2, 0.6), Color(1, 0.5, 0.8, 0.5)],
		[Color(0.2, 1, 0.6), Color(0.5, 1, 0.8, 0.5)],
		[Color(0.3, 0.8, 1), Color(0.6, 0.9, 1, 0.5)],
		[Color(1, 0.85, 0.1), Color(1, 0.95, 0.5, 0.5)],
		[Color(1, 0.4, 0.1), Color(1, 0.7, 0.4, 0.5)],
		[Color(0.9, 0.3, 1), Color(0.95, 0.6, 1, 0.5)],
		[Color(0, 1, 1), Color(0.5, 1, 1, 0.5)],
	]
	var color_pair = color_pairs[randi() % color_pairs.size()]
	word_label.add_theme_color_override("font_color", color_pair[0])
	glow_label.add_theme_color_override("font_color", color_pair[1])
	glow_label.modulate = Color(1, 1, 1, 0.6)
	
	container.add_child(glow_label)
	container.add_child(word_label)
	add_child(container)
	
	container.scale = Vector2.ZERO
	container.modulate.a = 1.0
	
	var tween = get_tree().create_tween()
	tween.tween_property(container, "scale", Vector2(1.15, 1.15), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	var glow_tween = get_tree().create_tween()
	glow_tween.set_loops(2)
	glow_tween.tween_property(glow_label, "modulate:a", 0.9, 0.12)
	glow_tween.tween_property(glow_label, "modulate:a", 0.4, 0.12)
	
	tween.tween_interval(0.6)
	
	tween.set_parallel(true)
	tween.tween_property(container, "position:y", container.position.y - 50, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(container, "scale", Vector2(0.85, 0.85), 0.5)
	tween.tween_property(container, "modulate:a", 0.0, 0.5)
	
	tween.chain().tween_callback(container.queue_free)

func show_combo_popup(text: String, position: Vector2) -> void:
	var popup = Label.new()
	popup.text = text
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	popup.add_theme_constant_override("outline_size", 3)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.global_position = position
	add_child(popup)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 60, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5).set_delay(0.1)
	tween.chain().tween_callback(popup.queue_free)

func reset() -> void:
	current_score = 0
	current_distance = 0.0
	current_combo = 0
	current_zone = ""
	current_danger = 0.0
	streak_active = false
	shake_intensity = 0.0
	score_multiplier = 1.0
	update_display()
	if combo_container:
		combo_container.visible = false
	if streak_indicator:
		streak_indicator.visible = false
	clear_power_up_indicators()
