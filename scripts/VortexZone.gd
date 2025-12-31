extends Area2D
class_name VortexZone

signal vortex_zone_expired(zone: VortexZone)

enum VortexType { 
	SUCTION,   # Pulls player toward center (dangerous near walls)
	REPULSION  # Pushes player away from center (can help escape)
}

@export var vortex_type: VortexType = VortexType.SUCTION
@export var vortex_strength: float = 300.0   # Force applied to player
@export var vortex_radius: float = 150.0     # Radius of effect
@export var pulsing: bool = true             # Pulse effect
@export var pulse_min: float = 0.6           # Minimum strength multiplier
@export var pulse_max: float = 1.2           # Maximum strength multiplier
@export var pulse_speed: float = 3.0         # Pulse frequency
@export var lifetime: float = 0.0            # 0 = infinite

# Visual settings
const SUCTION_COLOR = Color(0.8, 0.2, 1.0, 0.5)    # Purple
const REPULSION_COLOR = Color(0.2, 1.0, 0.5, 0.5)  # Green
const RING_COUNT = 4
const PARTICLE_COUNT = 12

# State
var is_active: bool = true
var player_in_zone: bool = false
var player_ref: Player = null
var lifetime_timer: float = 0.0
var pulse_timer: float = 0.0
var current_pulse_mult: float = 1.0

# Visual elements
var rings: Array[Node2D] = []
var particles: Array[ColorRect] = []
var core_glow: ColorRect = null
var outer_glow: ColorRect = null

func _ready() -> void:
	# Setup collision shape (circular)
	setup_collision()
	
	# Create visual effects
	create_visuals()
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set collision
	collision_layer = 0
	collision_mask = 1  # Detect player (layer 1)

func setup_collision() -> void:
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = vortex_radius
	collision.shape = shape
	add_child(collision)

func create_visuals() -> void:
	var vortex_color = SUCTION_COLOR if vortex_type == VortexType.SUCTION else REPULSION_COLOR
	
	# Outer glow (soft)
	outer_glow = ColorRect.new()
	outer_glow.size = Vector2(vortex_radius * 2.5, vortex_radius * 2.5)
	outer_glow.position = -outer_glow.size / 2
	outer_glow.color = Color(vortex_color.r, vortex_color.g, vortex_color.b, 0.1)
	outer_glow.z_index = -6
	add_child(outer_glow)
	
	# Core glow (bright center)
	core_glow = ColorRect.new()
	core_glow.size = Vector2(40, 40)
	core_glow.position = -core_glow.size / 2
	core_glow.pivot_offset = core_glow.size / 2
	core_glow.color = Color(vortex_color.r, vortex_color.g, vortex_color.b, 0.6)
	core_glow.z_index = -4
	add_child(core_glow)
	
	# Create swirling rings
	for i in range(RING_COUNT):
		var ring = create_ring(i, vortex_color)
		add_child(ring)
		rings.append(ring)
	
	# Create orbiting particles
	for i in range(PARTICLE_COUNT):
		var particle = ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.pivot_offset = Vector2(3, 3)
		particle.color = Color(1, 1, 1, 0.6)
		particle.z_index = -3
		add_child(particle)
		particles.append(particle)

func create_ring(index: int, color: Color) -> Node2D:
	var ring_container = Node2D.new()
	ring_container.z_index = -5
	
	var ring_radius = vortex_radius * (0.3 + index * 0.2)
	var segments = 16
	var gap_size = 2  # Number of segments to skip for gaps
	
	for i in range(segments):
		# Create gaps in the ring
		if i % 4 < gap_size:
			continue
		
		var angle = (TAU / segments) * i
		var segment = ColorRect.new()
		segment.size = Vector2(12, 4)
		segment.pivot_offset = Vector2(6, 2)
		segment.rotation = angle + PI/2
		segment.position = Vector2(cos(angle), sin(angle)) * ring_radius
		segment.color = Color(color.r, color.g, color.b, 0.3 - index * 0.05)
		ring_container.add_child(segment)
	
	return ring_container

func _process(delta: float) -> void:
	# Handle pulsing
	if pulsing:
		pulse_timer += delta * pulse_speed
		current_pulse_mult = lerp(pulse_min, pulse_max, (sin(pulse_timer) + 1) / 2)
		
		# Pulse the core glow
		if core_glow:
			var scale_mult = 0.8 + current_pulse_mult * 0.4
			core_glow.scale = Vector2(scale_mult, scale_mult)
	
	# Handle lifetime
	if lifetime > 0:
		lifetime_timer += delta
		if lifetime_timer >= lifetime:
			expire()
			return
	
	# Animate visuals
	animate_vortex(delta)
	
	# Apply vortex force to player if in zone
	if player_in_zone and player_ref and is_active:
		apply_vortex_force(delta)

