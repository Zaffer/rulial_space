extends "res://player/input/input_handler.gd"
class_name GyroscopeInput

# Simple gyroscope input for mobile web browsers

var sensitivity := 1.0
var enabled := true
var last_orientation := Vector3.ZERO
var calibrated := false
var look_delta := Vector2.ZERO
var debug_counter := 0  # Minimal debug for initial troubleshooting
var camera_ref: Camera3D  # Reference to camera for orientation compensation

func initialize(camera_ref: Camera3D) -> void:
	self.camera_ref = camera_ref
	_setup_gyroscope()

func handle_input_event(event: InputEvent) -> void:
	pass

func process_input(_delta: float) -> void:
	if enabled:
		_update_gyroscope()

func get_look_delta() -> Vector2:
	var delta = look_delta
	look_delta = Vector2.ZERO
	return delta

func get_movement_vector() -> Vector3:
	return Vector3.ZERO

func get_boost_modifier() -> float:
	return 1.0

func is_active() -> bool:
	return enabled and calibrated

func _setup_gyroscope() -> void:
	var js = """
		window.gyro = { alpha: 0, beta: 0, gamma: 0, ready: false };
		
		function onOrient(e) {
			window.gyro.alpha = e.alpha || 0;
			window.gyro.beta = e.beta || 0;
			window.gyro.gamma = e.gamma || 0;
			window.gyro.ready = true;
		}
		
		if (typeof DeviceOrientationEvent.requestPermission === 'function') {
			DeviceOrientationEvent.requestPermission().then(r => {
				if (r === 'granted') window.addEventListener('deviceorientation', onOrient);
			});
		} else {
			window.addEventListener('deviceorientation', onOrient);
		}
	"""
	JavaScriptBridge.eval(js)

func _update_gyroscope() -> void:
	
	var ready = JavaScriptBridge.eval("window.gyro ? window.gyro.ready : false")
	if not ready:
		return
	
	# Fetch individual primitive values (critical - can't return objects/arrays)
	var alpha = JavaScriptBridge.eval("window.gyro ? window.gyro.alpha : 0")
	var beta = JavaScriptBridge.eval("window.gyro ? window.gyro.beta : 0")
	var gamma = JavaScriptBridge.eval("window.gyro ? window.gyro.gamma : 0")
	
	# Null check (JavaScriptBridge can return null)
	if alpha == null or beta == null or gamma == null:
		return
	
	var current = Vector3(alpha, beta, gamma)
	
	if not calibrated:
		last_orientation = current
		calibrated = true
		print("Gyroscope: Calibrated with ", current)
		return
	
	var delta = current - last_orientation
	
	# Handle wraparound (critical for angle calculations)
	if delta.x > 180: delta.x -= 360
	elif delta.x < -180: delta.x += 360
	if delta.y > 180: delta.y -= 360
	elif delta.y < -180: delta.y += 360
	if delta.z > 180: delta.z -= 360
	elif delta.z < -180: delta.z += 360
	
	# gamma (phone roll/tilt) controls spaceship yaw (horizontal look)
	# beta (phone pitch) controls spaceship pitch (vertical look)
	# alpha (phone yaw/compass) could control spaceship roll (not used for now)
	look_delta.x += delta.z * sensitivity * 0.01  # gamma -> yaw
	look_delta.y += delta.y * sensitivity * 0.01   # beta -> pitch

    # TODO: Transform screen-space phone tilts into world-space camera movements

	last_orientation = current

func cleanup() -> void:
	pass
