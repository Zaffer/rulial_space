class_name HypergraphLogic
extends RefCounted



var incidence_matrix: Array = []
var num_nodes: int = 0
var num_hyperedges: int = 0

func _init(nodes: int = 0, hyperedges: int = 0):
	num_nodes = nodes
	num_hyperedges = hyperedges
	_initialize_matrix()

func _initialize_matrix():
	incidence_matrix.clear()
	for i in range(num_nodes):
		var row = []
		for j in range(num_hyperedges):
			row.append(0)
		incidence_matrix.append(row)

# Add a hyperedge connecting given nodes
func add_hyperedge(node_indices: Array) -> int:
	# Add new column for the hyperedge
	for i in range(num_nodes):
		incidence_matrix[i].append(0)
	
	# Set connections
	for node_idx in node_indices:
		if node_idx < num_nodes:
			incidence_matrix[node_idx][num_hyperedges] = 1
	
	num_hyperedges += 1
	return num_hyperedges - 1

# Get nodes connected to a hyperedge
func get_hyperedge_nodes(hyperedge_idx: int) -> Array:
	if hyperedge_idx >= num_hyperedges:
		return []
	
	var nodes = []
	for i in range(num_nodes):
		if incidence_matrix[i][hyperedge_idx] == 1:
			nodes.append(i)
	return nodes

# Apply rewrite rule anchored to a specific node: LHS -> RHS
func apply_rewrite_rule_at_node(lhs: HypergraphLogic, rhs: HypergraphLogic, anchor_node: int, lhs_anchor: int = 0, rhs_anchor: int = 0) -> bool:
	if anchor_node >= num_nodes:
		return false
	
	# Try to find and remove the LHS pattern anchored at the specified node
	var node_mapping = _find_pattern_match(lhs, anchor_node, lhs_anchor)
	if node_mapping.is_empty():
		return false
	
	# Remove the matched pattern
	_remove_matched_pattern(lhs, node_mapping)
	
	# Add the RHS pattern using the same anchor
	_add_rhs_pattern(rhs, anchor_node, rhs_anchor, node_mapping)
	
	return true

# Find if LHS pattern exists around the anchor node
func _find_pattern_match(pattern: HypergraphLogic, anchor_node: int, pattern_anchor: int) -> Dictionary:
	# Special case: empty LHS pattern (always matches)
	if pattern.num_hyperedges == 0:
		var mapping = {}
		mapping[pattern_anchor] = anchor_node
		return mapping
	
	# Start mapping with the anchor nodes aligned
	var node_mapping = {}
	node_mapping[pattern_anchor] = anchor_node
	
	# For each edge in the pattern involving the pattern anchor
	for pattern_edge_idx in range(pattern.num_hyperedges):
		var pattern_edge_nodes = pattern.get_hyperedge_nodes(pattern_edge_idx)
		if pattern_anchor in pattern_edge_nodes:
			# Look for a matching edge in the actual graph
			var found_match = false
			for graph_edge_idx in range(num_hyperedges):
				var graph_edge_nodes = get_hyperedge_nodes(graph_edge_idx)
				if anchor_node in graph_edge_nodes and graph_edge_nodes.size() == pattern_edge_nodes.size():
					# Try to extend the node mapping
					var extended_mapping = node_mapping.duplicate()
					var mapping_valid = true
					
					# Map pattern nodes to graph nodes
					for i in range(pattern_edge_nodes.size()):
						var pattern_node = pattern_edge_nodes[i]
						var graph_node = graph_edge_nodes[i]
						
						if pattern_node in extended_mapping:
							# Check consistency
							if extended_mapping[pattern_node] != graph_node:
								# Try different permutation
								continue
						else:
							# Add new mapping
							extended_mapping[pattern_node] = graph_node
					
					# If mapping is consistent, we found a match
					if mapping_valid:
						node_mapping = extended_mapping
						found_match = true
						break
			
			if not found_match:
				return {}  # Pattern doesn't match
	
	return node_mapping

# Remove edges that were matched by the pattern
func _remove_matched_pattern(pattern: HypergraphLogic, node_mapping: Dictionary):
	# For each edge in the pattern, find and remove the corresponding edge in the graph
	for pattern_edge_idx in range(pattern.num_hyperedges):
		var pattern_edge_nodes = pattern.get_hyperedge_nodes(pattern_edge_idx)
		
		# Map pattern nodes to actual graph nodes
		var target_edge_nodes = []
		for pattern_node in pattern_edge_nodes:
			if pattern_node in node_mapping:
				target_edge_nodes.append(node_mapping[pattern_node])
		
		# Find and remove this edge in the graph
		for graph_edge_idx in range(num_hyperedges - 1, -1, -1):
			var graph_edge_nodes = get_hyperedge_nodes(graph_edge_idx)
			if _arrays_match_unordered(graph_edge_nodes, target_edge_nodes):
				_remove_hyperedge(graph_edge_idx)
				break

