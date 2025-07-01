extends Camera3D

# Input sensitivity settings
@export var mouse_sensitivity := 0.002
@export var controller_sensitivity := 2.0
@export var fly_speed := 12.0
@export var boost_multiplier := 5.0
@export var shoot_cooldown := 0.2
@export var laser_range := 50.0  # Should match visual laser beam length

# Internal state
var spaceship: CharacterBody3D
var last_shot_time := 0
var weapon_light: OmniLight3D

func _ready():
	_setup_spaceship()
	_setup_weapon_light()

func _setup_spaceship():
	# Create spaceship as first-person weapon
	spaceship = CharacterBody3D.new()
	spaceship.collision_layer = 2
	spaceship.collision_mask = 1
	
	# Add visual mesh
	var spaceship_mesh = MeshInstance3D.new()
	var spaceship_script = load("res://player/spaceship.gd")
	spaceship_mesh.set_script(spaceship_script)
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
	_handle_mouse_look(event)
	_handle_fullscreen_toggle(event)

func _handle_mouse_look(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		var x_rotation = -event.relative.y * mouse_sensitivity
		var new_rotation = rotation.x + x_rotation
		new_rotation = clamp(new_rotation, deg_to_rad(-90), deg_to_rad(90))
		rotation.x = new_rotation

func _handle_fullscreen_toggle(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _process(delta):
	_handle_look_input(delta)
	_handle_movement_input(delta)
	_handle_action_input()
	_update_spaceship_position()

func _handle_look_input(delta):
	# Controller look with right stick
	var look_vector = Vector2.ZERO
	look_vector.x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	look_vector.y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	
	if look_vector.length() > 0.1:
		rotate_y(-look_vector.x * controller_sensitivity * delta)
		var x_rotation = -look_vector.y * controller_sensitivity * delta
		var new_rotation = rotation.x + x_rotation
		new_rotation = clamp(new_rotation, deg_to_rad(-90), deg_to_rad(90))
		rotation.x = new_rotation

func _handle_movement_input(delta):
	var input_vector = Vector3.ZERO
	var current_speed = fly_speed
	var movement_multiplier = 1.0  # For analog stick sensitivity
	
	# Handle boost input
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):  # LB for boost
		current_speed *= boost_multiplier
	
	# Keyboard movement
	if Input.is_key_pressed(KEY_W):
		input_vector += -transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_vector += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_vector += -transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_vector += transform.basis.x
	if Input.is_key_pressed(KEY_E):
		input_vector += transform.basis.y
	if Input.is_key_pressed(KEY_Q):
		input_vector += -transform.basis.y
	
	# Controller movement (left stick)
	var move_stick = Vector2.ZERO
	move_stick.x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	move_stick.y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	
	if move_stick.length() > 0.1:
		movement_multiplier = move_stick.length()  # Store analog sensitivity
		var stick_direction = move_stick.normalized()
		# Forward/backward from Y axis (swapped: negative Y = forward)
		input_vector += transform.basis.z * stick_direction.y
		# Left/right from X axis  
		input_vector += transform.basis.x * stick_direction.x
	
	# Apply horizontal movement with analog sensitivity
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		global_position += input_vector * current_speed * movement_multiplier * delta
	
	# Controller vertical movement (triggers) - applied separately to preserve analog
	if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.1:  # RT - Up
		var trigger_amount = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
		global_position += transform.basis.y * current_speed * trigger_amount * delta
	if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.1:   # LT - Down
		var trigger_amount = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
		global_position += -transform.basis.y * current_speed * trigger_amount * delta

func _handle_action_input():
	# Shooting (A or RB)
	var should_shoot = false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		should_shoot = true
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A):  # A button
		should_shoot = true
	if Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):  # RB button
		should_shoot = true
	
	if should_shoot and Time.get_ticks_msec() - last_shot_time > shoot_cooldown * 1000:
		shoot_projectile()
		last_shot_time = Time.get_ticks_msec()
	
	# Laser (just B button)
	var laser_active = false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		laser_active = true
	if Input.is_joy_button_pressed(0, JOY_BUTTON_B):  # B button for laser
		laser_active = true
	
	_handle_laser(laser_active)

func _handle_laser(active: bool):
	var spaceship_mesh = spaceship.get_child(0)
	var laser_beam = spaceship_mesh.get_meta("laser_beam", null)
	
	if laser_beam:
		laser_beam.visible = active
	
	if active:
		use_attraction_laser()

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
	var laser_beam = spaceship_mesh.get_meta("laser_beam", null)
	if not laser_beam:
		return
	
	var space_state = get_world_3d().direct_space_state
	var beam_start = laser_beam.global_position
	var beam_direction = -laser_beam.global_transform.basis.z
	var beam_end = beam_start + beam_direction * laser_range  # Use laser_range variable
	
	var query = PhysicsRayQueryParameters3D.create(beam_start, beam_end)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if result and result.collider.is_in_group("nodes"):
		result.collider.call("apply_laser_attraction", beam_start)
