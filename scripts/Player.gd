extends CharacterBody2D
class_name Player

signal floor_landed(floor_y: float)
signal player_died
signal power_up_collected(power_up: PowerUp)

# Movement parameters
@export_group("Movement")
@export var run_speed: float = 380.0
@export var acceleration: float = 4000.0  # Very fast acceleration
@export var friction: float = 2000.0
@export var air_friction: float = 100.0   # Keep momentum in air

# Ice platform movement
@export_group("Ice Physics")
@export var ice_friction: float = 150.0
@export var ice_acceleration: float = 800.0

# Jump parameters
@export_group("Jumping")
@export var base_jump_force: float = 750.0
@export var momentum_jump_bonus: float = 1.0
@export var max_jump_force: float = 1200.0
@export var gravity: float = 1400.0
@export var fall_gravity_multiplier: float = 1.2
@export var jump_cut_multiplier: float = 0.5

# Wall bounce parameters
@export_group("Wall Bounce")
@export var wall_bounce_force: float = 300.0
@export var wall_bounce_vertical_boost: float = -150.0

# Visual effects
@export_group("Visual Effects")
@export var trail_enabled: bool = true
@export var trail_spawn_rate: float = 0.03
@export var squash_stretch_enabled: bool = true

# State tracking
var is_jumping: bool = false
var was_on_floor: bool = false
var last_floor_y: float = 0.0
var touch_direction: float = 0.0  # Analog value from -1 to 1
var smoothed_touch_direction: float = 0.0  # Smoothed for better feel
var touch_jump_pressed: bool = false

# Jump assist (makes combos easier)
var coyote_timer: float = 0.0      # Time since left ground
var jump_buffer_timer: float = 0.0 # Time since jump was pressed
const COYOTE_TIME: float = 0.12    # Can still jump shortly after leaving platform
const JUMP_BUFFER: float = 0.15    # Remember jump input for a moment
var combo_jump_multiplier: float = 1.0
var power_up_jump_multiplier: float = 1.0  # From mega jump power-up
var current_floor: Floor = null
var is_on_ice: bool = false
var is_combo_active: bool = false
var has_shield: bool = false
var is_mega_jump_active: bool = false

# Trail effect
var trail_timer: float = 0.0
var trail_color: Color = Color(0.4, 0.6, 1.0, 0.5)

# Squash/stretch
var target_scale: Vector2 = Vector2.ONE
var current_visual_scale: Vector2 = Vector2.ONE

# Big jump roller effect
const BIG_JUMP_THRESHOLD: int = 10  # More than 10 platforms = big jump
var last_landing_floor_number: int = 0
var consecutive_big_jumps: int = 0
var is_rolling: bool = false
var roll_rotation: float = 0.0

# References
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var jump_particles: GPUParticles2D = $JumpParticles if has_node("JumpParticles") else null

# Animation state
var current_anim: String = "idle"

func _ready() -> void:
	last_floor_y = global_position.y

func _physics_process(delta: float) -> void:
	# Smooth the touch input for better mobile feel
	smooth_touch_input(delta)
	
	apply_gravity(delta)
	handle_movement(delta)
	handle_jump(delta)
	handle_wall_bounce()
	
	var was_on_floor_before = was_on_floor
	was_on_floor = is_on_floor()
	
	move_and_slide()
	
	detect_current_floor()
	
	# Check if we just landed
	if is_on_floor() and not was_on_floor_before:
		on_landed()
	
	update_sprite_direction()
	update_animation()
	update_visual_effects(delta)

func smooth_touch_input(_delta: float) -> void:
	# Direct input - no smoothing delay for instant response
	smoothed_touch_direction = touch_direction

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity_modifier = fall_gravity_multiplier if velocity.y > 0 else 1.0
		velocity.y += gravity * gravity_modifier * delta
		
		# Stretch while falling fast (subtle)
		if squash_stretch_enabled and velocity.y > 300:
			var stretch = min(velocity.y / 1000.0, 0.15)
			target_scale = Vector2(1.0 - stretch * 0.3, 1.0 + stretch)

func handle_movement(delta: float) -> void:
	var direction = get_input_direction()
	
	var current_acceleration = ice_acceleration if is_on_ice else acceleration
	var current_friction_value = ice_friction if is_on_ice else friction
	
	if abs(direction) > 0.01:
		var target_velocity = direction * run_speed
		
		# Instant acceleration - feels super responsive
		var accel = current_acceleration * 3.0
		velocity.x = move_toward(velocity.x, target_velocity, accel * delta)
	else:
		# Quick stop on ground, keep momentum in air
		var fric = current_friction_value if is_on_floor() else air_friction
		velocity.x = move_toward(velocity.x, 0, fric * delta)

