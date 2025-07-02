class_name InputManager
extends RefCounted

# Coordinates between different input handlers and emits unified signals
# Manages priority between input types (mobile overrides others when active)

# Signal definitions for discrete events
signal shoot_once
signal auto_fire_started
signal auto_fire_stopped
signal laser_started
signal laser_stopped
signal flight_mode_changed(mode: String)  # "NORMAL" or "BOOST"

# Input handlers (will be properly typed once handler files exist)
var keyboard_mouse_handler
var controller_handler  
var mobile_handler

# State tracking
var current_flight_mode := "NORMAL"
var is_mobile_active := false

func initialize(camera: Camera3D) -> void:
	# Create all input handlers (enabled as we create each handler file)
	keyboard_mouse_handler = preload("res://player/input/keyboard_mouse_input.gd").new()
	controller_handler = preload("res://player/input/controller_input.gd").new()
	mobile_handler = preload("res://player/input/mobile_input.gd").new()
	
	# Initialize handlers
	keyboard_mouse_handler.initialize(camera)
	controller_handler.initialize(camera)
	mobile_handler.initialize(camera)
	
	# Connect signals for priority handling
	_connect_handler_signals()

func _connect_handler_signals() -> void:
	# Connect signals from all handlers to forward them
	if keyboard_mouse_handler:
		keyboard_mouse_handler.shoot_once_requested.connect(_on_shoot_once)
		keyboard_mouse_handler.laser_started.connect(_on_laser_started)
		keyboard_mouse_handler.laser_stopped.connect(_on_laser_stopped)
	
	if controller_handler:
		controller_handler.shoot_once_requested.connect(_on_shoot_once)
		controller_handler.laser_started.connect(_on_laser_started)
		controller_handler.laser_stopped.connect(_on_laser_stopped)
	
	if mobile_handler:
		mobile_handler.shoot_once_requested.connect(_on_shoot_once)
		mobile_handler.auto_fire_started.connect(_on_auto_fire_started)
		mobile_handler.auto_fire_stopped.connect(_on_auto_fire_stopped)
		mobile_handler.laser_started.connect(_on_laser_started)
		mobile_handler.laser_stopped.connect(_on_laser_stopped)
		mobile_handler.flight_mode_changed.connect(_on_flight_mode_changed)

# Signal forwarders
func _on_shoot_once() -> void:
	shoot_once.emit()

func _on_auto_fire_started() -> void:
	auto_fire_started.emit()

func _on_auto_fire_stopped() -> void:
	auto_fire_stopped.emit()

func _on_laser_started() -> void:
	laser_started.emit()

func _on_laser_stopped() -> void:
	laser_stopped.emit()

func _on_flight_mode_changed(mode: String) -> void:
	current_flight_mode = mode
	flight_mode_changed.emit(mode)

func process_input(delta: float) -> void:
	# Update all handlers (when they exist)
	if keyboard_mouse_handler:
		keyboard_mouse_handler.process_input(delta)
	if controller_handler:
		controller_handler.process_input(delta)
	if mobile_handler:
		mobile_handler.process_input(delta)
	
	# Detect if mobile is active (has touches)
	_update_mobile_priority()

func handle_input_event(event: InputEvent) -> void:
	# Route input events to appropriate handlers (when they exist)
	if keyboard_mouse_handler:
		keyboard_mouse_handler.handle_input_event(event)
	if controller_handler:
		controller_handler.handle_input_event(event)
	if mobile_handler:
		mobile_handler.handle_input_event(event)

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
	if is_mobile_active and mobile_handler:
		return mobile_handler.get_look_delta()
	
	# Combine mouse and controller look
	var look = Vector2.ZERO
	if keyboard_mouse_handler:
		look = keyboard_mouse_handler.get_look_delta()
	if controller_handler:
		look += controller_handler.get_look_delta()  # Additive for smooth blending
	
	return look

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
