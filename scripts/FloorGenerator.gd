extends Node2D
class_name FloorGenerator

signal floor_generated(floor_node: Floor, floor_number: int)
signal power_up_spawned(power_up: PowerUp, floor_node: Floor)

@export var floor_scene: PackedScene
@export var power_up_scene: PackedScene

# Base platform settings
@export_group("Platform Size")
@export var floor_spacing_min: float = 100.0
@export var floor_spacing_max: float = 160.0
@export var floor_width_min: float = 70.0
@export var floor_width_max: float = 180.0

# Tower dimensions
@export_group("Tower")
@export var tower_width: float = 440.0
@export var tower_left_margin: float = 20.0
@export var generation_buffer: float = 800.0
@export var cleanup_buffer: float = 600.0

# Progressive difficulty settings
@export_group("Difficulty Scaling")
@export var difficulty_ramp_floors: int = 1500 # Floors to reach max difficulty
@export var min_width_at_max: float = 60.0
@export var max_spacing_at_max: float = 180.0

# Area boundaries
@export_group("Area Zones")
@export var learning_end: int = 300        # 1-300: Regular only
@export var moving_zone_end: int = 600     # 300-600: Moving platforms
@export var crumbling_zone_end: int = 900  # 600-900: Crumbling platforms
@export var ice_zone_end: int = 1200       # 900-1200: Ice platforms
@export var spring_zone_end: int = 1500    # 1200-1500: Spring platforms
# 1500+: Endgame - all types mixed

# Special platform chance within zones
@export_group("Zone Settings")
@export var special_platform_chance: float = 0.4  # 40% chance in zones
@export var endgame_special_chance: float = 0.5   # 50% chance in endgame

# Power-up spawning
@export_group("Power-ups")
@export var power_up_spawn_chance: float = 0.08   # 8% chance per floor
@export var power_up_min_floor: int = 20          # Start spawning at floor 20
@export var power_up_chance_increase: float = 0.01 # +1% per 100 floors

var current_floor_number: int = 0
var highest_floor_y: float = 0.0
var floor_pool: Array[Floor] = []
var active_floors: Array[Floor] = []
var last_floor_type: Floor.FloorType = Floor.FloorType.NORMAL
var ground_base: StaticBody2D = null

@onready var camera: Camera2D = null

func _ready() -> void:
	if floor_scene == null:
		floor_scene = preload("res://scenes/Floor.tscn")
	if power_up_scene == null:
		power_up_scene = preload("res://scenes/PowerUp.tscn")

func initialize(cam: Camera2D, start_y: float) -> void:
	camera = cam
	highest_floor_y = start_y
	current_floor_number = 0
	last_floor_type = Floor.FloorType.NORMAL
	
	# Generate starting platform (ground)
	spawn_ground_floor(start_y)
	
	# Pre-generate some floors
	for i in range(15):
		generate_next_floor()

func _process(_delta: float) -> void:
	if camera == null:
		return
	
	# Generate floors above camera view
	while highest_floor_y > camera.global_position.y - generation_buffer:
		generate_next_floor()
	
	# Cleanup floors below camera view
	cleanup_old_floors()

func spawn_ground_floor(y_pos: float) -> void:
	var ground = get_floor_from_pool()
	var center_x = tower_left_margin + tower_width / 2.0
	ground.global_position = Vector2(center_x, y_pos)
	ground.set_tower_bounds(tower_left_margin, tower_left_margin + tower_width)
	ground.setup(0, tower_width, Floor.FloorType.NORMAL)
	active_floors.append(ground)
	
	# Create a solid base below the ground floor so nothing can fall through
	create_ground_base(y_pos, center_x)

