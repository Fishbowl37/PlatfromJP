extends Node
class_name PowerUpManager

signal power_up_activated(type: PowerUp.Type, duration: float)
signal power_up_expired(type: PowerUp.Type)
signal shield_used
signal score_multiplier_changed(multiplier: float)
signal mega_jump_changed(active: bool)

# Power-up scene
var power_up_scene: PackedScene

# Active power-ups with remaining time - ALL effects are timed now
var active_effects: Dictionary = {}  # Type -> remaining_time

# Score multiplier
var score_multiplier: float = 1.0

# Mega jump multiplier
var mega_jump_multiplier: float = 1.0
const MEGA_JUMP_BOOST: float = 2.5  # 2.5x jump force during mega jump

# Spawning settings
@export var spawn_chance_base: float = 0.08  # 8% base chance per floor
@export var spawn_chance_increase_per_100: float = 0.02  # +2% per 100 floors
@export var max_spawn_chance: float = 0.20  # 20% max
@export var min_floor_for_spawn: int = 20  # Start spawning after floor 20

# References
var player: Player = null
var camera: Camera2D = null
var floor_generator: Node = null

# Active power-up nodes in the world
var active_power_ups: Array[PowerUp] = []

func _ready() -> void:
	power_up_scene = preload("res://scenes/PowerUp.tscn")

func _process(delta: float) -> void:
	update_active_effects(delta)

func initialize(p: Player, cam: Camera2D, generator: Node) -> void:
	player = p
	camera = cam
	floor_generator = generator

func update_active_effects(delta: float) -> void:
	var expired_types: Array[PowerUp.Type] = []
	
	for type in active_effects.keys():
		active_effects[type] -= delta
		if active_effects[type] <= 0:
			expired_types.append(type)
	
	for type in expired_types:
		expire_effect(type)

func expire_effect(type: PowerUp.Type) -> void:
	active_effects.erase(type)
	
	match type:
		PowerUp.Type.SHIELD:
			# Shield expired without being used
			pass
		PowerUp.Type.TIME_STOP:
			if camera and camera.has_method("resume_scrolling"):
				camera.resume_scrolling()
		PowerUp.Type.SCORE_2X:
			score_multiplier = 1.0
			score_multiplier_changed.emit(score_multiplier)
		PowerUp.Type.MEGA_JUMP:
			mega_jump_multiplier = 1.0
			mega_jump_changed.emit(false)
	
	power_up_expired.emit(type)

# Called when player collects a power-up
func on_power_up_collected(power_up: PowerUp) -> void:
	var type = power_up.get_type()
	var duration = power_up.get_duration()
	var points = power_up.get_points()
	
	# Add bonus points
	if points > 0:
		GameManager.add_score(int(points * score_multiplier))
	
	# Apply effect based on type
	match type:
		PowerUp.Type.SHIELD:
			activate_shield(duration)
		PowerUp.Type.TIME_STOP:
			activate_time_stop(duration)
		PowerUp.Type.SCORE_2X:
			activate_score_2x(duration)
		PowerUp.Type.MEGA_JUMP:
			activate_mega_jump(duration)
		PowerUp.Type.COIN:
			# Just points, show brief indicator
			power_up_activated.emit(type, 0.0)
	
	# Remove from active list
	active_power_ups.erase(power_up)

func activate_shield(duration: float) -> void:
	# Stack time if already active
	if PowerUp.Type.SHIELD in active_effects:
		active_effects[PowerUp.Type.SHIELD] += duration * 0.5  # Partial stack
	else:
		active_effects[PowerUp.Type.SHIELD] = duration
	
	power_up_activated.emit(PowerUp.Type.SHIELD, active_effects[PowerUp.Type.SHIELD])

func activate_time_stop(duration: float) -> void:
	# Stack time if already active
	if PowerUp.Type.TIME_STOP in active_effects:
		active_effects[PowerUp.Type.TIME_STOP] += duration * 0.5
	else:
		active_effects[PowerUp.Type.TIME_STOP] = duration
	
	if camera and camera.has_method("pause_scrolling_temporary"):
		camera.pause_scrolling_temporary(active_effects[PowerUp.Type.TIME_STOP])
	
	power_up_activated.emit(PowerUp.Type.TIME_STOP, active_effects[PowerUp.Type.TIME_STOP])

