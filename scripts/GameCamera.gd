extends Camera2D
class_name GameCamera

signal player_fell_off_screen

@export var player: Player
@export var smooth_speed: float = 8.0
@export var look_ahead_distance: float = 100.0

@export_group("Auto Scroll - Progressive Speed")
@export var base_scroll_speed: float = 12.0        # Starting speed
@export var max_scroll_speed: float = 120.0        # Maximum speed at high floors
@export var speed_ramp_height: float = 50000.0     # Height to reach max speed
@export var scroll_start_delay: float = 2.5        # Delay before scrolling starts

@export_group("Difficulty Milestones")
@export var speed_milestone_1: float = 18.0   # Speed at floor ~300 (end of learning)
@export var speed_milestone_2: float = 30.0   # Speed at floor ~600 (moving zone)
@export var speed_milestone_3: float = 45.0   # Speed at floor ~900 (crumbling zone)
@export var speed_milestone_4: float = 60.0   # Speed at floor ~1200 (ice zone)
@export var speed_milestone_5: float = 80.0   # Speed at floor ~1500 (spring zone)

@export_group("Death Zone")
@export var death_offset: float = 450.0
@export var hurry_up_threshold: float = 200.0  # Distance before danger warning

var current_scroll_speed: float = 0.0
var highest_player_y: float = 0.0
var is_scrolling: bool = false
var scroll_timer: float = 0.0
var start_y: float = 0.0

# Time stop power-up (controlled by PowerUpManager)
var is_time_stopped: bool = false

# Visual feedback
var speed_display_label: Label = null

func _ready() -> void:
	if player:
		global_position.x = player.global_position.x
		highest_player_y = player.global_position.y
		global_position.y = player.global_position.y
		start_y = player.global_position.y

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	
	if not GameManager.is_game_active:
		return
	
	# Track highest point reached
	if player.global_position.y < highest_player_y:
		highest_player_y = player.global_position.y
	
	# Follow player upward smoothly
	follow_player(delta)
	
	# Auto-scroll after delay
	handle_auto_scroll(delta)
	
	# Check if player fell off screen
	check_player_death()

func follow_player(delta: float) -> void:
	# Only follow upward, with look-ahead
	var target_y = player.global_position.y - look_ahead_distance
	
	if target_y < global_position.y:
		global_position.y = lerp(global_position.y, target_y, smooth_speed * delta)

func handle_auto_scroll(delta: float) -> void:
	# Time stopped by power-up - don't scroll
	if is_time_stopped:
		return
	
	if not is_scrolling:
		scroll_timer += delta
		if scroll_timer >= scroll_start_delay:
			is_scrolling = true
		return
	
	# Calculate scroll speed based on height climbed
	current_scroll_speed = calculate_scroll_speed()
	
	# Apply scroll
	global_position.y -= current_scroll_speed * delta
	
	# Update danger warning
	update_hurry_warning()

func calculate_scroll_speed() -> float:
	var height_climbed = start_y - highest_player_y
	
	# Zone-based speed increases matching floor zones
	# Floor spacing ~120, so floor 300 ≈ 36000 height
	if height_climbed < 36000:  # Floor 1-300: Learning
		var t = height_climbed / 36000.0
		return lerp(base_scroll_speed, speed_milestone_1, t)
	elif height_climbed < 72000:  # Floor 300-600: Moving Zone
		var t = (height_climbed - 36000.0) / 36000.0
		return lerp(speed_milestone_1, speed_milestone_2, t)
	elif height_climbed < 108000:  # Floor 600-900: Crumbling Zone
		var t = (height_climbed - 72000.0) / 36000.0
		return lerp(speed_milestone_2, speed_milestone_3, t)
	elif height_climbed < 144000:  # Floor 900-1200: Ice Zone
		var t = (height_climbed - 108000.0) / 36000.0
		return lerp(speed_milestone_3, speed_milestone_4, t)
	elif height_climbed < 180000:  # Floor 1200-1500: Spring Zone
		var t = (height_climbed - 144000.0) / 36000.0
		return lerp(speed_milestone_4, speed_milestone_5, t)
	else:  # Floor 1500+: Endgame
		var t = (height_climbed - 180000.0) / 60000.0
		return lerp(speed_milestone_5, max_scroll_speed, min(t, 1.0))

func update_hurry_warning() -> void:
	if player == null:
		return
	
	var distance_from_bottom = player.global_position.y - (global_position.y + death_offset)
	var danger_level = 1.0 - (distance_from_bottom / hurry_up_threshold)
	danger_level = clamp(danger_level, 0.0, 1.0)
	
	GameManager.set_danger_level(danger_level)

func check_player_death() -> void:
	if player == null:
		return
	
	# Grace period - don't kill player in first 3 seconds
	if scroll_timer < 3.0 and not is_scrolling:
		return
	
	if player.global_position.y > global_position.y + death_offset:
		# Only emit signal - let Main.gd decide if shield saves or player dies
		player_fell_off_screen.emit()

func reset(start_position: Vector2) -> void:
	global_position = start_position
	highest_player_y = start_position.y
	start_y = start_position.y
	current_scroll_speed = 0.0
	is_scrolling = false
	scroll_timer = 0.0

func get_scroll_speed() -> float:
	return current_scroll_speed

func get_speed_percentage() -> float:
	return (current_scroll_speed / max_scroll_speed) * 100.0

func pause_scrolling() -> void:
	is_scrolling = false

func resume_scrolling() -> void:
	is_scrolling = true
	is_time_stopped = false

func pause_scrolling_temporary(_duration: float) -> void:
	# Duration is now managed by PowerUpManager
	is_time_stopped = true

func stop_time_stop() -> void:
	is_time_stopped = false

func is_scroll_paused() -> bool:
	return is_time_stopped or not is_scrolling
