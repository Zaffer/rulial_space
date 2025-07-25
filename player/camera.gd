extends Camera3D

# First-person camera controller with unified input system
# 
# All input handling in modular handler classes:
# - KeyboardMouseInput: WASD movement, mouse look, mouse buttons
# - ControllerInput: Analog sticks, triggers, controller buttons  
# - MobileInput: Touch gestures, taps, drags, pinch/spread
#
# InputManager coordinates all input handlers and provides a unified interface
# through signals and polling methods. Camera now focuses purely on movement,
# weapon management, and rendering logic.

# Input sensitivity settings
@export var mouse_sensitivity := 0.002
@export var controller_sensitivity := 2.0
@export var fly_speed := 12.0
@export var boost_multiplier := 5.0
@export var shoot_cooldown := 0.2
@export var laser_range := 50.0

# Mobile input settings (used by MobileInput handler)
@export var mobile_sensitivity := 1.0
@export var mobile_pinch_sensitivity := 10.0
@export var mobile_drag_threshold := 10.0
@export var mobile_double_tap_time := 0.3

# Internal state
var spaceship: CharacterBody3D
var last_shot_time := 0
var weapon_light: OmniLight3D
var is_laser_active := false

func _ready():
	_setup_spaceship()
	_setup_weapon_light()
	_initialize_input_manager()

func _setup_spaceship():
	# Create spaceship as first-person weapon
	spaceship = CharacterBody3D.new()
	spaceship.collision_layer = 2
	spaceship.collision_mask = 1
	
	# Load the spaceship scene
	var spaceship_scene = preload("res://player/spaceship.tscn")
	var spaceship_mesh = spaceship_scene.instantiate()
	spaceship.add_child(spaceship_mesh)
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.8
	collision.shape = shape
	spaceship.add_child(collision)
	
	add_child(spaceship)
	spaceship.scale = Vector3(0.3, 0.3, 0.3)

func _setup_weapon_light():
	# Add lighting for the weapon
	weapon_light = OmniLight3D.new()
	weapon_light.light_energy = 0.8
	weapon_light.light_color = Color.CYAN
	weapon_light.omni_range = 5.0
	weapon_light.position = Vector3(0.5, -0.3, -1.0)
	add_child(weapon_light)

func _input(event):
	# InputManager handles most input now
	if input_manager:
		input_manager.handle_input_event(event)
	
	# Keep fullscreen toggle (not input-type specific)
	_handle_fullscreen_toggle(event)

func _handle_fullscreen_toggle(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _process(delta):
	# Use InputManager for all input
	if input_manager:
		input_manager.process_input(delta)
		
		# Get unified input from InputManager
		var movement_vector = input_manager.get_movement_vector()
		var look_delta = input_manager.get_look_delta()
		var roll_delta = input_manager.get_roll_delta()
		var boost_modifier = input_manager.get_boost_modifier()
		
		# Check actions using new direct method approach
		if input_manager.is_shooting():
			_on_shoot()
		
		# Check laser state
		is_laser_active = input_manager.is_using_laser()
		
		# Apply movement and look
		_apply_movement_from_input_manager(movement_vector, boost_modifier, delta)
		_apply_look_from_input_manager(look_delta, roll_delta)
	
	# Handle laser (will be active if detected this frame)
	_handle_laser(is_laser_active)
	
	_update_spaceship_position()

func _apply_movement_from_input_manager(movement_vector: Vector3, boost_modifier: float, delta: float):
	# Apply movement from InputManager (replaces _handle_movement_input)
	if movement_vector.length() > 0:
		var current_speed = fly_speed * boost_modifier
		# Convert local movement vector to world space using camera's transform
		var world_movement = transform.basis * movement_vector
		global_position += world_movement * current_speed * delta

func _apply_look_from_input_manager(look_delta: Vector2, roll_delta: float):
	# Apply look input from InputManager with roll support
	if look_delta.length() > 0 or roll_delta != 0:
		# Apply yaw and pitch
		rotate_y(look_delta.x)
		var x_rotation = look_delta.y
		var new_rotation = rotation.x + x_rotation
		new_rotation = clamp(new_rotation, deg_to_rad(-90), deg_to_rad(90))
		rotation.x = new_rotation
		
		# Apply roll
		rotation.z += roll_delta

func _update_spaceship_position():
	var desired_position = global_position + transform.basis * Vector3(0.8, -0.5, -1.0)
	spaceship.global_position = desired_position
	spaceship.global_rotation = global_rotation

func shoot_projectile():
	var projectile = RigidBody3D.new()
	var projectile_script = load("res://player/projectile.gd")
	projectile.set_script(projectile_script)
	
	get_tree().current_scene.add_child(projectile)
	
	var spaceship_mesh = spaceship.get_child(0)
	var gun_barrel_pos = spaceship_mesh.call("get_gun_barrel_position")
	
	projectile.global_position = gun_barrel_pos
	spaceship_mesh.call("gun_kickback")
	
	var shoot_direction = -transform.basis.z
	projectile.call("launch", shoot_direction)

func use_attraction_laser():
	var spaceship_mesh = spaceship.get_child(0)
	var laser_beam = spaceship_mesh.get_node("LaserBeam")
	if not laser_beam:
		return
	
	var space_state = get_world_3d().direct_space_state
	
	# Use gun barrel position as the start point and camera's forward direction
	var beam_start = spaceship_mesh.call("get_gun_barrel_position")
	var beam_direction = -transform.basis.z
	var beam_end = beam_start + beam_direction * laser_range
	
	var query = PhysicsRayQueryParameters3D.create(beam_start, beam_end)
	query.collision_mask = 1  # Only nodes
	
	var result = space_state.intersect_ray(query)
	if result and result.collider.is_in_group("nodes"):
		result.collider.call("apply_laser_attraction", beam_start)
		
		# Trigger flash effect on hit node
		if result.collider.has_method("flash_hit"):
			result.collider.flash_hit()
		
		# Apply rewrite rule to the hit node
		var main_scene = get_tree().current_scene
		if main_scene.has_method("apply_rewrite_to_node"):
			main_scene.apply_rewrite_to_node(result.collider)

func _handle_laser(active: bool):
	var spaceship_mesh = spaceship.get_child(0)
	var laser_beam = spaceship_mesh.get_node("LaserBeam")
	
	if laser_beam:
		laser_beam.visible = active
	
	if active:
		use_attraction_laser()

# InputManager Integration
var input_manager

func _initialize_input_manager():
	# Initialize the new input system
	var InputManagerClass = preload("res://player/input/input_manager.gd")
	input_manager = InputManagerClass.new()
	input_manager.initialize(self)

# Input action handlers
func _on_shoot():
	if Time.get_ticks_msec() - last_shot_time > shoot_cooldown * 1000:
		shoot_projectile()
		last_shot_time = Time.get_ticks_msec()

func _on_laser():
	is_laser_active = true

func _on_flight_mode_changed(_mode: String):
	# Handle flight mode changes (if needed)
	pass