# Add RHS pattern around the anchor
func _add_rhs_pattern(rhs: HypergraphLogic, anchor_node: int, rhs_anchor: int, _lhs_mapping: Dictionary):
	# Create mapping for RHS nodes
	var rhs_mapping = {}
	rhs_mapping[rhs_anchor] = anchor_node
	
	# For nodes in RHS that aren't the anchor, we need to create new nodes or reuse existing ones
	var next_available_node = num_nodes
	
	for rhs_edge_idx in range(rhs.num_hyperedges):
		var rhs_edge_nodes = rhs.get_hyperedge_nodes(rhs_edge_idx)
		var new_edge_nodes = []
		
		for rhs_node in rhs_edge_nodes:
			if rhs_node in rhs_mapping:
				new_edge_nodes.append(rhs_mapping[rhs_node])
			else:
				# Create new node
				rhs_mapping[rhs_node] = next_available_node
				new_edge_nodes.append(next_available_node)
				next_available_node += 1
				
				# Expand the matrix if we need more nodes
				if next_available_node > num_nodes:
					_add_new_node()
		
		# Check for duplicate edges before adding
		var edge_already_exists = false
		for existing_edge_idx in range(num_hyperedges):
			var existing_edge_nodes = get_hyperedge_nodes(existing_edge_idx)
			if _arrays_match_unordered(existing_edge_nodes, new_edge_nodes):
				edge_already_exists = true
				break
		
		if not edge_already_exists:
			add_hyperedge(new_edge_nodes)

# Helper function to check if two arrays contain the same elements (unordered)
func _arrays_match_unordered(arr1: Array, arr2: Array) -> bool:
	if arr1.size() != arr2.size():
		return false
	
	var arr1_sorted = arr1.duplicate()
	var arr2_sorted = arr2.duplicate()
	arr1_sorted.sort()
	arr2_sorted.sort()
	
	return arr1_sorted == arr2_sorted

# Add a new node to the hypergraph
func _add_new_node():
	# Add new row to incidence matrix
	var new_row = []
	for j in range(num_hyperedges):
		new_row.append(0)
	incidence_matrix.append(new_row)
	num_nodes += 1

func _remove_hyperedge(edge_idx: int):
	if edge_idx >= num_hyperedges:
		return
	
	# Remove column from incidence matrix
	for i in range(num_nodes):
		incidence_matrix[i].remove_at(edge_idx)
	num_hyperedges -= 1

# Generate random hyperedges for initial graph
# Generate random hyperedges for initial graph with guaranteed connectivity
func generate_random_hyperedges(num_nodes_param: int):
	# First, ensure all nodes are connected by creating a spanning tree
	_create_connected_spanning_tree(num_nodes_param)
	
	# Then add additional random hyperedges for complexity
	var additional_edges = max(1, num_nodes_param - 4)  # Add some extra edges
	for i in range(additional_edges):
		var edge_size = randi() % 3 + 2  # 2 to 4 nodes per hyperedge
		var edge_nodes = []
		for j in range(edge_size):
			var node_idx = randi() % num_nodes_param
			if node_idx not in edge_nodes:
				edge_nodes.append(node_idx)
		if edge_nodes.size() >= 2:
			add_hyperedge(edge_nodes)

# Create a connected spanning tree to ensure all nodes are reachable
func _create_connected_spanning_tree(num_nodes_param: int):
	if num_nodes_param < 2:
		return
	
	print("Creating connected spanning tree for ", num_nodes_param, " nodes")
	
	# Create a simple chain to connect all nodes
	for i in range(num_nodes_param - 1):
		add_hyperedge([i, i + 1])
	
	# Add one more edge to create a more interesting structure (triangle with first 3 nodes)
	if num_nodes_param >= 3:
		add_hyperedge([0, 1, 2])
	
	# Connect the last node to an earlier node to prevent it from being isolated
	if num_nodes_param >= 4:
		add_hyperedge([num_nodes_param - 1, 0])

# Create a simple rewrite rule
static func create_rule(lhs_nodes: int, lhs_edges: Array, rhs_nodes: int, rhs_edges: Array) -> Dictionary:
	var lhs = HypergraphLogic.new(lhs_nodes, 0)
	for edge in lhs_edges:
		lhs.add_hyperedge(edge)
	
	var rhs = HypergraphLogic.new(rhs_nodes, 0)
	for edge in rhs_edges:
		rhs.add_hyperedge(edge)
	
	return {"lhs": lhs, "rhs": rhs}

func print_matrix():
	print("Incidence Matrix (%d nodes, %d hyperedges):" % [num_nodes, num_hyperedges])
	for i in range(num_nodes):
		print("Node %d: %s" % [i, str(incidence_matrix[i])])
