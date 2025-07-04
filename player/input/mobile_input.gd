extends "res://player/input/input_handler.gd"
class_name MobileInput

# Handles mobile touch gestures: tap/drag for shooting and looking, pinch for movement, two-finger strafe

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

# Camera reference
var camera: Camera3D
var fly_speed := 12.0

# Signals
signal shoot
signal laser  # Reserved for future use
signal flight_mode_changed(mode: String)  # Reserved for future use

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
				"shot_fired": false
			}
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
	
	# Reset all movement if no touches
	if touch_count == 0:
		current_movement = Vector3.ZERO  # Reset everything when no touches

func _handle_mobile_release(_finger_id: int) -> void:
	# Clean up on touch release - no special handling needed
	pass

func _handle_mobile_drag(finger_id: int, relative: Vector2) -> void:
	var touch_count = mobile_touches.size()
	var touch_data = mobile_touches[finger_id]
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Fire single shot on first drag
	if not touch_data["shot_fired"]:
		shoot.emit()
		touch_data["shot_fired"] = true
	
	# # Simple fix for fast second finger: ignore very large relative movements on first drag
	# # (these are usually caused by rapid finger placement)
	# if not touch_data["has_dragged"] and relative.length() > 50.0:
	# 	return  # Skip this first large movement
	
	# # Simple fix for finger lifting: ignore single finger drags right after two-finger gestures
	# # (these are usually caused by one finger lifting slightly before the other)
	# if touch_count == 1 and (current_time - last_two_finger_time) < 0.2:
	# 	return  # Skip single finger drags shortly after two-finger gestures
	
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