func create_ground_base(y_pos: float, center_x: float) -> void:
	# Remove old ground base if exists
	if ground_base and is_instance_valid(ground_base):
		ground_base.queue_free()
	
	# Create a large solid floor that extends far below
	ground_base = StaticBody2D.new()
	ground_base.global_position = Vector2(center_x, y_pos + 500)  # 500 pixels below ground floor
	
	# Collision shape - very tall to catch anything
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(tower_width, 1000)  # 1000 pixels tall, same width as tower
	collision.shape = shape
	ground_base.add_child(collision)
	
	# Visual - same color as normal platform
	var visual = ColorRect.new()
	visual.size = Vector2(tower_width, 1000)
	visual.position = Vector2(-tower_width / 2, -500)
	visual.color = Color(0.2, 0.35, 0.55)  # NORMAL_COLOR - same as regular platforms
	visual.z_index = -2
	ground_base.add_child(visual)
	
	# Top highlight to match platform style
	var top_highlight = ColorRect.new()
	top_highlight.size = Vector2(tower_width, 4)
	top_highlight.position = Vector2(-tower_width / 2, -500)
	top_highlight.color = Color(0.35, 0.55, 0.8)  # NORMAL_TOP color
	top_highlight.z_index = -1
	ground_base.add_child(top_highlight)
	
	# Set collision layer same as floors
	ground_base.collision_layer = 2
	ground_base.collision_mask = 0
	
	add_child(ground_base)

func generate_next_floor() -> void:
	current_floor_number += 1
	
	# Calculate difficulty factor (0.0 to 1.0)
	var difficulty = get_difficulty_factor()
	
	# Calculate vertical spacing (increases with difficulty)
	var base_spacing = lerp(floor_spacing_min, floor_spacing_max, difficulty * 0.5)
	var max_spacing = lerp(floor_spacing_max, max_spacing_at_max, difficulty)
	var spacing = randf_range(base_spacing, max_spacing)
	
	highest_floor_y -= spacing
	
	# Calculate floor width (decreases with difficulty)
	var base_width = lerp(floor_width_max, floor_width_min, difficulty * 0.6)
	var min_width = lerp(floor_width_min, min_width_at_max, difficulty)
	var width = randf_range(min_width, base_width)
	width = clamp(width, min_width_at_max, floor_width_max)
	
	# Determine floor type based on zone
	var floor_type = determine_floor_type()
	
	# Spring platforms should be wider for balance
	if floor_type == Floor.FloorType.SPRING:
		width = max(width, 100.0)
	
	# Calculate horizontal position within tower bounds
	var half_width = width / 2.0
	var min_x = tower_left_margin + half_width + 5
	var max_x = tower_left_margin + tower_width - half_width - 5
	var x_pos = randf_range(min_x, max_x)
	
	# Spawn the floor
	var floor_node = get_floor_from_pool()
	floor_node.global_position = Vector2(x_pos, highest_floor_y)
	floor_node.set_tower_bounds(tower_left_margin, tower_left_margin + tower_width)
	floor_node.setup(current_floor_number, width, floor_type)
	active_floors.append(floor_node)
	
	last_floor_type = floor_type
	
	floor_generated.emit(floor_node, current_floor_number)
	
	# Maybe spawn a power-up on this floor
	maybe_spawn_power_up(floor_node)

func get_difficulty_factor() -> float:
	return clamp(float(current_floor_number) / float(difficulty_ramp_floors), 0.0, 1.0)

