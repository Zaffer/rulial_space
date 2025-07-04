class_name InputManager
extends RefCounted

# Coordinates between different input handlers and emits unified signals
# Manages priority between input types (mobile overrides others when active)

# Signal definitions for continuous actions
signal shoot  # Emitted continuously while shoot button/gesture is held
signal laser  # Emitted continuously while laser button/gesture is held
signal flight_mode_changed(mode: String)  # Reserved for future mobile boost implementation

# Input handlers (will be properly typed once handler files exist)
var keyboard_mouse_handler
var controller_handler  
var mobile_handler
var gyroscope_handler

# State tracking
var is_mobile_active := false

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
	
	# Connect signals for priority handling
	_connect_handler_signals()

func _connect_handler_signals() -> void:
	# Connect signals from all handlers to forward them
	if keyboard_mouse_handler:
		keyboard_mouse_handler.shoot.connect(_on_shoot)
		keyboard_mouse_handler.laser.connect(_on_laser)
	
	if controller_handler:
		controller_handler.shoot.connect(_on_shoot)
		controller_handler.laser.connect(_on_laser)
	
	if mobile_handler:
		mobile_handler.shoot.connect(_on_shoot)
		mobile_handler.laser.connect(_on_laser)
		# Note: Mobile handler currently only uses shoot signal - laser reserved for future

# Signal forwarders  
func _on_shoot() -> void:
	# Debug: Find out which handler is calling this
	var caller = "unknown"
	if mobile_handler and mobile_handler.is_active():
		caller = "mobile"
	elif keyboard_mouse_handler:
		caller = "keyboard_mouse"
	else:
		caller = "controller"
	
	print("DEBUG: InputManager _on_shoot called from: ", caller)
	shoot.emit()

func _on_laser() -> void:
	print("DEBUG: InputManager _on_laser called")
	laser.emit()

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
	
	# Detect if mobile is active (has touches)
	_update_mobile_priority()

func handle_input_event(event: InputEvent) -> void:
	# Route input events to appropriate handlers (when they exist)
	
	# Always let mobile handler process touch events first
	if mobile_handler:
		mobile_handler.handle_input_event(event)
	
	# Only allow keyboard/mouse if mobile is not currently active (has no touches)
	if not is_mobile_active:
		if keyboard_mouse_handler:
			keyboard_mouse_handler.handle_input_event(event)
		if controller_handler:
			controller_handler.handle_input_event(event)

func _update_mobile_priority() -> void:
	# Check if mobile input is currently active
	if mobile_handler and mobile_handler.has_method("is_active"):
		is_mobile_active = mobile_handler.is_active()
	else:
		is_mobile_active = false

# Unified input getters (combine all active sources with priority)
func get_movement_vector() -> Vector3:
	if is_mobile_active and mobile_handler:
		return mobile_handler.get_movement_vector()
	
	# Combine keyboard and controller input
	var movement = Vector3.ZERO
	if keyboard_mouse_handler:
		movement = keyboard_mouse_handler.get_movement_vector()
	if movement.length() < 0.1 and controller_handler:  # If no keyboard input, try controller
		movement = controller_handler.get_movement_vector()
	
	return movement

func get_look_delta() -> Vector2:
	var look = Vector2.ZERO
	
	if is_mobile_active and mobile_handler:
		# When mobile is active, use mobile touch gestures as base
		look = mobile_handler.get_look_delta()
	else:
		# When mobile is not active, combine mouse and controller
		if keyboard_mouse_handler:
			look = keyboard_mouse_handler.get_look_delta()
		if controller_handler:
			look += controller_handler.get_look_delta()  # Additive for smooth blending
	
	# Always add gyroscope input regardless of mobile state
	# This allows gyroscope to work with touch gestures
	if gyroscope_handler:
		look += gyroscope_handler.get_look_delta()  # Add gyroscope input
	
	return look

func get_roll_delta() -> float:
	# no rolling implemented yet
	return 0.0

func get_boost_modifier() -> float:
	if is_mobile_active and mobile_handler:
		return mobile_handler.get_boost_modifier()
	
	# Check keyboard/controller boost
	var kb_boost = 1.0
	var controller_boost = 1.0
	
	if keyboard_mouse_handler:
		kb_boost = keyboard_mouse_handler.get_boost_modifier()
	if controller_handler:
		controller_boost = controller_handler.get_boost_modifier()
	
	return max(kb_boost, controller_boost)  # Use highest boost value

func cleanup() -> void:
	if keyboard_mouse_handler:
		keyboard_mouse_handler.cleanup()
	if controller_handler:
		controller_handler.cleanup()
	if mobile_handler:
		mobile_handler.cleanup()
	if gyroscope_handler:
		gyroscope_handler.cleanup()
