extends Node

# Signals
signal score_changed(new_score: int)
signal floor_changed(floor_number: int)
signal game_started
signal game_over(final_score: int, final_floor: int)
signal danger_level_changed(level: float)

# Game State
var is_game_active: bool = false
var is_paused: bool = false

# Score System
var current_score: int = 0
var best_score: int = 0
var current_floor: int = 0
var highest_floor: int = 0

# Danger indicator
var danger_level: float = 0.0

# Save data
const SAVE_PATH = "user://icy_tower_save.cfg"

func _ready() -> void:
	load_game_data()

func start_game() -> void:
	is_game_active = true
	is_paused = false
	current_score = 0
	current_floor = 0
	danger_level = 0.0
	
	score_changed.emit(current_score)
	floor_changed.emit(current_floor)
	game_started.emit()

func end_game() -> void:
	is_game_active = false
	
	# Update best score
	if current_score > best_score:
		best_score = current_score
		save_game_data()
	
	# Update highest floor
	if current_floor > highest_floor:
		highest_floor = current_floor
		save_game_data()
	
	game_over.emit(current_score, current_floor)

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false

# Floor landing - just track floor progress
func on_floor_landed(_floor_y: float, floor_number: int) -> void:
	if not is_game_active:
		return
	
	# Update floor count
	if floor_number > current_floor:
		current_floor = floor_number
		floor_changed.emit(current_floor)

# Add score (called from Main.gd via ComboSystem)
func add_score(points: int) -> void:
	current_score += points
	score_changed.emit(current_score)

func set_danger_level(level: float) -> void:
	danger_level = clamp(level, 0.0, 1.0)
	danger_level_changed.emit(danger_level)

func get_danger_level() -> float:
	return danger_level

# Persistence
func save_game_data() -> void:
	var config = ConfigFile.new()
	config.set_value("game", "best_score", best_score)
	config.set_value("game", "highest_floor", highest_floor)
	config.set_value("settings", "joystick_sensitivity", joystick_sensitivity)
	config.save(SAVE_PATH)

func load_game_data() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		best_score = config.get_value("game", "best_score", 0)
		highest_floor = config.get_value("game", "highest_floor", 0)
		joystick_sensitivity = config.get_value("settings", "joystick_sensitivity", 0.4)

func get_best_score() -> int:
	return best_score

func get_highest_floor() -> int:
	return highest_floor

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