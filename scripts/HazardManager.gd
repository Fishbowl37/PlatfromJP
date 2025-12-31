extends Node2D
class_name HazardManager

signal wind_zone_spawned(zone: WindZone)
signal vortex_zone_spawned(zone: VortexZone)

# References
var player: Player = null
var camera: Camera2D = null
var floor_generator: FloorGenerator = null

# Tower dimensions
@export var tower_width: float = 440.0
@export var tower_left_margin: float = 20.0

# Wind zone settings
@export_group("Wind Zones")
@export var wind_zone_start_floor: int = 400       # Start spawning wind zones
@export var wind_zone_chance: float = 0.15         # Chance per spawn check
@export var wind_zone_min_spacing: float = 1200.0  # Min distance between wind zones
@export var wind_strength_base: float = 450.0      # Base wind strength
@export var wind_strength_max: float = 700.0       # Max wind strength at high floors
@export var wind_zone_height_min: float = 800.0    # Min wind zone height (covers ~8 floors)
@export var wind_zone_height_max: float = 1500.0   # Max wind zone height (covers ~15 floors)
@export var wind_gusting_chance: float = 0.4       # Chance for gusting wind

# Vortex zone settings
@export_group("Vortex Zones")
@export var vortex_zone_start_floor: int = 600     # Start spawning vortex zones
@export var vortex_zone_chance: float = 0.12       # Chance per spawn check
@export var vortex_zone_min_spacing: float = 600.0 # Min distance between vortexes
@export var vortex_strength_base: float = 500.0    # Base vortex strength
@export var vortex_strength_max: float = 800.0     # Max vortex strength at high floors
@export var vortex_radius_min: float = 100.0       # Min vortex radius
@export var vortex_radius_max: float = 200.0       # Max vortex radius
@export var suction_chance: float = 0.7            # Chance for suction (vs repulsion)

# Spawn tracking
var last_wind_zone_y: float = INF
var last_vortex_zone_y: float = INF
var generation_buffer: float = 800.0
var cleanup_buffer: float = 600.0

# Active hazards
var active_wind_zones: Array[WindZone] = []
var active_vortex_zones: Array[VortexZone] = []

# Spawn check interval (in meters of camera movement)
var last_check_y: float = INF
var check_interval: float = 200.0  # Check every 200 pixels of upward movement

func _ready() -> void:
	pass

func initialize(p: Player, cam: Camera2D, fg: FloorGenerator) -> void:
	player = p
	camera = cam
	floor_generator = fg
	
	# Get tower dimensions from floor generator
	if floor_generator:
		tower_width = floor_generator.tower_width
		tower_left_margin = floor_generator.tower_left_margin
	
	last_check_y = INF
	last_wind_zone_y = INF
	last_vortex_zone_y = INF

func _process(_delta: float) -> void:
	if not camera or not floor_generator:
		return
	
	if not GameManager.is_game_active:
		return
	
	var camera_y = camera.global_position.y
	
	# Check if we should try spawning hazards
	if camera_y < last_check_y - check_interval:
		last_check_y = camera_y
		try_spawn_hazards()
	
	# Cleanup hazards below camera
	cleanup_old_hazards()

func try_spawn_hazards() -> void:
	var current_floor = floor_generator.get_current_floor_count()
	var camera_y = camera.global_position.y
	
	# Try spawning wind zone
	if current_floor >= wind_zone_start_floor:
		if camera_y < last_wind_zone_y - wind_zone_min_spacing:
			if randf() < wind_zone_chance:
				spawn_wind_zone(camera_y - generation_buffer)
	
	# Try spawning vortex zone
	if current_floor >= vortex_zone_start_floor:
		if camera_y < last_vortex_zone_y - vortex_zone_min_spacing:
			if randf() < vortex_zone_chance:
				spawn_vortex_zone(camera_y - generation_buffer)

