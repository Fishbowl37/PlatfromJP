extends Area2D
class_name PowerUp

signal collected(power_up: PowerUp)

enum Type {
	SHIELD,       # Protects from one death
	TIME_STOP,    # Pauses camera for a few seconds
	SCORE_2X,     # Double score for duration
	MEGA_JUMP,    # Instant super jump
	COIN          # Bonus points
}

@export var power_up_type: Type = Type.SHIELD
@export var float_amplitude: float = 8.0
@export var float_speed: float = 3.0
@export var rotation_speed: float = 2.0
@export var glow_speed: float = 4.0

# Visual nodes
var icon_label: Label
var glow_effect: ColorRect
var particle_trail: GPUParticles2D

# Animation state
var base_y: float = 0.0
var time_alive: float = 0.0
var is_collected: bool = false

# Type configurations - ALL effects are now TIMED
const TYPE_CONFIG = {
	Type.SHIELD: {
		"icon": "🛡️",
		"color": Color(0.3, 0.7, 1.0),
		"glow_color": Color(0.3, 0.7, 1.0, 0.4),
		"name": "SHIELD",
		"duration": 20.0,  # 20 seconds to use the shield
		"points": 0
	},
	Type.TIME_STOP: {
		"icon": "⏱️",
		"color": Color(1.0, 0.9, 0.3),
		"glow_color": Color(1.0, 0.9, 0.3, 0.4),
		"name": "TIME STOP",
		"duration": 6.0,  # 6 seconds of frozen camera
		"points": 0
	},
	Type.SCORE_2X: {
		"icon": "✨",
		"color": Color(1.0, 0.5, 0.8),
		"glow_color": Color(1.0, 0.5, 0.8, 0.4),
		"name": "2X SCORE",
		"duration": 12.0,  # 12 seconds of double points
		"points": 0
	},
	Type.MEGA_JUMP: {
		"icon": "🚀",
		"color": Color(0.4, 1.0, 0.4),
		"glow_color": Color(0.4, 1.0, 0.4, 0.4),
		"name": "MEGA JUMP",
		"duration": 8.0,  # 8 seconds of super jumps
		"points": 0
	},
	Type.COIN: {
		"icon": "💎",
		"color": Color(0.2, 0.9, 1.0),
		"glow_color": Color(0.2, 0.9, 1.0, 0.4),
		"name": "GEM",
		"duration": 0.0,  # Instant - adds 1-3 gems
		"points": 0
	}
}

func _ready() -> void:
	base_y = global_position.y
	
	# Setup Area2D properties FIRST
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1  # Player is on layer 1
	
	setup_visual()
	setup_collision()
	
	# Connect body entered signal
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	
	time_alive += delta
	
	# Floating animation
	global_position.y = base_y + sin(time_alive * float_speed) * float_amplitude
	
	# Rotation
	if icon_label:
		icon_label.rotation = sin(time_alive * rotation_speed) * 0.15
	
	# Glow pulsing
	if glow_effect:
		var pulse = (sin(time_alive * glow_speed) + 1) * 0.5
		var config = TYPE_CONFIG[power_up_type]
		glow_effect.modulate.a = 0.3 + pulse * 0.4
		glow_effect.scale = Vector2(1.0 + pulse * 0.2, 1.0 + pulse * 0.2)

func setup_visual() -> void:
	var config = TYPE_CONFIG[power_up_type]
	
	# Create glow background
	glow_effect = ColorRect.new()
	glow_effect.size = Vector2(50, 50)
	glow_effect.position = Vector2(-25, -25)
	glow_effect.color = config["glow_color"]
	glow_effect.pivot_offset = Vector2(25, 25)
	add_child(glow_effect)
	
	# Create icon
	icon_label = Label.new()
	icon_label.text = config["icon"]
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.size = Vector2(50, 50)
	icon_label.position = Vector2(-25, -30)
	icon_label.pivot_offset = Vector2(25, 25)
	add_child(icon_label)
	
	# Create particle trail
	setup_particles(config["color"])

func setup_particles(color: Color) -> void:
	particle_trail = GPUParticles2D.new()
	particle_trail.amount = 12
	particle_trail.lifetime = 0.8
	particle_trail.preprocess = 0.5
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 15.0
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 25.0
	material.gravity = Vector3(0, -30, 0)
	material.scale_min = 3.0
	material.scale_max = 6.0
	material.color = color
	
	particle_trail.process_material = material
	particle_trail.emitting = true
	add_child(particle_trail)

func setup_collision() -> void:
	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30.0  # Slightly larger for easier pickup
	collision.shape = shape
	add_child(collision)

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	
	if body is Player:
		collect()

func collect() -> void:
	if is_collected:
		return
	
	is_collected = true
	
	# Emit signal
	collected.emit(self)
	
	# Collection animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	
	if particle_trail:
		particle_trail.emitting = false
	
	# Play sound
	GameManager.play_sound("powerup")
	
	tween.chain().tween_callback(queue_free)

func get_type() -> Type:
	return power_up_type

func get_type_name() -> String:
	return TYPE_CONFIG[power_up_type]["name"]

func get_color() -> Color:
	return TYPE_CONFIG[power_up_type]["color"]

func get_duration() -> float:
	return TYPE_CONFIG[power_up_type]["duration"]

func get_points() -> int:
	return TYPE_CONFIG[power_up_type]["points"]

func set_type(type: Type) -> void:
	power_up_type = type
	if icon_label:
		setup_visual()

static func get_random_type() -> Type:
	var types = [Type.SHIELD, Type.TIME_STOP, Type.SCORE_2X, Type.MEGA_JUMP, Type.COIN]
	var weights = [15, 10, 20, 10, 45]  # Coins most common, time stop/mega jump rare
	
	var total_weight = 0
	for w in weights:
		total_weight += w
	
	var roll = randi() % total_weight
	var cumulative = 0
	
	for i in range(types.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return types[i]
	
	return Type.COIN

