extends "res://player/input/input_handler.gd"
class_name MobileInput

# Handles mobile touch gestures: tap/drag for shooting and looking, pinch for movement, two-finger strafe
# TODO: major issue with shooting/clicking/tapping and some error on chrome: 'Uncaught (in promise)
# TODO: make it relative to current position
# TODO: make gyroscope movement cause look to be screen-relative instead of world-relative
# TODO: make background image visible on mobile, some compact image error
# TODO: implement option to bring up multipler menu and test webrtc exntension work on mobile

# Mobile input settings
var mobile_sensitivity := 1.0
var mobile_pinch_sensitivity := 10.0
var mobile_drag_threshold := 10.0

# Gesture detection settings
var two_finger_delay := 0.1  # Small delay to detect two-finger gestures

# Touch tracking
var mobile_touches := {}
var last_two_finger_time := 0.0  # Track when we last had two fingers

# Input state
var accumulated_look_delta := Vector2.ZERO
var current_movement := Vector3.ZERO
var is_shooting_active := false  # Track shooting state for direct method calls
var last_shot_time := 0.0  # For shot cooldown

# Camera reference
var camera: Camera3D
var fly_speed := 12.0

func initialize(camera_ref: Camera3D) -> void:
	camera = camera_ref
	# Copy settings from camera
	mobile_sensitivity = camera.mobile_sensitivity
	mobile_pinch_sensitivity = camera.mobile_pinch_sensitivity
	mobile_drag_threshold = camera.mobile_drag_threshold
	fly_speed = camera.fly_speed

func handle_input_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			mobile_touches[event.index] = {
				"position": event.position,
				"start_time": Time.get_ticks_msec() / 1000.0,
				"last_position": event.position,
				"has_dragged": false,
				"is_shooting": true  # Start shooting on touch down
			}
			# Set shooting active when any finger touches
			is_shooting_active = true
		else:
			if event.index in mobile_touches:
				_handle_mobile_release(event.index)
				mobile_touches.erase(event.index)
	
	elif event is InputEventScreenDrag:
		if event.index in mobile_touches:
			mobile_touches[event.index]["last_position"] = event.position
			mobile_touches[event.index]["has_dragged"] = true
			_handle_mobile_drag(event.index, event.relative)

func process_input(delta: float) -> void:
	var touch_count = mobile_touches.size()
	
	# Track when we have two fingers for the finger-lifting issue
	if touch_count >= 2:
		last_two_finger_time = Time.get_ticks_msec() / 1000.0
		_handle_pinch_gesture(delta)
		
		# Disable shooting for all touches when using two-finger gestures
		for touch_data in mobile_touches.values():
			touch_data["is_shooting"] = false
	
	# Reset all movement and shooting if no touches
	if touch_count == 0:
		current_movement = Vector3.ZERO  # Reset everything when no touches
		is_shooting_active = false  # Reset shooting state when no touches
	else:
		# Update shooting state - active if any touch is shooting
		is_shooting_active = false
		for touch_data in mobile_touches.values():
			if touch_data.get("is_shooting", false):
				is_shooting_active = true
				break

func _handle_mobile_release(_finger_id: int) -> void:
	# Clean up on touch release - no special handling needed
	pass

func _handle_mobile_drag(_finger_id: int, relative: Vector2) -> void:
	var touch_count = mobile_touches.size()
	
	# Simple gesture based on touch count
	if touch_count == 1:
		_apply_look(relative)
	elif touch_count == 2:
		_apply_strafe(relative)

func _apply_look(relative: Vector2) -> void:
	# Convert screen drag to camera rotation
	var sensitivity = mobile_sensitivity * 0.002
	accumulated_look_delta.x += relative.x * sensitivity
	accumulated_look_delta.y += relative.y * sensitivity

func _apply_strafe(relative: Vector2) -> void:
	# Convert screen drag to normalized strafe movement (like controller)
	var strafe_sensitivity = mobile_sensitivity * 0.1
	
	# Simple direct assignment - drag right = move right
	current_movement.x = -relative.x * strafe_sensitivity
	current_movement.y = relative.y * strafe_sensitivity
	
	# Clamp to normalized range like controller input
	current_movement.x = clamp(current_movement.x, -1.0, 1.0)
	current_movement.y = clamp(current_movement.y, -1.0, 1.0)

func _handle_pinch_gesture(_delta: float) -> void:
	var touch_ids = mobile_touches.keys()
	if touch_ids.size() < 2:
		return
	
	# Use last_position to avoid jumps when fingers move during pinch
	var pos1 = mobile_touches[touch_ids[0]]["last_position"]
	var pos2 = mobile_touches[touch_ids[1]]["last_position"]
	var current_distance = pos1.distance_to(pos2)
	
	# Get previous distance for comparison
	var previous_distance = get_meta("pinch_distance", current_distance)
	var distance_change = current_distance - previous_distance
	
	# Apply forward/backward movement based on pinch/spread
	var pinch_sensitivity = mobile_pinch_sensitivity * 0.01
	# Negative distance_change = pinch = forward, positive = spread = backward (inverted for correct feel)
	var movement_delta = -distance_change * pinch_sensitivity
	
	# Set movement directly for responsive control
	current_movement.z = clamp(movement_delta, -1.0, 1.0)
	
	set_meta("pinch_distance", current_distance)

# Interface implementation
func get_movement_vector() -> Vector3:
	return current_movement

func get_look_delta() -> Vector2:
	var delta = accumulated_look_delta
	accumulated_look_delta = Vector2.ZERO
	return delta

func get_boost_modifier() -> float:
	return 1.0

func is_active() -> bool:
	return mobile_touches.size() > 0

# Action state methods (new direct method approach)
func is_shooting() -> bool:
	return is_shooting_active

func is_using_laser() -> bool:
	return false  # Not implemented for mobile yet
