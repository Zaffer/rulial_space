class_name HypergraphVisualizer
extends RefCounted

# Handles 3D visualization of hypergraph structures

static func initialize_visualization(hypergraph: HypergraphLogic, nodes: Array, edges: Array, NodeScene: PackedScene, EdgeScene: PackedScene, anchor_manager: AnchorManager, parent_node: Node3D, selected_node_idx: int):
	# Create 3D nodes for each hypergraph node
	for i in range(hypergraph.num_nodes):
		var node_instance = NodeScene.instantiate()
		parent_node.add_child(node_instance)
		# Store the node index for efficient lookup
		node_instance.set_meta("node_index", i)
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

	# Create edges from hypergraph
	for edge_idx in range(hypergraph.num_hyperedges):
		var connected_nodes = hypergraph.get_hyperedge_nodes(edge_idx)
		# For visualization, create pairwise edges within each hyperedge
		for i in range(connected_nodes.size()):
			for j in range(i + 1, connected_nodes.size()):
				var edge_instance = EdgeScene.instantiate()
				parent_node.add_child(edge_instance)
				edge_instance.start_node = nodes[connected_nodes[i]]
				edge_instance.end_node = nodes[connected_nodes[j]]
				edges.append(edge_instance)
				nodes[connected_nodes[i]].connected_nodes.append(nodes[connected_nodes[j]])
				nodes[connected_nodes[j]].connected_nodes.append(nodes[connected_nodes[i]])
	
	# Highlight the initially selected node
	highlight_selected_node(nodes, selected_node_idx)

static func highlight_selected_node(nodes: Array, selected_node_idx: int):
	# Reset all nodes to normal scale
	for i in range(nodes.size()):
		if nodes[i]:
			if i == selected_node_idx:
				nodes[i].scale = Vector3(1.5, 1.5, 1.5)  # Highlight selected node
			else:
				nodes[i].scale = Vector3(1.0, 1.0, 1.0)  # Normal size
	print("Selected node: ", selected_node_idx)

static func rebuild_visualization(hypergraph: HypergraphLogic, nodes: Array, edges: Array, EdgeScene: PackedScene, parent_node: Node3D):
	# Clear existing edges
	for edge in edges:
		edge.queue_free()
	edges.clear()
	
	# Clear node connections
	for node in nodes:
		node.connected_nodes.clear()
	
	# Recreate edges from updated hypergraph
	for edge_idx in range(hypergraph.num_hyperedges):
		var connected_nodes = hypergraph.get_hyperedge_nodes(edge_idx)
		for i in range(connected_nodes.size()):
			for j in range(i + 1, connected_nodes.size()):
				if connected_nodes[i] < nodes.size() and connected_nodes[j] < nodes.size():
					var edge_instance = EdgeScene.instantiate()
					parent_node.add_child(edge_instance)
					edge_instance.start_node = nodes[connected_nodes[i]]
					edge_instance.end_node = nodes[connected_nodes[j]]
					edges.append(edge_instance)
					nodes[connected_nodes[i]].connected_nodes.append(nodes[connected_nodes[j]])
					nodes[connected_nodes[j]].connected_nodes.append(nodes[connected_nodes[i]])
