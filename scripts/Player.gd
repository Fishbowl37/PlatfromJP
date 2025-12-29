extends CharacterBody2D
class_name Player

signal floor_landed(floor_y: float)
signal player_died
signal power_up_collected(power_up: PowerUp)

# Movement parameters
@export_group("Movement")
@export var run_speed: float = 350.0
@export var acceleration: float = 2000.0
@export var friction: float = 1500.0
@export var air_friction: float = 200.0

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
	handle_jump()
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
	
	if abs(direction) > 0.005:
		# Analog input: direction value scales the target speed
		var target_velocity = direction * run_speed
		
		# Very fast acceleration for instant mobile response
		var mobile_acceleration = current_acceleration * 2.5
		velocity.x = move_toward(velocity.x, target_velocity, mobile_acceleration * delta)
	else:
		# Smooth deceleration
		var active_friction = current_friction_value if is_on_floor() else air_friction
		velocity.x = move_toward(velocity.x, 0, active_friction * delta)

func get_input_direction() -> float:
	var keyboard_dir = Input.get_axis("move_left", "move_right")
	if keyboard_dir != 0:
		return keyboard_dir
	# Return smoothed analog touch direction for better mobile feel
	return smoothed_touch_direction

func handle_jump() -> void:
	var jump_pressed = Input.is_action_just_pressed("jump") or touch_jump_pressed
	var jump_released = Input.is_action_just_released("jump")
	
	if jump_pressed:
		touch_jump_pressed = false
		if is_on_floor():
			perform_jump()
	
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
	
	GameManager.play_sound("land")

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
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
		sprite.scale = Vector2(0.5, 0.5)
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
