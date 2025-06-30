extends Camera3D

@export var mouse_sensitivity := 0.002
@export var fly_speed := 12.0
@export var boost_multiplier := 5.0
@export var shoot_cooldown := 0.2

var spaceship: CharacterBody3D
var last_shot_time := 0
var weapon_light: OmniLight3D

func _ready():
	# DISABLED - Let main.gd handle mouse capture
	# Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Control pause behavior when window loses focus
	get_tree().set_auto_accept_quit(false)  # Handle quit manually if needed
	# You can control pause on focus loss with:
	# get_tree().paused = false  # Ensure game doesn't pause on focus loss
	
	# Create the spaceship as a character body (controlled movement but can collide)
	spaceship = CharacterBody3D.new()
	
	# Set collision layers to avoid projectile interactions
	spaceship.collision_layer = 2  # Layer 2 for spaceship
	spaceship.collision_mask = 1   # Only collide with layer 1 (nodes)
	
	# Add the visual mesh
	var spaceship_mesh = MeshInstance3D.new()
	var spaceship_script = load("res://spaceship.gd")
	spaceship_mesh.set_script(spaceship_script)
	spaceship.add_child(spaceship_mesh)
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.8  # Adjust size as needed
	collision.shape = shape
	spaceship.add_child(collision)
	
	add_child(spaceship)
	
	# Position and scale will be set dynamically in _process()
	spaceship.scale = Vector3(0.3, 0.3, 0.3)  # Slightly bigger for weapon view
	spaceship.rotation_degrees = Vector3(0, 0, 0)  # Angled more towards center
	
	# Create ambient floating particles for reference
	# Note: Particles are now handled by the main scene's AmbientParticles node
	# ambient_particles = GPUParticles3D.new()
	# var particles_script = load("res://ambient_particles.gd")
	# ambient_particles.set_script(particles_script)
	# ambient_particles.position = global_position
	# get_parent().add_child.call_deferred(ambient_particles)
	
	# Add lighting for the weapon
	weapon_light = OmniLight3D.new()
	weapon_light.light_energy = 0.8
	weapon_light.light_color = Color.CYAN
	weapon_light.omni_range = 5.0
	weapon_light.position = Vector3(0.5, -0.3, -1.0)  # Near the weapon
	add_child(weapon_light)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Mouse look - only when mouse is captured
		rotate_y(-event.relative.x * mouse_sensitivity)
		var x_rotation = -event.relative.y * mouse_sensitivity
		var new_rotation = rotation.x + x_rotation
		# Clamp vertical rotation to prevent flipping
		new_rotation = clamp(new_rotation, deg_to_rad(-90), deg_to_rad(90))
		rotation.x = new_rotation
	
	# DISABLED - Let main.gd handle ESC key and mouse capture
	# if event.is_action_pressed("ui_cancel"):
	# 	# Toggle mouse capture with ESC
	# 	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
	# 		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# 	else:
	# 		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Toggle fullscreen with F11
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _process(delta):
	var input_vector = Vector3.ZERO
	var current_speed = fly_speed

	# Boost speed with Shift
	if Input.is_key_pressed(KEY_SHIFT):  # Shift key
		current_speed *= boost_multiplier

	# Movement input (WASD keys for camera orientation)
	if Input.is_key_pressed(KEY_W):          # W - Forward
		input_vector += -transform.basis.z
	if Input.is_key_pressed(KEY_S):          # S - Backward
		input_vector += transform.basis.z
	if Input.is_key_pressed(KEY_A):          # A - Left
		input_vector += -transform.basis.x
	if Input.is_key_pressed(KEY_D):          # D - Right
		input_vector += transform.basis.x

	# Vertical movement (Q/E)
	if Input.is_key_pressed(KEY_E):           # E - Up
		input_vector += transform.basis.y
	if Input.is_key_pressed(KEY_Q):           # Q - Down
		input_vector += -transform.basis.y

	# Shooting with Left Mouse Click
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Time.get_ticks_msec() - last_shot_time > shoot_cooldown * 1000:
		shoot_projectile()
		last_shot_time = Time.get_ticks_msec()
	
	# Attraction laser with Right Mouse Click
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# Get spaceship laser beam and show it
		var spaceship_mesh = spaceship.get_child(0)
		var laser_beam = spaceship_mesh.get_meta("laser_beam", null)
		if laser_beam:
			laser_beam.visible = true
		use_attraction_laser()
	else:
		# Hide laser beam
		var spaceship_mesh = spaceship.get_child(0)
		var laser_beam = spaceship_mesh.get_meta("laser_beam", null)
		if laser_beam:
			laser_beam.visible = false

	# Apply movement in world space
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		global_position += input_vector * current_speed * delta
	
	# Keep spaceship in fixed position relative to camera (like FPS weapon)
	var desired_spaceship_position = global_position + transform.basis * Vector3(0.8, -0.5, -1.0)
	spaceship.global_position = desired_spaceship_position
	spaceship.global_rotation = global_rotation
	
	# Only call move_and_slide when we actually need collision detection
	# For now, let's disable it since the spaceship should stay fixed to camera
	# spaceship.move_and_slide()

func shoot_projectile():
	# Create projectile
	var projectile = RigidBody3D.new()
	var projectile_script = load("res://projectile.gd")
	projectile.set_script(projectile_script)
	
	# Add to the main scene (get the root node)
	get_tree().current_scene.add_child(projectile)
	
	# Get gun barrel position from spaceship
	var spaceship_mesh = spaceship.get_child(0)  # First child is the mesh with script
	var gun_barrel_pos = spaceship_mesh.call("get_gun_barrel_position")
	
	# Position projectile directly at gun barrel (no offset)
	projectile.global_position = gun_barrel_pos
	
	# Trigger gun kickback animation
	spaceship_mesh.call("gun_kickback")
	
	# Launch projectile in the direction the camera is facing
	var shoot_direction = -transform.basis.z  # Forward direction
	projectile.call("launch", shoot_direction)

func _notification(what):
	# DISABLED - Let main.gd handle focus and mouse capture
	# match what:
	# 	NOTIFICATION_WM_WINDOW_FOCUS_IN:
	# 		# Window gained focus - unpause and capture mouse
	# 		get_tree().paused = false
	# 		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
	# 			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# 	NOTIFICATION_WM_WINDOW_FOCUS_OUT:
	# 		# Window lost focus - pause and release mouse
	# 		get_tree().paused = true
	# 		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	pass

func use_attraction_laser():
	# Get the spaceship's laser beam position to raycast from there
	var spaceship_mesh = spaceship.get_child(0)
	var laser_beam = spaceship_mesh.get_meta("laser_beam", null)
	if not laser_beam:
		return
	
	# Raycast from the laser beam's position in the direction it's pointing
	var space_state = get_world_3d().direct_space_state
	var beam_start = laser_beam.global_position
	var beam_direction = -laser_beam.global_transform.basis.z  # Forward direction of the beam
	var beam_end = beam_start + beam_direction * 10.0  # Match the 10-unit beam length
	
	var query = PhysicsRayQueryParameters3D.create(beam_start, beam_end)
	query.collision_mask = 1  # Only hit nodes
	
	var result = space_state.intersect_ray(query)
	if result and result.collider.is_in_group("nodes"):
		result.collider.call("apply_laser_attraction", beam_start)
		print("Laser hitting node!")
