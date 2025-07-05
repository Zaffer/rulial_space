class_name InputManager
extends RefCounted

# Coordinates between different input handlers and provides unified input interface
# Manages priority between input types (mobile overrides others when active)

# Input handlers (will be properly typed once handler files exist)
var keyboard_mouse_handler
var controller_handler  
var mobile_handler
var gyroscope_handler

func initialize(camera: Camera3D) -> void:
	# Create all input handlers (enabled as we create each handler file)
	keyboard_mouse_handler = preload("res://player/input/keyboard_mouse_input.gd").new()
	controller_handler = preload("res://player/input/controller_input.gd").new()
	mobile_handler = preload("res://player/input/mobile_input.gd").new()
	gyroscope_handler = preload("res://player/input/gyroscope_input.gd").new()
	
	# Initialize handlers
	keyboard_mouse_handler.initialize(camera)
	controller_handler.initialize(camera)
	mobile_handler.initialize(camera)
	gyroscope_handler.initialize(camera)

func process_input(delta: float) -> void:
	# Update all handlers (when they exist)
	if keyboard_mouse_handler:
		keyboard_mouse_handler.process_input(delta)
	if controller_handler:
		controller_handler.process_input(delta)
	if mobile_handler:
		mobile_handler.process_input(delta)
	if gyroscope_handler:
		gyroscope_handler.process_input(delta)

func handle_input_event(event: InputEvent) -> void:
	# Route input events to appropriate handlers (when they exist)
	
	# Always let mobile handler process touch events first
	if mobile_handler:
		mobile_handler.handle_input_event(event)
	
	# Only allow keyboard/mouse if mobile is not currently active (has no touches)
	if not (mobile_handler and mobile_handler.is_active()):
		if keyboard_mouse_handler:
			keyboard_mouse_handler.handle_input_event(event)
		if controller_handler:
			controller_handler.handle_input_event(event)

# Unified input getters (combine all active sources with smart priority)
func get_movement_vector() -> Vector3:
	# Mobile takes priority when active
	if mobile_handler and mobile_handler.is_active():
		return mobile_handler.get_movement_vector()
	
	# Combine keyboard and controller input when mobile is not active
	var movement = keyboard_mouse_handler.get_movement_vector() if keyboard_mouse_handler else Vector3.ZERO
	if movement.length() < 0.1 and controller_handler:  # If no keyboard input, try controller
		movement = controller_handler.get_movement_vector()
	
	return movement

func get_look_delta() -> Vector2:
	var look = Vector2.ZERO
	
	# Mobile takes priority when active
	if mobile_handler and mobile_handler.is_active():
		look = mobile_handler.get_look_delta()
	else:
		# Combine mouse and controller when mobile is not active
		if keyboard_mouse_handler:
			look = keyboard_mouse_handler.get_look_delta()
		if controller_handler:
			look += controller_handler.get_look_delta()  # Additive for smooth blending
	
	# Always add gyroscope input regardless of mobile state
	if gyroscope_handler:
		look += gyroscope_handler.get_look_delta()
	
	return look

func get_roll_delta() -> float:
	# No rolling implemented yet
	return 0.0

func get_boost_modifier() -> float:
	# Mobile takes priority when active
	if mobile_handler and mobile_handler.is_active():
		return mobile_handler.get_boost_modifier()
	
	# Use highest boost from keyboard/controller
	var kb_boost = keyboard_mouse_handler.get_boost_modifier() if keyboard_mouse_handler else 1.0
	var controller_boost = controller_handler.get_boost_modifier() if controller_handler else 1.0
	return max(kb_boost, controller_boost)

# Unified action getters - use ANY active input source (more permissive than movement)
func is_shooting() -> bool:
	# Mobile takes priority when active, otherwise check desktop inputs
	if mobile_handler and mobile_handler.is_active():
		return mobile_handler.is_shooting()
	else:
		var kb_shoot = keyboard_mouse_handler.is_shooting() if keyboard_mouse_handler else false
		var controller_shoot = controller_handler.is_shooting() if controller_handler else false
		return kb_shoot or controller_shoot

func is_using_laser() -> bool:
	# Mobile takes priority when active, otherwise check desktop inputs
	if mobile_handler and mobile_handler.is_active():
		return mobile_handler.is_using_laser()
	else:
		var kb_laser = keyboard_mouse_handler.is_using_laser() if keyboard_mouse_handler else false
		var controller_laser = controller_handler.is_using_laser() if controller_handler else false
		return kb_laser or controller_laser

func get_flight_mode() -> String:
	# Reserved for future mobile boost implementation
	return "normal"

func cleanup() -> void:
	if keyboard_mouse_handler:
		keyboard_mouse_handler.cleanup()
	if controller_handler:
		controller_handler.cleanup()
	if mobile_handler:
		mobile_handler.cleanup()
	if gyroscope_handler:
		gyroscope_handler.cleanup()
