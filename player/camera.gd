extends Camera3D

# Input sensitivity settings
@export var mouse_sensitivity := 0.002
@export var controller_sensitivity := 2.0
@export var fly_speed := 12.0
@export var boost_multiplier := 5.0
@export var shoot_cooldown := 0.2
@export var laser_range := 50.0  # Should match visual laser beam length

# Mobile input settings
@export var mobile_sensitivity := 1.0
@export var mobile_pinch_sensitivity := 10.0
@export var mobile_drag_threshold := 10.0
@export var mobile_double_tap_time := 0.3

# Internal state
var spaceship: CharacterBody3D
var last_shot_time := 0
var weapon_light: OmniLight3D

# Mobile input state
var mobile_touches := {}
var mobile_flight_mode := "NORMAL"  # "NORMAL" or "BOOST"
var mobile_weapon_mode := "NONE"   # "NONE", "AUTO_FIRE", "LASER_BEAM"
var mobile_last_tap_time := 0.0
var mobile_boost_start_time := 0.0
var mobile_weapon_finger := -1
var mobile_tap_hold_timer := 0.0
var mobile_tap_hold_threshold := 0.3  # Time to hold after taps
var mobile_boost_fingers := []  # Track fingers used for boost mode entry
var mobile_gesture_delay := 0.1  # Delay before processing single finger gestures
var mobile_pending_taps := {}  # Store taps that might become multi-finger gestures
var mobile_tap_count := 0  # Count consecutive taps
var mobile_tap_count_timer := 0.0  # Timer for tap sequence
var mobile_tap_sequence_timeout := 0.5  # Max time between taps in sequence

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
	_handle_mobile_touch(event)

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

func _handle_mobile_touch(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			mobile_touches[event.index] = {
				"position": event.position,
				"start_time": Time.get_ticks_msec() / 1000.0,
				"last_position": event.position,
				"tap_count": 1
			}
			
			# If this is the first finger, delay processing
			if mobile_touches.size() == 1:
				mobile_pending_taps[event.index] = {
					"position": event.position,
					"time": Time.get_ticks_msec() / 1000.0
				}
			else:
				# Multiple fingers - process multi-finger tap immediately
				# Clear any pending single taps
				mobile_pending_taps.clear()
				_handle_mobile_tap(event.index, event.position)
		else:
			if event.index in mobile_touches:
				_handle_mobile_release(event.index)
				mobile_touches.erase(event.index)
			# Remove from pending taps
			if event.index in mobile_pending_taps:
				mobile_pending_taps.erase(event.index)
	
	elif event is InputEventScreenDrag:
		if event.index in mobile_touches:
			mobile_touches[event.index]["last_position"] = event.position
			# Only process drag if not in pending state or if multiple fingers
			if event.index not in mobile_pending_taps or mobile_touches.size() > 1:
				_handle_mobile_drag(event.index, event.relative)

func _process(delta):
	_handle_look_input(delta)
	_handle_movement_input(delta)
	_handle_action_input()
	_handle_mobile_input(delta)
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
	# Shooting (A or RB or mobile)
	var should_shoot = false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		should_shoot = true
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A):  # A button
		should_shoot = true
	if Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):  # RB button
		should_shoot = true
	if mobile_weapon_mode == "AUTO_FIRE":  # Mobile auto-fire
		should_shoot = true
	
	if should_shoot and Time.get_ticks_msec() - last_shot_time > shoot_cooldown * 1000:
		shoot_projectile()
		last_shot_time = Time.get_ticks_msec()
	
	# Laser (just B button or mobile)
	var laser_active = false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		laser_active = true
	if Input.is_joy_button_pressed(0, JOY_BUTTON_B):  # B button for laser
		laser_active = true
	if mobile_weapon_mode == "LASER_BEAM":  # Mobile laser
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