func get_input_direction() -> float:
	var keyboard_dir = Input.get_axis("move_left", "move_right")
	if keyboard_dir != 0:
		return keyboard_dir
	# Return smoothed analog touch direction for better mobile feel
	return smoothed_touch_direction

func handle_jump(delta: float) -> void:
	var jump_pressed = Input.is_action_just_pressed("jump") or touch_jump_pressed
	var jump_released = Input.is_action_just_released("jump")
	
	# Update coyote time (allows jump shortly after leaving platform)
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta
	
	# Update jump buffer (remembers jump input)
	if jump_pressed:
		jump_buffer_timer = JUMP_BUFFER
		touch_jump_pressed = false
	else:
		jump_buffer_timer -= delta
	
	# Can jump if: on floor OR within coyote time, AND jump buffered
	var can_jump = (is_on_floor() or coyote_timer > 0) and jump_buffer_timer > 0
	
	if can_jump:
		perform_jump()
		coyote_timer = 0  # Consume coyote time
		jump_buffer_timer = 0  # Consume buffer
	
	if jump_released and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func perform_jump() -> void:
	var speed_ratio = abs(velocity.x) / run_speed
	var momentum_bonus = speed_ratio * momentum_jump_bonus * base_jump_force
	var total_jump_force = min(base_jump_force + momentum_bonus, max_jump_force)
	total_jump_force *= combo_jump_multiplier
	total_jump_force *= power_up_jump_multiplier  # Apply mega jump boost
	
	velocity.y = -total_jump_force
	is_jumping = true
	
	# Squash effect on jump (subtle)
	if squash_stretch_enabled:
		if is_mega_jump_active:
			target_scale = Vector2(1.15, 0.85)  # Subtle squash
		else:
			target_scale = Vector2(1.1, 0.9)
	
	if jump_particles:
		jump_particles.emitting = true
	
	GameManager.play_sound("jump")

func handle_wall_bounce() -> void:
	if is_on_wall() and not is_on_floor():
		var collision = get_last_slide_collision()
		if collision:
			var normal = collision.get_normal()
			velocity.x = normal.x * wall_bounce_force
			
			if velocity.y > 0:
				velocity.y += wall_bounce_vertical_boost
			
			# Squash on wall hit (subtle)
			if squash_stretch_enabled:
				target_scale = Vector2(0.9, 1.1)
			
			GameManager.play_sound("wall_bounce")

func on_landed() -> void:
	is_jumping = false
	
	# Squash on landing (subtle)
	if squash_stretch_enabled:
		var impact = min(abs(velocity.y) / 800.0, 0.15)
		target_scale = Vector2(1.0 + impact, 1.0 - impact * 0.5)
	
	# Emit signal for combo system if we went UP
	if global_position.y < last_floor_y - 20:
		floor_landed.emit(global_position.y)
		last_floor_y = global_position.y
	
	# Notify the floor we landed on it
	if current_floor:
		current_floor.on_player_landed(self)
		
		# Check for big jump (jumped more than 10 platforms)
		check_big_jump(current_floor.floor_number)
	
	GameManager.play_sound("land")

func check_big_jump(new_floor_number: int) -> void:
	if last_landing_floor_number > 0 and new_floor_number > last_landing_floor_number:
		var floors_jumped = new_floor_number - last_landing_floor_number
		
		if floors_jumped > BIG_JUMP_THRESHOLD:
			consecutive_big_jumps += 1
			
			# Two big jumps in a row = ROLLER!
			if consecutive_big_jumps >= 2:
				start_roller_effect()
				consecutive_big_jumps = 0  # Reset after triggering
		else:
			consecutive_big_jumps = 0  # Reset if jump wasn't big
	
	last_landing_floor_number = new_floor_number