func spawn_wind_zone(y_pos: float) -> void:
	var wind_zone = WindZone.new()
	add_child(wind_zone)
	
	# Calculate difficulty scaling
	var current_floor = floor_generator.get_current_floor_count()
	var difficulty = clamp(float(current_floor - wind_zone_start_floor) / 1000.0, 0.0, 1.0)
	
	# Random direction
	var direction = WindZone.WindDirection.RIGHT if randf() > 0.5 else WindZone.WindDirection.LEFT
	
	# Scale strength with difficulty
	var strength = lerp(wind_strength_base, wind_strength_max, difficulty)
	
	# Random height within range
	var height = randf_range(wind_zone_height_min, wind_zone_height_max)
	
	# Whether it's gusting (more common at higher difficulty)
	var is_gusting = randf() < (wind_gusting_chance + difficulty * 0.2)
	
	# Position in center of tower
	var center_x = tower_left_margin + tower_width / 2.0
	
	wind_zone.zone_width = tower_width
	wind_zone.set_tower_bounds(tower_left_margin, tower_left_margin + tower_width)
	wind_zone.setup(Vector2(center_x, y_pos), direction, strength, height, is_gusting, 0.0)
	
	active_wind_zones.append(wind_zone)
	last_wind_zone_y = y_pos
	
	wind_zone.wind_zone_expired.connect(_on_wind_zone_expired)
	wind_zone_spawned.emit(wind_zone)

func spawn_vortex_zone(y_pos: float) -> void:
	var vortex_zone = VortexZone.new()
	add_child(vortex_zone)
	
	# Calculate difficulty scaling
	var current_floor = floor_generator.get_current_floor_count()
	var difficulty = clamp(float(current_floor - vortex_zone_start_floor) / 1000.0, 0.0, 1.0)
	
	# Suction is more dangerous (pulls toward walls potentially), more common
	var type = VortexZone.VortexType.SUCTION if randf() < suction_chance else VortexZone.VortexType.REPULSION
	
	# Scale strength with difficulty
	var strength = lerp(vortex_strength_base, vortex_strength_max, difficulty)
	
	# Random radius
	var radius = randf_range(vortex_radius_min, vortex_radius_max)
	
	# Random X position within tower (avoid edges for suction vortexes)
	var x_margin = radius if type == VortexZone.VortexType.SUCTION else radius * 0.5
	var min_x = tower_left_margin + x_margin
	var max_x = tower_left_margin + tower_width - x_margin
	var x_pos = randf_range(min_x, max_x)
	
	vortex_zone.setup(Vector2(x_pos, y_pos), type, strength, radius, true, 0.0)
	
	active_vortex_zones.append(vortex_zone)
	last_vortex_zone_y = y_pos
	
	vortex_zone.vortex_zone_expired.connect(_on_vortex_zone_expired)
	vortex_zone_spawned.emit(vortex_zone)

func cleanup_old_hazards() -> void:
	if not camera:
		return
	
	var cleanup_threshold = camera.global_position.y + cleanup_buffer
	
	# Cleanup wind zones
	for zone in active_wind_zones.duplicate():
		if zone.global_position.y > cleanup_threshold:
			zone.expire()
	
	# Cleanup vortex zones
	for zone in active_vortex_zones.duplicate():
		if zone.global_position.y > cleanup_threshold:
			zone.expire()

func _on_wind_zone_expired(zone: WindZone) -> void:
	active_wind_zones.erase(zone)

func _on_vortex_zone_expired(zone: VortexZone) -> void:
	active_vortex_zones.erase(zone)

func reset() -> void:
	# Clear all active hazards
	for zone in active_wind_zones.duplicate():
		zone.queue_free()
	active_wind_zones.clear()
	
	for zone in active_vortex_zones.duplicate():
		zone.queue_free()
	active_vortex_zones.clear()
	
	# Reset tracking
	last_check_y = INF
	last_wind_zone_y = INF
	last_vortex_zone_y = INF

# Get combined environmental force at a position (for HUD indicators, etc.)
func get_environmental_force_at(pos: Vector2) -> Vector2:
	var total_force = Vector2.ZERO
	
	# Check wind zones
	for zone in active_wind_zones:
		var half_height = zone.zone_height / 2
		if pos.y > zone.global_position.y - half_height and pos.y < zone.global_position.y + half_height:
			total_force += zone.get_wind_force()
	
	# Check vortex zones
	for zone in active_vortex_zones:
		var distance = pos.distance_to(zone.global_position)
		if distance < zone.vortex_radius:
			total_force += zone.get_vortex_force(pos)
	
	return total_force

# Debug: Get active hazard count
func get_active_hazard_count() -> Dictionary:
	return {
		"wind_zones": active_wind_zones.size(),
		"vortex_zones": active_vortex_zones.size()
	}