func _process_pending_taps():
	var current_time = Time.get_ticks_msec() / 1000.0
	var taps_to_process = []
	
	# Check which pending taps should be processed
	for finger_id in mobile_pending_taps.keys():
		var tap_data = mobile_pending_taps[finger_id]
		var tap_age = current_time - tap_data["time"]
		
		# If tap is old enough and still only one finger, process it
		if tap_age >= mobile_gesture_delay and mobile_touches.size() == 1:
			taps_to_process.append(finger_id)
	
	# Process the taps
	for finger_id in taps_to_process:
		var tap_data = mobile_pending_taps[finger_id]
		_handle_mobile_tap(finger_id, tap_data["position"])
		mobile_pending_taps.erase(finger_id)

func _check_tap_sequence_timeout():
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# If tap sequence has timed out, process single tap
	if mobile_tap_count > 0 and current_time - mobile_tap_count_timer > mobile_tap_sequence_timeout:
		if mobile_tap_count == 1 and mobile_weapon_mode == "NONE":
			# Single tap that timed out - shoot once
			shoot_projectile()
		mobile_tap_count = 0

# Mobile Input Functions
func _handle_mobile_input(delta):
	# Process mobile gestures and convert to movement/look/actions
	var touch_count = mobile_touches.size()
	
	if touch_count == 0:
		return
	
	# Process pending taps after delay
	_process_pending_taps()
	
	# Check for tap sequence timeouts
	_check_tap_sequence_timeout()
	
	# Handle multi-finger gestures
	if touch_count >= 2:
		_handle_multi_finger_gestures(delta)

func _handle_mobile_tap(finger_id: int, _tap_position: Vector2):
	var current_time = Time.get_ticks_msec() / 1000.0
	var touch_count = mobile_touches.size()
	
	# In NORMAL mode
	if mobile_flight_mode == "NORMAL":
		if touch_count == 1:
			# Handle tap counting for single finger
			if current_time - mobile_tap_count_timer < mobile_tap_sequence_timeout:
				mobile_tap_count += 1
			else:
				mobile_tap_count = 1
			mobile_tap_count_timer = current_time
			
			# Process based on tap count
			if mobile_tap_count == 1:
				# Single tap - shoot once (process after timeout to check for more taps)
				pass  # Will be handled in _process_tap_sequences()
			elif mobile_tap_count == 2:
				# Double tap - prepare for potential auto-fire
				pass  # Will be handled in _process_tap_sequences()
			elif mobile_tap_count >= 3:
				# Triple tap - prepare for potential laser
				pass  # Will be handled in _process_tap_sequences()
		
		elif touch_count == 2:
			# Two finger tap - check for double tap to enter boost mode
			if current_time - mobile_boost_start_time < mobile_double_tap_time:
				mobile_flight_mode = "BOOST"
				mobile_boost_fingers = mobile_touches.keys()
			mobile_boost_start_time = current_time
	
	# In BOOST mode
	elif mobile_flight_mode == "BOOST":
		# 3rd finger actions (when 2 boost fingers + 1 more)
		if touch_count == 3 and finger_id not in mobile_boost_fingers:
			# Handle tap counting for 3rd finger
			if current_time - mobile_tap_count_timer < mobile_tap_sequence_timeout:
				mobile_tap_count += 1
			else:
				mobile_tap_count = 1
			mobile_tap_count_timer = current_time

func _handle_mobile_release(finger_id: int):
	# If releasing weapon finger, stop weapon mode
	if finger_id == mobile_weapon_finger:
		mobile_weapon_mode = "NONE"
		mobile_weapon_finger = -1
	
	# If releasing a boost finger, exit boost mode
	if finger_id in mobile_boost_fingers:
		mobile_boost_fingers.erase(finger_id)
		if mobile_boost_fingers.size() == 0:
			mobile_flight_mode = "NORMAL"
	
	# Reset tap hold timer if no fingers are down
	if mobile_touches.size() <= 1:  # Will be 0 after this finger is removed
		mobile_tap_hold_timer = 0.0
		# Process final tap sequence when finger is released
		_process_tap_sequences(finger_id)

