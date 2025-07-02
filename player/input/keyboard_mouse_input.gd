extends "res://player/input/input_handler.gd"
class_name KeyboardMouseInput

# Handles keyboard WASD movement, mouse look, and mouse button actions

# Input sensitivity settings (copied from camera)
var mouse_sensitivity := 0.002
var fly_speed := 12.0
var boost_multiplier := 5.0

# Internal state
var accumulated_look_delta := Vector2.ZERO
var current_movement := Vector3.ZERO
var current_boost_modifier := 1.0
var should_shoot_once := false
var should_auto_fire := false
var should_laser := false

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
	mouse_sensitivity = camera.get("mouse_sensitivity")
	fly_speed = camera.get("fly_speed") 
	boost_multiplier = camera.get("boost_multiplier")

func handle_input_event(event: InputEvent) -> void:
	_handle_mouse_look(event)
	_handle_mouse_buttons(event)
	_handle_fullscreen_toggle(event)

func _handle_mouse_buttons(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				shoot_once_requested.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				laser_started.emit()
			else:
				laser_stopped.emit()

func _handle_mouse_look(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Accumulate look delta for this frame (will be consumed by get_look_delta)
		accumulated_look_delta.x += -event.relative.x * mouse_sensitivity
		accumulated_look_delta.y += -event.relative.y * mouse_sensitivity

func _handle_fullscreen_toggle(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func process_input(_delta: float) -> void:
	_update_movement_input()
	_update_boost_input()
	_update_action_input()

func _update_action_input() -> void:
	# Check for continuous mouse button states
	var laser_active = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if laser_active != should_laser:
		should_laser = laser_active
		if should_laser:
			laser_started.emit()
		else:
			laser_stopped.emit()

func _update_movement_input() -> void:
	# Calculate keyboard movement in camera's local coordinate system
	var input_vector = Vector3.ZERO
	
	# Keyboard movement (WASD + QE)
	if Input.is_key_pressed(KEY_W):
		input_vector += Vector3.FORWARD  # Forward in local space
	if Input.is_key_pressed(KEY_S):
		input_vector += -Vector3.FORWARD   # Backward in local space
	if Input.is_key_pressed(KEY_A):
		input_vector += -Vector3.RIGHT    # Left in local space
	if Input.is_key_pressed(KEY_D):
		input_vector += Vector3.RIGHT     # Right in local space
	if Input.is_key_pressed(KEY_E):
		input_vector += Vector3.UP        # Up in local space
	if Input.is_key_pressed(KEY_Q):
		input_vector += -Vector3.UP       # Down in local space
	
	current_movement = input_vector.normalized() if input_vector.length() > 0 else Vector3.ZERO

func _update_boost_input() -> void:
	# Check for boost input (Shift key)
	current_boost_modifier = boost_multiplier if Input.is_key_pressed(KEY_SHIFT) else 1.0

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
