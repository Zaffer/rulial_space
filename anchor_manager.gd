extends Node

class_name AnchorManager

signal anchor_changed(new_anchor: RigidBody3D)

var anchor_node: RigidBody3D = null
var tracked_nodes: Array[RigidBody3D] = []

func add_node(node: RigidBody3D):
	if node not in tracked_nodes:
		tracked_nodes.append(node)
		# Connect to know when it's destroyed
		node.tree_exiting.connect(_on_node_destroyed.bind(node))
		# Update anchor if needed
		update_anchor_node()

func remove_node(node: RigidBody3D):
	tracked_nodes.erase(node)
	# If it was the anchor, find a new one
	if anchor_node == node:
		anchor_node = null
		update_anchor_node()

func _on_node_destroyed(node: RigidBody3D):
	remove_node(node)

func find_closest_node_to_center() -> RigidBody3D:
	var closest_node: RigidBody3D = null
	var closest_distance = INF
	
	for node in tracked_nodes:
		if node and is_instance_valid(node):
			var distance = node.global_transform.origin.length()
			if distance < closest_distance:
				closest_distance = distance
				closest_node = node
	
	return closest_node

func update_anchor_node():
	# Check if current anchor is still valid
	if anchor_node and is_instance_valid(anchor_node) and anchor_node in tracked_nodes:
		return  # Current anchor is fine
	
	# Clear old anchor status from all nodes
	for node in tracked_nodes:
		if node and is_instance_valid(node):
			node.is_anchor = false
	
	# Find new anchor node
	anchor_node = find_closest_node_to_center()
	if anchor_node:
		anchor_node.is_anchor = true
		anchor_changed.emit(anchor_node)
		print("New anchor node set: ", anchor_node.name)

func get_anchor() -> RigidBody3D:
	return anchor_node

func has_anchor() -> bool:
	return anchor_node != null and is_instance_valid(anchor_node)