func animate_vortex(delta: float) -> void:
	var rotation_direction = 1.0 if vortex_type == VortexType.SUCTION else -1.0
	
	# Rotate rings (each at different speed)
	for i in range(rings.size()):
		var speed = (1.0 + i * 0.3) * rotation_direction
		rings[i].rotation += speed * delta
	
	# Animate orbiting particles
	var base_orbit_speed = 2.5 * rotation_direction
	for i in range(particles.size()):
		var particle = particles[i]
		var angle_offset = (TAU / PARTICLE_COUNT) * i
		var orbit_radius = vortex_radius * (0.4 + (i % 3) * 0.2)
		
		# Calculate position (spiral inward for suction, outward for repulsion)
		var time_offset = Time.get_ticks_msec() / 1000.0
		var angle = angle_offset + time_offset * base_orbit_speed
		
		if vortex_type == VortexType.SUCTION:
			# Spiral inward
			var spiral = fmod(time_offset * 0.5 + i * 0.1, 1.0)
			orbit_radius *= (1.0 - spiral * 0.3)
		else:
			# Spiral outward
			var spiral = fmod(time_offset * 0.5 + i * 0.1, 1.0)
			orbit_radius *= (0.7 + spiral * 0.3)
		
		particle.position = Vector2(cos(angle), sin(angle)) * orbit_radius
		
		# Fade based on distance from center
		var dist_ratio = particle.position.length() / vortex_radius
		particle.color.a = 0.6 * (1.0 - dist_ratio * 0.5)

func apply_vortex_force(delta: float) -> void:
	if not player_ref:
		return
	
	# Calculate direction to/from center
	var to_center = global_position - player_ref.global_position
	var distance = to_center.length()
	
	if distance < 10:  # Avoid division by zero
		return
	
	var direction = to_center.normalized()
	
	# Suction pulls toward center, repulsion pushes away
	if vortex_type == VortexType.REPULSION:
		direction = -direction
	
	# Strength falls off with distance (stronger closer to center)
	var distance_factor = 1.0 - (distance / vortex_radius)
	distance_factor = clamp(distance_factor, 0.2, 1.0)
	
	var force = vortex_strength * distance_factor * current_pulse_mult
	
	# Apply more force when player is in the air
	if not player_ref.is_on_floor():
		force *= 1.3
	
	# Add to player's velocity
	player_ref.velocity += direction * force * delta

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_zone = true
		player_ref = body
		
		# Visual feedback - intensify
		var tween = create_tween()
		tween.tween_property(core_glow, "color:a", 0.9, 0.2)
		if outer_glow:
			var outer_tween = create_tween()
			outer_tween.tween_property(outer_glow, "color:a", 0.2, 0.2)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_zone = false
		player_ref = null
		
		# Visual feedback - dim
		var tween = create_tween()
		tween.tween_property(core_glow, "color:a", 0.6, 0.2)
		if outer_glow:
			var outer_tween = create_tween()
			outer_tween.tween_property(outer_glow, "color:a", 0.1, 0.2)

func setup(pos: Vector2, type: VortexType, strength: float = 300.0, radius: float = 150.0, is_pulsing: bool = true, life: float = 0.0) -> void:
	global_position = pos
	vortex_type = type
	vortex_strength = strength
	vortex_radius = radius
	pulsing = is_pulsing
	lifetime = life
	
	# Clear and recreate visuals
	for ring in rings:
		ring.queue_free()
	rings.clear()
	
	for particle in particles:
		particle.queue_free()
	particles.clear()
	
	if core_glow:
		core_glow.queue_free()
		core_glow = null
	
	if outer_glow:
		outer_glow.queue_free()
		outer_glow = null
	
	# Rebuild collision
	for child in get_children():
		if child is CollisionShape2D:
			child.queue_free()
	
	setup_collision()
	create_visuals()

func expire() -> void:
	is_active = false
	
	# Implode effect for suction, explode for repulsion
	var tween = create_tween()
	tween.set_parallel(true)
	
	if vortex_type == VortexType.SUCTION:
		tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.3).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.3).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(func():
		vortex_zone_expired.emit(self)
		queue_free()
	)

func get_vortex_force(from_position: Vector2) -> Vector2:
	if not is_active:
		return Vector2.ZERO
	
	var to_center = global_position - from_position
	var distance = to_center.length()
	
	if distance < 10 or distance > vortex_radius:
		return Vector2.ZERO
	
	var direction = to_center.normalized()
	if vortex_type == VortexType.REPULSION:
		direction = -direction
	
	var distance_factor = 1.0 - (distance / vortex_radius)
	distance_factor = clamp(distance_factor, 0.2, 1.0)
	
	return direction * vortex_strength * distance_factor * current_pulse_mult

