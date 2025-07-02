extends "res://player/input/input_handler.gd"
class_name MobileInput

# Handles complex mobile touch gestures - taps, drags, pinch/spread, multi-finger

# Mobile input settings (copied from camera)
var mobile_sensitivity := 1.0
var mobile_pinch_sensitivity := 10.0
var mobile_drag_threshold := 10.0
var mobile_double_tap_time := 0.3

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

# Internal state for interface
var accumulated_look_delta := Vector2.ZERO
var current_movement := Vector3.ZERO
var current_boost_modifier := 1.0

# Reference to camera
var camera: Camera3D
var fly_speed := 12.0
var boost_multiplier := 5.0

# Signals for actions
signal shoot  # Emitted continuously while shooting gesture is active
signal laser  # Emitted continuously while laser gesture is active  
signal flight_mode_changed(mode: String)

# Note: Mobile input currently uses tap patterns for actions
# For now, emitting single shots on taps - can be enhanced later for continuous

func initialize(camera_ref: Camera3D) -> void:
	camera = camera_ref
	# Copy settings from camera
	mobile_sensitivity = camera.mobile_sensitivity
	mobile_pinch_sensitivity = camera.mobile_pinch_sensitivity
	mobile_drag_threshold = camera.mobile_drag_threshold
	mobile_double_tap_time = camera.mobile_double_tap_time
	fly_speed = camera.fly_speed
	boost_multiplier = camera.boost_multiplier

func handle_input_event(event: InputEvent) -> void:
	_handle_mobile_touch(event)

func _handle_mobile_touch(event: InputEvent) -> void:
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

func process_input(_delta: float) -> void:
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
		_handle_multi_finger_gestures(_delta)
	
	# Emit continuous signals based on current weapon mode
	_emit_continuous_actions()

func _emit_continuous_actions() -> void:
	# Emit continuous signals while gestures are active
	if mobile_weapon_mode == "AUTO_FIRE":
		shoot.emit()
	elif mobile_weapon_mode == "LASER_BEAM":
		laser.emit()
	
	# Update boost modifier based on flight mode
	current_boost_modifier = boost_multiplier if mobile_flight_mode == "BOOST" else 1.0

func _process_pending_taps() -> void:
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

func _check_tap_sequence_timeout() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# If tap sequence has timed out, process single tap
	if mobile_tap_count > 0 and current_time - mobile_tap_count_timer > mobile_tap_sequence_timeout:
		if mobile_tap_count == 1 and mobile_weapon_mode == "NONE":
			# Single tap that timed out - shoot once
			shoot.emit()
		mobile_tap_count = 0

func _process_tap_sequences(finger_id: int) -> void:
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
			shoot.emit()
	elif mobile_tap_count == 2:
		if finger_still_down:
			# Double tap + hold - enter auto-fire
			mobile_weapon_mode = "AUTO_FIRE"
			mobile_weapon_finger = finger_id
			# Note: Continuous shooting will be handled by checking weapon mode
		else:
			# Just double tap without hold - shoot once
			if mobile_weapon_mode == "NONE":
				shoot.emit()
	elif mobile_tap_count >= 3:
		if finger_still_down:
			# Triple tap + hold - enter laser mode
			mobile_weapon_mode = "LASER_BEAM"
			mobile_weapon_finger = finger_id
			# Note: Continuous laser will be handled by checking weapon mode
		else:
			# Just triple tap without hold - shoot once
			if mobile_weapon_mode == "NONE":
				shoot.emit()
	
	# Reset tap count
	mobile_tap_count = 0

func _handle_mobile_tap(finger_id: int, _tap_position: Vector2) -> void:
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
		
		elif touch_count == 2:
			# Two finger tap - check for double tap to enter boost mode
			if current_time - mobile_boost_start_time < mobile_double_tap_time:
				mobile_flight_mode = "BOOST"
				mobile_boost_fingers = mobile_touches.keys()
				flight_mode_changed.emit("BOOST")
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

func _handle_mobile_release(finger_id: int) -> void:
	# If releasing weapon finger, stop weapon mode
	if finger_id == mobile_weapon_finger:
		# Note: Continuous signals will stop automatically when finger is released
		mobile_weapon_mode = "NONE"
		mobile_weapon_finger = -1
	
	# If releasing a boost finger, exit boost mode
	if finger_id in mobile_boost_fingers:
		mobile_boost_fingers.erase(finger_id)
		if mobile_boost_fingers.size() == 0:
			mobile_flight_mode = "NORMAL"
			flight_mode_changed.emit("NORMAL")
	
	# Reset tap hold timer if no fingers are down
	if mobile_touches.size() <= 1:  # Will be 0 after this finger is removed
		mobile_tap_hold_timer = 0.0
		# Process final tap sequence when finger is released
		_process_tap_sequences(finger_id)

func _handle_mobile_drag(finger_id: int, relative: Vector2) -> void:
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

func _handle_multi_finger_gestures(delta: float) -> void:
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
				
				# Forward/backward movement
				var forward_movement = -distance_change * move_speed * delta
				current_movement.z = forward_movement
			
			set_meta("mobile_previous_distance", current_distance)

func _apply_mobile_look(relative: Vector2) -> void:
	# Convert screen drag to camera rotation
	# Drag right = turn right (positive Y rotation)
	# Drag up = look up (positive X rotation) 
	var look_sensitivity = mobile_sensitivity * 0.002
	accumulated_look_delta.x += relative.x * look_sensitivity  # Positive X for right turn
	accumulated_look_delta.y += relative.y * look_sensitivity  # Positive Y for up look

func _apply_mobile_strafe(relative: Vector2, boosted: bool = false) -> void:
	# Convert screen drag to strafe movement
	# Drag right = move right, drag up = move up
	var strafe_speed = fly_speed * mobile_sensitivity * 0.01
	if mobile_flight_mode == "BOOST" or boosted:
		strafe_speed *= boost_multiplier
	
	# Apply strafe movement
	current_movement.x = relative.x * strafe_speed
	current_movement.y = relative.y * strafe_speed

# Interface implementation
func get_movement_vector() -> Vector3:
	return current_movement

func get_look_delta() -> Vector2:
	# Return accumulated look delta and reset for next frame
	var delta = accumulated_look_delta
	accumulated_look_delta = Vector2.ZERO
	return delta

func get_boost_modifier() -> float:
	return current_boost_modifier

# Check if mobile input is currently active
func is_active() -> bool:
	return mobile_touches.size() > 0