func activate_score_2x(duration: float) -> void:
	# Stack time if already active
	if PowerUp.Type.SCORE_2X in active_effects:
		active_effects[PowerUp.Type.SCORE_2X] += duration * 0.5
	else:
		active_effects[PowerUp.Type.SCORE_2X] = duration
	
	score_multiplier = 2.0
	score_multiplier_changed.emit(score_multiplier)
	power_up_activated.emit(PowerUp.Type.SCORE_2X, active_effects[PowerUp.Type.SCORE_2X])

func activate_mega_jump(duration: float) -> void:
	# Stack time if already active
	if PowerUp.Type.MEGA_JUMP in active_effects:
		active_effects[PowerUp.Type.MEGA_JUMP] += duration * 0.5
	else:
		active_effects[PowerUp.Type.MEGA_JUMP] = duration
		mega_jump_multiplier = MEGA_JUMP_BOOST
		mega_jump_changed.emit(true)
	
	power_up_activated.emit(PowerUp.Type.MEGA_JUMP, active_effects[PowerUp.Type.MEGA_JUMP])

# Called when player would die - returns true if shield was used
func try_use_shield() -> bool:
	if has_active_shield():
		active_effects.erase(PowerUp.Type.SHIELD)
		shield_used.emit()
		return true
	return false

func get_score_multiplier() -> float:
	return score_multiplier

func get_jump_multiplier() -> float:
	return mega_jump_multiplier

func has_active_shield() -> bool:
	return PowerUp.Type.SHIELD in active_effects and active_effects[PowerUp.Type.SHIELD] > 0

func is_mega_jump_active() -> bool:
	return PowerUp.Type.MEGA_JUMP in active_effects and active_effects[PowerUp.Type.MEGA_JUMP] > 0

func is_time_stopped() -> bool:
	return PowerUp.Type.TIME_STOP in active_effects and active_effects[PowerUp.Type.TIME_STOP] > 0

func get_remaining_time(type: PowerUp.Type) -> float:
	if type in active_effects:
		return active_effects[type]
	return 0.0

func get_all_active_effects() -> Dictionary:
	return active_effects.duplicate()

# Spawning logic
func should_spawn_on_floor(floor_number: int) -> bool:
	if floor_number < min_floor_for_spawn:
		return false
	
	# Don't spawn on milestone floors (they're already special)
	if floor_number % 50 == 0:
		return false
	
	# Calculate spawn chance
	var bonus_chance = (floor_number / 100) * spawn_chance_increase_per_100
	var total_chance = min(spawn_chance_base + bonus_chance, max_spawn_chance)
	
	return randf() < total_chance

func spawn_power_up_at(position: Vector2, parent: Node) -> PowerUp:
	var power_up = power_up_scene.instantiate() as PowerUp
	power_up.power_up_type = PowerUp.get_random_type()
	power_up.global_position = position
	power_up.collected.connect(on_power_up_collected)
	
	parent.add_child(power_up)
	active_power_ups.append(power_up)
	
	return power_up

func cleanup_power_ups_below(y_threshold: float) -> void:
	for power_up in active_power_ups.duplicate():
		if power_up.global_position.y > y_threshold:
			active_power_ups.erase(power_up)
			power_up.queue_free()

func reset() -> void:
	# Clear all active effects
	for type in active_effects.keys():
		expire_effect(type)
	active_effects.clear()
	
	# Reset multipliers
	score_multiplier = 1.0
	mega_jump_multiplier = 1.0
	score_multiplier_changed.emit(score_multiplier)
	mega_jump_changed.emit(false)
	
	# Clear spawned power-ups
	for power_up in active_power_ups:
		if is_instance_valid(power_up):
			power_up.queue_free()
	active_power_ups.clear()