func start_roller_effect() -> void:
	if is_rolling:
		return
	
	is_rolling = true
	roll_rotation = 0.0
	
	# Spawn burst effect
	spawn_roller_burst()
	
	# Create a tween for the rolling animation (full 360 spin + extra flair)
	var roll_tween = create_tween()
	roll_tween.set_ease(Tween.EASE_IN_OUT)
	roll_tween.set_trans(Tween.TRANS_SINE)
	
	# Spin 720 degrees (2 full rotations) - slower so player can see it
	roll_tween.tween_property(self, "roll_rotation", TAU * 2.0, 1.5)
	roll_tween.tween_callback(func(): 
		is_rolling = false
		roll_rotation = 0.0
	)
	
	# Add a scale pulse for extra juice - also slower
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "target_scale", Vector2(1.3, 0.7), 0.2)
	scale_tween.tween_property(self, "target_scale", Vector2(0.8, 1.2), 0.3)
	scale_tween.tween_property(self, "target_scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_ELASTIC)
	
	# Spawn trail particles during roll
	spawn_roller_trails()
	
	# Play a sound if available
	GameManager.play_sound("jump")

func spawn_roller_burst() -> void:
	# Create expanding ring effect
	var ring = create_burst_ring()
	get_parent().add_child(ring)
	ring.global_position = global_position
	
	# Create radial particle burst
	var num_particles = 12
	for i in range(num_particles):
		var angle = (TAU / num_particles) * i
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = Color(1.0, 0.85, 0.3, 0.9)  # Golden color
		particle.position = global_position - Vector2(4, 4)
		particle.pivot_offset = Vector2(4, 4)
		particle.rotation = angle
		get_parent().add_child(particle)
		
		# Animate outward
		var direction = Vector2(cos(angle), sin(angle))
		var end_pos = particle.position + direction * 80
		
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", end_pos, 0.4).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.4)
		tween.chain().tween_callback(particle.queue_free)

func create_burst_ring() -> Node2D:
	# Create a ring that expands outward
	var ring_container = Node2D.new()
	
	# Multiple ring segments for a dashed ring look
	var segments = 16
	for i in range(segments):
		var angle = (TAU / segments) * i
		var segment = ColorRect.new()
		segment.size = Vector2(12, 4)
		segment.color = Color(1.0, 0.9, 0.4, 0.8)
		segment.pivot_offset = Vector2(6, 2)
		segment.rotation = angle
		segment.position = Vector2(cos(angle), sin(angle)) * 20 - Vector2(6, 2)
		ring_container.add_child(segment)
	
	# Animate the ring expanding and fading
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring_container, "scale", Vector2(4, 4), 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_container, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(ring_container.queue_free)
	
	return ring_container

func spawn_roller_trails() -> void:
	# Spawn sparkle trails during the roll
	var trail_count = 8
	for i in range(trail_count):
		# Delay each trail spawn
		get_tree().create_timer(i * 0.15).timeout.connect(func():
			if is_rolling:
				spawn_single_roller_trail()
		)

func spawn_single_roller_trail() -> void:
	# Spawn a few sparkles around the player
	for j in range(3):
		var sparkle = ColorRect.new()
		sparkle.size = Vector2(6, 6)
		
		# Alternate colors for variety
		var colors = [
			Color(1.0, 0.85, 0.3, 0.8),   # Gold
			Color(1.0, 0.95, 0.6, 0.8),   # Light gold
			Color(1.0, 0.7, 0.2, 0.8)     # Orange gold
		]
		sparkle.color = colors[j % colors.size()]
		
		# Random offset around player
		var offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		sparkle.position = global_position + offset - Vector2(3, 3)
		sparkle.pivot_offset = Vector2(3, 3)
		
		get_parent().add_child(sparkle)
		
		# Animate upward and fade
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(sparkle, "position:y", sparkle.position.y - 40, 0.5)
		tween.tween_property(sparkle, "modulate:a", 0.0, 0.5)
		tween.tween_property(sparkle, "rotation", randf_range(-PI, PI), 0.5)
		tween.chain().tween_callback(sparkle.queue_free)

func detect_current_floor() -> void:
	if not is_on_floor():
		if current_floor:
			current_floor.on_player_left()
			current_floor = null
		is_on_ice = false
		return
	
	var found_floor: Floor = null
	
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is Floor:
			found_floor = collider
			break
	
	if found_floor != current_floor:
		if current_floor:
			current_floor.on_player_left()
		current_floor = found_floor
	
	is_on_ice = current_floor != null and current_floor.is_ice_platform()

func update_sprite_direction() -> void:
	if velocity.x > 10:
		sprite.flip_h = false
	elif velocity.x < -10:
		sprite.flip_h = true

func update_animation() -> void:
	if not sprite:
		return
	
	var new_anim: String = "idle"
	
	if not is_on_floor():
		# In the air - use jump animation
		new_anim = "jump"
	elif abs(velocity.x) > 50:
		# Moving on ground - use run animation
		new_anim = "run"
	else:
		# Standing still - use idle animation
		new_anim = "idle"
	
	# Only change animation if different
	if new_anim != current_anim:
		current_anim = new_anim
		sprite.play(new_anim)

func update_visual_effects(delta: float) -> void:
	# Smooth squash/stretch
	current_visual_scale = current_visual_scale.lerp(target_scale, delta * 15.0)
	target_scale = target_scale.lerp(Vector2.ONE, delta * 8.0)
	
	if sprite:
		# Apply squash/stretch on top of base scale
		sprite.scale = Vector2(0.5, 0.5) * current_visual_scale
		
		# Apply roller rotation
		if is_rolling:
			sprite.rotation = roll_rotation
		else:
			sprite.rotation = 0.0
		
		# Visual effects based on state
		if is_mega_jump_active:
			# Green glow for mega jump
			var glow = (sin(Time.get_ticks_msec() * 0.015) + 1) * 0.2 + 0.1
			sprite.modulate = Color(0.7 + glow, 1.0 + glow, 0.7, 1.0)
		elif has_shield:
			# Blue shimmer for shield
			var shimmer = (sin(Time.get_ticks_msec() * 0.008) + 1) * 0.15
			sprite.modulate = Color(0.8 + shimmer, 0.9 + shimmer, 1.0 + shimmer, 1.0)
		elif is_combo_active:
			# Golden glow for combo
			var glow = (sin(Time.get_ticks_msec() * 0.01) + 1) * 0.15 + 0.1
			sprite.modulate = Color(1.0 + glow, 1.0 + glow * 0.5, 0.8, 1.0)
		elif is_on_ice:
			sprite.modulate = Color(0.85, 0.92, 1.0)
		else:
			sprite.modulate = Color(1, 1, 1)
	
	# Trail effect when moving fast
	if trail_enabled and abs(velocity.x) > 200:
		trail_timer -= delta
		if trail_timer <= 0:
			spawn_trail()
			trail_timer = trail_spawn_rate

func spawn_trail() -> void:
	var trail = ColorRect.new()
	trail.size = Vector2(20, 30)
	trail.position = global_position - Vector2(10, 20)
	
	# Color based on state
	if is_combo_active:
		trail.color = Color(1, 0.8, 0.3, 0.4)
	else:
		trail.color = Color(0.4, 0.6, 1.0, 0.3)
	
	get_parent().add_child(trail)
	
	# Fade out
	var tween = get_tree().create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.2)
	tween.tween_callback(trail.queue_free)

