extends Node
class_name ComboSystem

signal combo_triggered(floors_skipped: int)  # Fires when player skips 2+ floors
signal super_combo(floors_skipped: int)      # Fires for huge jumps (5+ floors)
signal combo_streak_started()                # Fires when player chains multiple combos
signal combo_streak_ended(streak_count: int)

@export var combo_window: float = 1.5  # Time window to chain combos for streak
@export var floor_spacing: float = 120.0

var last_landing_y: float = 0.0
var combo_streak: int = 0  # How many combo jumps in a row
var streak_timer: float = 0.0
var is_streak_active: bool = false

# Thresholds
const MIN_COMBO_FLOORS = 2    # Skip at least 2 floors for combo
const SUPER_COMBO_FLOORS = 5  # Skip 5+ for super combo
const MEGA_COMBO_FLOORS = 8   # Skip 8+ for mega combo
const ULTRA_COMBO_FLOORS = 12 # Skip 12+ for ultra combo

func _process(delta: float) -> void:
	if is_streak_active:
		streak_timer -= delta
		if streak_timer <= 0:
			# Streak ended - player took too long
			end_streak()

func initialize(start_y: float) -> void:
	last_landing_y = start_y
	reset()

func on_floor_landed(landing_y: float) -> int:
	# Calculate how many floors were skipped
	var height_diff = last_landing_y - landing_y
	var floors_skipped = int(height_diff / floor_spacing)
	
	# Update last landing position
	last_landing_y = landing_y
	
	# Player went down or stayed same - no combo, end streak
	if floors_skipped <= 0:
		if is_streak_active:
			end_streak()
		return 0
	
	# Calculate base score
	var jump_score = calculate_jump_score(floors_skipped)
	
	# Check if this qualifies as a combo (skipped 2+ floors)
	if floors_skipped >= MIN_COMBO_FLOORS:
		# This is a COMBO jump!
		
		# Update streak
		if is_streak_active and streak_timer > 0:
			# Continue streak
			combo_streak += 1
		else:
			# Start new streak
			combo_streak = 1
			is_streak_active = true
			combo_streak_started.emit()
		
		# Reset streak timer
		streak_timer = combo_window
		
		# Apply streak multiplier to score
		jump_score *= combo_streak
		
		# Emit combo signal with floors skipped
		combo_triggered.emit(floors_skipped)
		
		# Check for super/mega/ultra combos
		if floors_skipped >= ULTRA_COMBO_FLOORS:
			super_combo.emit(floors_skipped)
			GameManager.play_sound("ultra_jump")
		elif floors_skipped >= MEGA_COMBO_FLOORS:
			super_combo.emit(floors_skipped)
			GameManager.play_sound("mega_jump")
		elif floors_skipped >= SUPER_COMBO_FLOORS:
			super_combo.emit(floors_skipped)
			GameManager.play_sound("super_jump")
	else:
		# Small jump (1 floor) - ends streak but still scores
		if is_streak_active:
			end_streak()
	
	return jump_score

func calculate_jump_score(floors_skipped: int) -> int:
	# Base score: 10 points per floor
	var base_score = floors_skipped * 10
	
	# Bonus points for big jumps
	if floors_skipped >= ULTRA_COMBO_FLOORS:
		base_score += 500
	elif floors_skipped >= MEGA_COMBO_FLOORS:
		base_score += 200
	elif floors_skipped >= SUPER_COMBO_FLOORS:
		base_score += 100
	elif floors_skipped >= MIN_COMBO_FLOORS:
		base_score += 25
	
	return base_score

func end_streak() -> void:
	if combo_streak > 1:
		combo_streak_ended.emit(combo_streak)
	is_streak_active = false
	combo_streak = 0
	streak_timer = 0.0

func get_streak_count() -> int:
	return combo_streak

func get_streak_timer_ratio() -> float:
	if combo_window <= 0:
		return 0.0
	return streak_timer / combo_window

func is_in_streak() -> bool:
	return is_streak_active and combo_streak > 0

func reset() -> void:
	combo_streak = 0
	streak_timer = 0.0
	is_streak_active = false
