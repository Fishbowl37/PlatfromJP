extends Node

# Signals
signal score_changed(new_score: int)
signal distance_changed(distance: float)
signal game_started
signal game_over(final_score: int, final_distance: float)
signal danger_level_changed(level: float)

# Game State
var is_game_active: bool = false
var is_paused: bool = false

# Score System
var current_score: int = 0
var best_score: int = 0
var current_distance: float = 0.0
var best_distance: float = 0.0

# Danger indicator
var danger_level: float = 0.0

# Current game mode ("tower" or "freefall")
var current_game_mode: String = "tower"

# Skin Manager
var skin_manager: Node = null

# Save data
const SAVE_PATH = "user://icy_tower_save.cfg"

func _ready() -> void:
	_setup_skin_manager()
	load_game_data()

func _setup_skin_manager() -> void:
	var SkinManagerScript = load("res://scripts/SkinManager.gd")
	if SkinManagerScript:
		skin_manager = SkinManagerScript.new()
		add_child(skin_manager)

func start_game() -> void:
	is_game_active = true
	is_paused = false
	current_score = 0
	current_distance = 0.0
	danger_level = 0.0
	
	score_changed.emit(current_score)
	distance_changed.emit(current_distance)
	game_started.emit()

func end_game() -> void:
	is_game_active = false
	
	var is_new_best = false
	
	# Update best score
	if current_score > best_score:
		best_score = current_score
		is_new_best = true
		save_game_data()
	
	# Update best distance
	if current_distance > best_distance:
		best_distance = current_distance
		save_game_data()
	
	# Submit score to leaderboard
	_submit_to_leaderboard()
	
	# Trigger ads manager game over logic
	if has_node("/root/AdsManager"):
		get_node("/root/AdsManager").on_game_over()
	
	game_over.emit(current_score, current_distance)

func _submit_to_leaderboard() -> void:
	if not has_node("/root/LeaderboardManager"):
		return
	
	var leaderboard = get_node("/root/LeaderboardManager")
	var skin_id = "default"
	if skin_manager:
		skin_id = skin_manager.get_equipped_skin()
	
	leaderboard.submit_score(current_score, current_distance, skin_id, current_game_mode)

## Set the current game mode for leaderboard submission
func set_game_mode(mode: String) -> void:
	current_game_mode = mode

## Get the current game mode
func get_game_mode() -> String:
	return current_game_mode

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false

# Update distance from starting point (called every frame from Main.gd)
func update_distance(distance: float) -> void:
	if not is_game_active:
		return
	
	# Update distance if player went higher
	if distance > current_distance:
		current_distance = distance
		distance_changed.emit(current_distance)

# Add score (called from Main.gd via ComboSystem)
func add_score(points: int) -> void:
	# Apply score multiplier from RemoteConfig if available
	var multiplier = _get_score_multiplier()
	var adjusted_points = int(points * multiplier)
	current_score += adjusted_points
	score_changed.emit(current_score)

func _get_score_multiplier() -> float:
	if has_node("/root/RemoteConfig"):
		return get_node("/root/RemoteConfig").get_score_multiplier()
	return 1.0

func _get_coin_multiplier() -> float:
	if has_node("/root/RemoteConfig"):
		return get_node("/root/RemoteConfig").get_coin_multiplier()
	return 1.0

func set_danger_level(level: float) -> void:
	danger_level = clamp(level, 0.0, 1.0)
	danger_level_changed.emit(danger_level)

func get_danger_level() -> float:
	return danger_level

# Persistence
func save_game_data() -> void:
	var config = ConfigFile.new()
	config.set_value("game", "best_score", best_score)
	config.set_value("game", "best_distance", best_distance)
	config.set_value("settings", "joystick_sensitivity", joystick_sensitivity)
	
	# Save skin data
	if skin_manager:
		var skin_data = skin_manager.get_save_data()
		config.set_value("skins", "coins", skin_data.get("coins", 0))
		config.set_value("skins", "equipped_skin", skin_data.get("equipped_skin", "default"))
		config.set_value("skins", "unlocked_skins", skin_data.get("unlocked_skins", ["default"]))
	
	config.save(SAVE_PATH)

func load_game_data() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		best_score = config.get_value("game", "best_score", 0)
		best_distance = config.get_value("game", "best_distance", 0.0)
		joystick_sensitivity = config.get_value("settings", "joystick_sensitivity", 0.4)
		
		# Load skin data
		if skin_manager:
			var skin_data = {
				"coins": config.get_value("skins", "coins", 0),
				"equipped_skin": config.get_value("skins", "equipped_skin", "default"),
				"unlocked_skins": config.get_value("skins", "unlocked_skins", ["default", "knight", "karasu"])
			}
			skin_manager.load_save_data(skin_data)

func get_best_score() -> int:
	return best_score

func get_best_distance() -> float:
	return best_distance

# Sound System (placeholder)
var sounds_enabled: bool = true

func play_sound(_sound_name: String) -> void:
	if not sounds_enabled:
		return
	# Placeholder - sounds will be added later

func set_sounds_enabled(enabled: bool) -> void:
	sounds_enabled = enabled

# Joystick Sensitivity (0.0 = very low, 1.0 = very high)
# Default 0.4 is a comfortable middle ground
var joystick_sensitivity: float = 0.4

signal joystick_sensitivity_changed(new_value: float)

func set_joystick_sensitivity(value: float) -> void:
	joystick_sensitivity = clamp(value, 0.1, 1.0)
	joystick_sensitivity_changed.emit(joystick_sensitivity)
	save_game_data()

func get_joystick_sensitivity() -> float:
	return joystick_sensitivity