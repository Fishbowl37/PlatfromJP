extends CanvasLayer
class_name GameOverScreen

signal restart_requested
signal menu_requested

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var score_label: Label = $Panel/MarginContainer/VBoxContainer/ScoreLabel
@onready var best_label: Label = $Panel/MarginContainer/VBoxContainer/BestLabel
@onready var distance_label: Label = $Panel/MarginContainer/VBoxContainer/DistanceLabel
@onready var restart_button: Button = $Panel/MarginContainer/VBoxContainer/RestartButton
@onready var menu_button: Button = $Panel/MarginContainer/VBoxContainer/MenuButton
@onready var dimmer: ColorRect = $Dimmer

var final_score: int = 0
var final_distance: float = 0.0
var is_new_best: bool = false

# Dynamic UI elements
var rank_label: Label = null
var leaderboard_manager: Node = null

func _ready() -> void:
	visible = false
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	
	# Connect to leaderboard manager
	await get_tree().process_frame
	if has_node("/root/LeaderboardManager"):
		leaderboard_manager = get_node("/root/LeaderboardManager")
		leaderboard_manager.score_submitted.connect(_on_score_submitted)

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

func format_distance(dist: float) -> String:
	if dist >= 1000:
		return "%.1fkm" % (dist / 1000.0)
	return "%dm" % int(dist)

func show_game_over(score: int, distance_reached: float, best_score: int, distance_label_text: String = "HEIGHT") -> void:
	final_score = score
	final_distance = distance_reached
	is_new_best = score > best_score
	
	# Update labels
	if score_label:
		score_label.text = format_number(score)
	if distance_label:
		distance_label.text = "📏 %s: %s" % [distance_label_text, format_distance(distance_reached)]
	if best_label:
		if is_new_best:
			best_label.text = "★ NEW BEST! ★"
			best_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		else:
			best_label.text = "★ BEST: %s ★" % format_number(best_score)
			best_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	
	# Create rank label if it doesn't exist
	_setup_rank_label()
	
	# Show with animation
	visible = true
	
	# Fade in dimmer
	if dimmer:
		dimmer.modulate.a = 0
		var dim_tween = create_tween()
		dim_tween.tween_property(dimmer, "modulate:a", 1.0, 0.3)
	
	# Animate panel entrance
	if panel:
		panel.modulate.a = 0
		panel.scale = Vector2(0.7, 0.7)
		panel.pivot_offset = panel.size / 2
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_parallel(true)
		tween.tween_property(panel, "modulate:a", 1.0, 0.4)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.5)
	
	# Animate title shake if new best
	if is_new_best and title_label:
		title_label.text = "NEW RECORD!"
		title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		
		# Celebration shake
		var shake_tween = create_tween()
		shake_tween.set_loops(3)
		shake_tween.tween_property(title_label, "rotation", 0.05, 0.1)
		shake_tween.tween_property(title_label, "rotation", -0.05, 0.1)
		shake_tween.tween_property(title_label, "rotation", 0.0, 0.1)

func _setup_rank_label() -> void:
	# Find or create rank label after best_label
	var vbox = panel.get_node_or_null("MarginContainer/VBoxContainer")
	if not vbox:
		return
	
	# Remove existing rank label if any
	if rank_label and is_instance_valid(rank_label):
		rank_label.queue_free()
		rank_label = null
	
	# Create new rank label
	rank_label = Label.new()
	rank_label.name = "RankLabel"
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 16)
	rank_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	rank_label.text = "🏆 Submitting score..."
	
	# Find the best_label index and insert after it
	var best_label_idx = best_label.get_index() if best_label else -1
	if best_label_idx >= 0:
		vbox.add_child(rank_label)
		vbox.move_child(rank_label, best_label_idx + 1)
	else:
		vbox.add_child(rank_label)

func _on_score_submitted(success: bool, rank: int) -> void:
	if not rank_label or not is_instance_valid(rank_label):
		return
	
	if success and rank > 0:
		if rank <= 3:
			var medal = "🥇" if rank == 1 else ("🥈" if rank == 2 else "🥉")
			rank_label.text = "%s RANK #%d" % [medal, rank]
			rank_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		elif rank <= 10:
			rank_label.text = "🏆 RANK #%d - TOP 10!" % rank
			rank_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		else:
			rank_label.text = "🏆 RANK #%d" % rank
			rank_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	elif success:
		rank_label.text = "🏆 Score saved!"
		rank_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.6))
	else:
		rank_label.text = ""  # Hide on failure

func hide_game_over() -> void:
	if panel:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(panel, "modulate:a", 0.0, 0.2)
		tween.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.2)
		if dimmer:
			tween.tween_property(dimmer, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(func(): visible = false)
	else:
		visible = false

func _on_restart_pressed() -> void:
	hide_game_over()
	restart_requested.emit()

func _on_menu_pressed() -> void:
	hide_game_over()
	menu_requested.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Quick restart on any tap (except buttons)
	if event is InputEventScreenTouch and event.pressed:
		# Small delay to allow button presses
		await get_tree().create_timer(0.1).timeout
		if visible and not (restart_button and restart_button.is_hovered()):
			_on_restart_pressed()
