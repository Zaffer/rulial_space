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
var shoot_pressed := false
var laser_pressed := false
var controller_id := -1  # Cached controller ID

# Reference to camera for coordinate transforms
var camera: Camera3D

# Signals for actions
signal shoot  # Emitted continuously while button held
signal laser  # Emitted continuously while button held

func initialize(camera_ref: Camera3D) -> void:
	camera = camera_ref
	# Copy sensitivity settings from camera
	controller_sensitivity = camera.get("controller_sensitivity")
	fly_speed = camera.get("fly_speed") 
	boost_multiplier = camera.get("boost_multiplier")

func _get_controller_id() -> int:
	# Get the first available controller, or -1 if none
	var connected_joypads = Input.get_connected_joypads()
	return connected_joypads[0] if connected_joypads.size() > 0 else -1

func handle_input_event(_event: InputEvent) -> void:
	# Controller input is polled, not event-based
	pass

func process_input(delta: float) -> void:
	# Update controller ID once per frame
	controller_id = _get_controller_id()
	
	_update_look_input(delta)
	_update_movement_input(delta)
	_update_boost_input()
	_update_action_states()
	_emit_continuous_actions()

func _update_action_states() -> void:
	# Update action states based on current button presses
	# Shoot: Right shoulder button (previously A button)
	shoot_pressed = Input.is_joy_button_pressed(controller_id, JOY_BUTTON_RIGHT_SHOULDER)
	# Laser: Left shoulder button (LB)
	laser_pressed = Input.is_joy_button_pressed(controller_id, JOY_BUTTON_LEFT_SHOULDER)

func _emit_continuous_actions() -> void:
	# Emit continuous action signals while buttons are held
	if shoot_pressed:
		shoot.emit()
	if laser_pressed:
		laser.emit()

func _update_look_input(delta: float) -> void:
	# Controller look with right stick
	var look_vector = Vector2.ZERO
	look_vector.x = Input.get_joy_axis(controller_id, JOY_AXIS_RIGHT_X)
	look_vector.y = Input.get_joy_axis(controller_id, JOY_AXIS_RIGHT_Y)
	
	if look_vector.length() > 0.1:
		# Apply sensitivity and delta time, accumulate for this frame
		accumulated_look_delta.x += -look_vector.x * controller_sensitivity * delta
		accumulated_look_delta.y += -look_vector.y * controller_sensitivity * delta

func _update_movement_input(_delta: float) -> void:
	var input_vector = Vector3.ZERO
	
	# Controller movement (left stick)
	var move_stick = Vector2.ZERO
	move_stick.x = Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_X)
	move_stick.y = Input.get_joy_axis(controller_id, JOY_AXIS_LEFT_Y)
	
	if move_stick.length() > 0.1:
		# Forward/backward from Y axis (negative Y = forward)
		input_vector += Vector3.BACK * move_stick.y
		# Left/right from X axis  
		input_vector += Vector3.RIGHT * move_stick.x
	
	# Controller vertical movement (triggers)
	if Input.get_joy_axis(controller_id, JOY_AXIS_TRIGGER_RIGHT) > 0.1:  # RT - Up
		var trigger_amount = Input.get_joy_axis(controller_id, JOY_AXIS_TRIGGER_RIGHT)
		input_vector += Vector3.UP * trigger_amount
	if Input.get_joy_axis(controller_id, JOY_AXIS_TRIGGER_LEFT) > 0.1:   # LT - Down
		var trigger_amount = Input.get_joy_axis(controller_id, JOY_AXIS_TRIGGER_LEFT)
		input_vector += Vector3.DOWN * trigger_amount
	
	current_movement = input_vector

func _update_boost_input() -> void:
	# Check for boost input (Left stick click/press - L3)
	current_boost_modifier = boost_multiplier if Input.is_joy_button_pressed(controller_id, JOY_BUTTON_LEFT_STICK) else 1.0

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

# Action state methods (new direct method approach)
func is_shooting() -> bool:
	return shoot_pressed

func is_using_laser() -> bool:
	return laser_pressed

# State query methods
func is_active() -> bool:
	# Controller is considered active if any action is being performed and controller is connected
	return controller_id >= 0 and (shoot_pressed or laser_pressed or current_movement.length() > 0.1)
