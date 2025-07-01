extends Node3D

@export var NodeScene: PackedScene
@export var EdgeScene: PackedScene
@export var num_nodes: int = 8

var nodes = []
var edges = []
var anchor_manager: AnchorManager
var multiplayer_manager: Node
var remote_player: Node
var camera: Camera3D
var multiplayer_menu: Control

var adjacency_matrix = []

func _ready():
	# Create anchor manager
	anchor_manager = AnchorManager.new()
	add_child(anchor_manager)
	
	# Create multiplayer manager
	multiplayer_manager = preload("res://multiplayer/multiplayer_manager_mesh.gd").new()
	add_child(multiplayer_manager)
	
	# Connect to built-in multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_joined)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	
	# Find the camera (assuming it's added to the scene)
	camera = get_viewport().get_camera_3d()
	
	# Create multiplayer menu
	_create_multiplayer_menu()
	
	# Start with mouse visible and not captured
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	adjacency_matrix = generate_random_adjacency_matrix(num_nodes)

	for i in range(adjacency_matrix.size()):
		var node_instance = NodeScene.instantiate()
		add_child(node_instance)
		# Register with anchor manager
		anchor_manager.add_node(node_instance)
		# More compact initial positioning in a smaller sphere
		var angle1 = randf() * TAU
		var angle2 = randf() * PI
		var radius = randf() * 3.0 + 1.0  # Radius between 1 and 4
		var x = radius * sin(angle2) * cos(angle1)
		var y = radius * sin(angle2) * sin(angle1)
		var z = radius * cos(angle2)
		node_instance.global_transform.origin = Vector3(x, y, z)
		nodes.append(node_instance)

	for i in range(adjacency_matrix.size()):
		for j in range(i, adjacency_matrix[i].size()):
			if adjacency_matrix[i][j] == 1:
				var edge_instance = EdgeScene.instantiate()
				add_child(edge_instance)
				edge_instance.start_node = nodes[i]
				edge_instance.end_node = nodes[j]
				edges.append(edge_instance)
				nodes[i].connected_nodes.append(nodes[j])
				nodes[j].connected_nodes.append(nodes[i])

func _process(_delta):
	# ALWAYS ensure mouse is visible when menu is open (overrides any capture attempts)
	if multiplayer_menu.is_menu_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Handle mouse capture for game control (Enter/Space key)
	if not multiplayer_menu.is_menu_open and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		if Input.is_action_just_pressed("ui_accept"):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Send player position to remote peer if connected (only when mouse is captured)
	if multiplayer_manager.is_mesh_connected() and camera and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		multiplayer_manager.send_player_data(camera.global_position, camera.global_rotation)

func _input(event):
	# Handle ESC key - toggle menu or release mouse
	if event.is_action_pressed("ui_cancel"):
		multiplayer_menu.toggle_menu()
		if multiplayer_menu.is_menu_open:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_viewport().set_input_as_handled()
	
	# Capture mouse on left click when menu is closed
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not multiplayer_menu.is_menu_open:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_viewport().set_input_as_handled()


func _notification(what):
	# Handle window focus changes
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			# Release mouse capture when window loses focus
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		NOTIFICATION_WM_CLOSE_REQUEST:
			# Allow window to close properly
			get_tree().quit()

# Multiplayer connection handlers
func _on_peer_joined(peer_id: int):
	print("Main: Peer joined with ID ", peer_id)

func _on_peer_left(peer_id: int):
	print("Main: Peer left with ID ", peer_id)

# Menu setup
func _create_multiplayer_menu():
	# Create CanvasLayer for UI overlay
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	# Load menu scene
	var menu_scene = preload("res://multiplayer/multiplayer_menu.tscn")
	multiplayer_menu = menu_scene.instantiate()
	canvas_layer.add_child(multiplayer_menu)
	
	# Setup connections
	multiplayer_menu.setup_multiplayer_manager(multiplayer_manager)

func generate_random_adjacency_matrix(size: int) -> Array:
	var matrix = []
	for i in range(size):
		var row = []
		for j in range(size):
			if i == j:
				row.append(0)
			elif j < i:
				row.append(matrix[j][i])
			else:
				row.append(randi() % 2)
		matrix.append(row)
	return matrix
