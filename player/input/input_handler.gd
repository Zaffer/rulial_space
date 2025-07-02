class_name InputHandler
extends RefCounted

# Base class for all input handlers (keyboard/mouse, controller, mobile)
# Defines the common interface that all input types must implement

# Continuous input methods (polled each frame)
func get_movement_vector() -> Vector3:
	# Return movement input as Vector3 (forward/back, left/right, up/down)
	return Vector3.ZERO

func get_look_delta() -> Vector2:
	# Return look input as Vector2 (horizontal, vertical rotation delta)
	return Vector2.ZERO

func get_boost_modifier() -> float:
	# Return boost multiplier (1.0 = normal, higher = boosted)
	return 1.0

# Setup and cleanup methods
func initialize(_camera: Camera3D) -> void:
	# Called when handler is first created
	pass

func process_input(_delta: float) -> void:
	# Called each frame to update internal state
	pass

func handle_input_event(_event: InputEvent) -> void:
	# Called for each input event
	pass

func cleanup() -> void:
	# Called when handler is being destroyed
	pass