func die() -> void:
	player_died.emit()
	GameManager.play_sound("death")
	set_physics_process(false)
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)

func reset(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	last_floor_y = spawn_position.y
	is_jumping = false
	was_on_floor = true
	is_on_ice = false
	is_combo_active = false
	has_shield = false
	is_mega_jump_active = false
	current_floor = null
	combo_jump_multiplier = 1.0
	power_up_jump_multiplier = 1.0
	target_scale = Vector2.ONE
	current_visual_scale = Vector2.ONE
	current_anim = "idle"
	touch_direction = 0.0
	smoothed_touch_direction = 0.0
	touch_jump_pressed = false
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	# Reset big jump roller tracking
	last_landing_floor_number = 0
	consecutive_big_jumps = 0
	is_rolling = false
	roll_rotation = 0.0
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
		sprite.scale = Vector2(0.5, 0.5)
		sprite.rotation = 0.0
		sprite.play("idle")
	set_physics_process(true)

func set_shield_active(active: bool) -> void:
	has_shield = active
	# Visual feedback for shield
	if sprite and active:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.5, 0.8, 1.0), 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.3)

func set_mega_jump_active(active: bool) -> void:
	is_mega_jump_active = active
	power_up_jump_multiplier = 2.5 if active else 1.0
	
	# Visual feedback
	if sprite and active:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.1)
		tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_ELASTIC)

func set_touch_direction(dir: float) -> void:
	touch_direction = dir

func trigger_touch_jump() -> void:
	touch_jump_pressed = true

func set_combo_jump_active(active: bool) -> void:
	combo_jump_multiplier = 2.0 if active else 1.0
	is_combo_active = active
	
	# Visual feedback for combo activation
	if active and sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.1)
		tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_ELASTIC)