func _handle_mobile_drag(finger_id: int, relative: Vector2):
	var touch_count = mobile_touches.size()
	
	# In NORMAL mode
	if mobile_flight_mode == "NORMAL":
		if touch_count == 1:
			# Single finger drag - look around (always, even during weapon modes)
			_apply_mobile_look(relative)
		elif touch_count == 2:
			# Two finger drag - strafe movement
			_apply_mobile_strafe(relative)
	
	# In BOOST mode
	elif mobile_flight_mode == "BOOST":
		if touch_count == 2:
			# Two finger drag - boosted strafe movement
			_apply_mobile_strafe(relative, true)  # Pass boost flag
		elif touch_count == 3:
			# 3rd finger drag - look around
			if finger_id not in mobile_boost_fingers:
				_apply_mobile_look(relative)

func _handle_multi_finger_gestures(delta):
	var touch_count = mobile_touches.size()
	
	if touch_count >= 2:
		# Calculate pinch/spread for forward/backward movement
		var touch_positions = []
		for touch_data in mobile_touches.values():
			touch_positions.append(touch_data["position"])
		
		if touch_positions.size() >= 2:
			var current_distance = touch_positions[0].distance_to(touch_positions[1])
			
			# Store previous distance in meta for comparison
			var previous_distance = get_meta("mobile_previous_distance", current_distance)
			var distance_change = current_distance - previous_distance
			
			# Apply forward/backward movement based on pinch/spread
			if abs(distance_change) > mobile_pinch_sensitivity:
				var move_speed = fly_speed * mobile_sensitivity * 0.01
				if mobile_flight_mode == "BOOST":
					move_speed *= boost_multiplier
				
				var movement_direction = transform.basis.z * -distance_change * move_speed * delta
				global_position += movement_direction
			
			set_meta("mobile_previous_distance", current_distance)

func _apply_mobile_look(relative: Vector2):
	# Convert screen drag to camera rotation
	# Drag right = turn right (positive Y rotation)
	# Drag up = look up (positive X rotation) 
	var look_sensitivity = mobile_sensitivity * 0.002
	rotate_y(relative.x * look_sensitivity)  # Positive X for right turn
	var x_rotation = relative.y * look_sensitivity  # Positive Y for up look
	var new_rotation = rotation.x + x_rotation
	new_rotation = clamp(new_rotation, deg_to_rad(-90), deg_to_rad(90))
	rotation.x = new_rotation

func _apply_mobile_strafe(relative: Vector2, boosted: bool = false):
	# Convert screen drag to strafe movement
	# Drag right = move right, drag up = move up
	var strafe_speed = fly_speed * mobile_sensitivity * 0.01
	if mobile_flight_mode == "BOOST" or boosted:
		strafe_speed *= boost_multiplier
	
	var movement = Vector3()
	movement += transform.basis.x * relative.x * strafe_speed  # Right/left
	movement += transform.basis.y * relative.y * strafe_speed  # Up/down (positive Y for up)
	
	global_position += movement * get_process_delta_time()

func _process_tap_sequences(finger_id: int):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Only process if this was a recent tap sequence
	if current_time - mobile_tap_count_timer > mobile_tap_sequence_timeout:
		mobile_tap_count = 0
		return
	
	# Check if finger is being held down for mode activation
	var finger_still_down = finger_id in mobile_touches
	
	if mobile_tap_count == 1:
		# Single tap - shoot once
		if mobile_weapon_mode == "NONE":
			shoot_projectile()
	elif mobile_tap_count == 2:
		if finger_still_down:
			# Double tap + hold - enter auto-fire
			mobile_weapon_mode = "AUTO_FIRE"
			mobile_weapon_finger = finger_id
		else:
			# Just double tap without hold - shoot once
			if mobile_weapon_mode == "NONE":
				shoot_projectile()
	elif mobile_tap_count >= 3:
		if finger_still_down:
			# Triple tap + hold - enter laser mode
			mobile_weapon_mode = "LASER_BEAM"
			mobile_weapon_finger = finger_id
		else:
			# Just triple tap without hold - shoot once
			if mobile_weapon_mode == "NONE":
				shoot_projectile()
	
	# Reset tap count
	mobile_tap_count = 0