func determine_floor_type() -> Floor.FloorType:
	# Milestone floors are always normal and wide
	if current_floor_number % 50 == 0:
		return Floor.FloorType.NORMAL
	
	# Every 10 floors is a safe floor
	if current_floor_number % 10 == 0:
		return Floor.FloorType.NORMAL
	
	# Don't have too many special floors in a row
	if last_floor_type != Floor.FloorType.NORMAL:
		if randf() > 0.5:  # 50% chance to force normal after special
			return Floor.FloorType.NORMAL
	
	# Zone 1: Learning (1-300) - Regular platforms only
	if current_floor_number <= learning_end:
		return Floor.FloorType.NORMAL
	
	# Zone 2: Moving (300-600)
	elif current_floor_number <= moving_zone_end:
		if randf() < special_platform_chance:
			return Floor.FloorType.MOVING
		return Floor.FloorType.NORMAL
	
	# Zone 3: Crumbling (600-900)
	elif current_floor_number <= crumbling_zone_end:
		if randf() < special_platform_chance:
			return Floor.FloorType.CRUMBLING
		return Floor.FloorType.NORMAL
	
	# Zone 4: Ice (900-1200)
	elif current_floor_number <= ice_zone_end:
		if randf() < special_platform_chance:
			return Floor.FloorType.ICE
		return Floor.FloorType.NORMAL
	
	# Zone 5: Spring (1200-1500)
	elif current_floor_number <= spring_zone_end:
		if randf() < special_platform_chance:
			return Floor.FloorType.SPRING
		return Floor.FloorType.NORMAL
	
	# Endgame (1500+): All types mixed!
	else:
		if randf() < endgame_special_chance:
			var types = [
				Floor.FloorType.MOVING,
				Floor.FloorType.CRUMBLING,
				Floor.FloorType.ICE,
				Floor.FloorType.SPRING
			]
			return types[randi() % types.size()]
		return Floor.FloorType.NORMAL

func get_current_zone_name() -> String:
	if current_floor_number <= learning_end:
		return "LEARNING"
	elif current_floor_number <= moving_zone_end:
		return "MOVING ZONE"
	elif current_floor_number <= crumbling_zone_end:
		return "CRUMBLING ZONE"
	elif current_floor_number <= ice_zone_end:
		return "ICE ZONE"
	elif current_floor_number <= spring_zone_end:
		return "SPRING ZONE"
	else:
		return "ENDGAME"

func get_floor_from_pool() -> Floor:
	if floor_pool.size() > 0:
		var floor_node = floor_pool.pop_back()
		floor_node.visible = true
		floor_node.set_process(true)
		floor_node.modulate.a = 1.0
		return floor_node
	else:
		var new_floor = floor_scene.instantiate() as Floor
		add_child(new_floor)
		return new_floor

func return_to_pool(floor_node: Floor) -> void:
	floor_node.visible = false
	floor_node.set_process(false)
	active_floors.erase(floor_node)
	floor_pool.append(floor_node)

func cleanup_old_floors() -> void:
	if camera == null:
		return
	
	var cleanup_threshold = camera.global_position.y + cleanup_buffer
	
	for floor_node in active_floors.duplicate():
		if floor_node.global_position.y > cleanup_threshold:
			return_to_pool(floor_node)

func reset() -> void:
	# Return all floors to pool
	for floor_node in active_floors.duplicate():
		return_to_pool(floor_node)
	
	# Remove ground base
	if ground_base and is_instance_valid(ground_base):
		ground_base.queue_free()
		ground_base = null
	
	current_floor_number = 0
	highest_floor_y = 0.0
	last_floor_type = Floor.FloorType.NORMAL

func get_current_floor_count() -> int:
	return current_floor_number

func get_difficulty_percentage() -> float:
	return get_difficulty_factor() * 100.0

func maybe_spawn_power_up(floor_node: Floor) -> void:
	# Don't spawn on early floors
	if current_floor_number < power_up_min_floor:
		return
	
	# Don't spawn on milestone floors (keep them clean)
	if current_floor_number % 50 == 0:
		return
	
	# Don't spawn on crumbling platforms (they disappear)
	if floor_node.floor_type == Floor.FloorType.CRUMBLING:
		return
	
	# Calculate spawn chance (increases with floor number)
	var bonus = (current_floor_number / 100) * power_up_chance_increase
	var total_chance = min(power_up_spawn_chance + bonus, 0.20)
	
	if randf() < total_chance:
		spawn_power_up_on_floor(floor_node)

func spawn_power_up_on_floor(floor_node: Floor) -> void:
	var power_up = power_up_scene.instantiate() as PowerUp
	power_up.power_up_type = PowerUp.get_random_type()
	
	# Position above the floor
	power_up.global_position = floor_node.global_position + Vector2(0, -40)
	
	add_child(power_up)
	power_up_spawned.emit(power_up, floor_node)
