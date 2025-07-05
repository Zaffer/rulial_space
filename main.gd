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
var hypergraph: HypergraphLogic
var selected_node_idx: int = 0  # Currently selected node for rule application

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
	
	# Create hypergraph and initialize visualization
	hypergraph = HypergraphLogic.new(num_nodes, 0)
	hypergraph.generate_random_hyperedges(num_nodes)
	
	HypergraphVisualizer.initialize_visualization(hypergraph, nodes, edges, NodeScene, EdgeScene, anchor_manager, self, selected_node_idx)

func _process(_delta):
	# ALWAYS ensure mouse is visible when menu is open (overrides any capture attempts)
	if multiplayer_menu.is_menu_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Handle mouse capture for game control (Enter/Space key)
	if not multiplayer_menu.is_menu_open and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		if Input.is_action_just_pressed("ui_accept"):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Send player position to remote peer if connected (only when mouse is captured)
	if multiplayer_manager.is_network_connected() and camera and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
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
	
	# Hypergraph rewrite rules (when menu is closed)
	elif not multiplayer_menu.is_menu_open:
		if event.is_action_pressed("ui_up"):  # Up arrow
			RewritingRules.apply_rule(hypergraph, "triangle_to_edge", selected_node_idx)
			HypergraphVisualizer.rebuild_visualization(hypergraph, nodes, edges, EdgeScene, self)
		elif event.is_action_pressed("ui_down"):  # Down arrow
			RewritingRules.apply_rule(hypergraph, "edge_to_triangle", selected_node_idx)
			HypergraphVisualizer.rebuild_visualization(hypergraph, nodes, edges, EdgeScene, self)
		elif event.is_action_pressed("ui_left"):  # Left arrow - select previous node
			selected_node_idx = (selected_node_idx - 1) % num_nodes
			HypergraphVisualizer.highlight_selected_node(nodes, selected_node_idx)
		elif event.is_action_pressed("ui_right"):  # Right arrow - select next node
			selected_node_idx = (selected_node_idx + 1) % num_nodes
			HypergraphVisualizer.highlight_selected_node(nodes, selected_node_idx)
		elif event.is_action_pressed("ui_accept"):  # Space/Enter - print matrix
			hypergraph.print_matrix()
			print("Selected node: ", selected_node_idx)


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

# Handle projectile hitting a node (called from node.gd)
func apply_rewrite_to_node(hit_node):
	var node_index = hit_node.get_meta("node_index", -1)
	if node_index >= 0:
		RewritingRules.apply_rule(hypergraph, "triangle_to_edge", node_index)
		HypergraphVisualizer.rebuild_visualization(hypergraph, nodes, edges, EdgeScene, self)
