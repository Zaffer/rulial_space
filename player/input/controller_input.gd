extends "res://player/input/input_handler.gd"
class_name ControllerInput

# Handles gamepad/controller input - sticks, buttons, triggers

# Input sensitivity settings (copied from camera)
var controller_sensitivity := 2.0
var fly_speed := 12.0
var boost_multiplier := 5.0

# Internal state
var accumulated_look_delta := Vector2.ZERO
var current_movement := Vector3.ZERO
var current_boost_modifier := 1.0
var last_shoot_state := false
var last_laser_state := false

# Reference to camera for coordinate transforms
var camera: Camera3D

# Signals for actions
signal shoot_once_requested
signal auto_fire_started
signal auto_fire_stopped  
signal laser_started
signal laser_stopped

func initialize(camera_ref: Camera3D) -> void:
	camera = camera_ref
	# Copy sensitivity settings from camera
	controller_sensitivity = camera.get("controller_sensitivity")
	fly_speed = camera.get("fly_speed") 
	boost_multiplier = camera.get("boost_multiplier")

func handle_input_event(_event: InputEvent) -> void:
	# Controller input is polled, not event-based
	pass

func process_input(delta: float) -> void:
	_update_look_input(delta)
	_update_movement_input(delta)
	_update_boost_input()
	_update_action_input()

func _update_look_input(delta: float) -> void:
	# Controller look with right stick
	var look_vector = Vector2.ZERO
	look_vector.x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	look_vector.y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	
	if look_vector.length() > 0.1:
		# Apply sensitivity and delta time, accumulate for this frame
		accumulated_look_delta.x += -look_vector.x * controller_sensitivity * delta
		accumulated_look_delta.y += -look_vector.y * controller_sensitivity * delta

func _update_movement_input(_delta: float) -> void:
	var input_vector = Vector3.ZERO
	
	# Controller movement (left stick)
	var move_stick = Vector2.ZERO
	move_stick.x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	move_stick.y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	
	if move_stick.length() > 0.1:
		var stick_direction = move_stick.normalized()
		var movement_multiplier = move_stick.length()  # Analog sensitivity
		
		# Forward/backward from Y axis (negative Y = forward)
		input_vector += Vector3.BACK * stick_direction.y
		# Left/right from X axis  
		input_vector += Vector3.RIGHT * stick_direction.x
		
		# Apply analog sensitivity
		input_vector *= movement_multiplier
	
	# Controller vertical movement (triggers)
	if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.1:  # RT - Up
		var trigger_amount = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
		input_vector += Vector3.UP * trigger_amount
	if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.1:   # LT - Down
		var trigger_amount = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
		input_vector += -Vector3.UP * trigger_amount
	
	current_movement = input_vector.normalized() if input_vector.length() > 0 else Vector3.ZERO

func _update_boost_input() -> void:
	# Check for boost input (Left Shoulder button)
	current_boost_modifier = boost_multiplier if Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) else 1.0

func _update_action_input() -> void:
	# Handle controller button actions with edge detection
	
	# A button or Right Shoulder - Shooting (emit only on press, not hold)
	var shoot_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)
	if shoot_pressed and not last_shoot_state:
		shoot_once_requested.emit()
	last_shoot_state = shoot_pressed
	
	# B button - Laser (emit on state change)
	var laser_active = Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	if laser_active != last_laser_state:
		last_laser_state = laser_active
		if laser_active:
			laser_started.emit()
		else:
			laser_stopped.emit()

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
