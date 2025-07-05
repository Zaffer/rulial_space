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
	
	# Remove hyperedges that match LHS pattern around anchor_node
	var removed_edges = _remove_pattern_at_node(lhs, anchor_node, lhs_anchor)
	if removed_edges.is_empty():
		return false
	
	# Add hyperedges from RHS pattern around anchor_node
	_add_pattern_at_node(rhs, anchor_node, rhs_anchor)
	
	return true

func _remove_pattern_at_node(pattern: HypergraphLogic, anchor_node: int, pattern_anchor: int) -> Array:
	var removed_edges = []
	
	# Find hyperedges involving the anchor node that match the pattern
	for edge_idx in range(num_hyperedges - 1, -1, -1):  # Reverse to avoid index issues
		var edge_nodes = get_hyperedge_nodes(edge_idx)
		if anchor_node in edge_nodes:
			# Check if this edge matches any edge in the pattern involving pattern_anchor
			for pattern_edge_idx in range(pattern.num_hyperedges):
				var pattern_edge_nodes = pattern.get_hyperedge_nodes(pattern_edge_idx)
				if pattern_anchor in pattern_edge_nodes:
					# Simple match: same number of nodes
					if edge_nodes.size() == pattern_edge_nodes.size():
						_remove_hyperedge(edge_idx)
						removed_edges.append(edge_idx)
						break
	
	return removed_edges

func _add_pattern_at_node(pattern: HypergraphLogic, anchor_node: int, pattern_anchor: int):
	# Add hyperedges from pattern, mapping pattern_anchor to anchor_node
	for pattern_edge_idx in range(pattern.num_hyperedges):
		var pattern_edge_nodes = pattern.get_hyperedge_nodes(pattern_edge_idx)
		if pattern_anchor in pattern_edge_nodes:
			# Create new edge with anchor_node replacing pattern_anchor
			var new_edge_nodes = []
			for p_node in pattern_edge_nodes:
				if p_node == pattern_anchor:
					new_edge_nodes.append(anchor_node)
				else:
					# For other nodes in pattern, use nearby nodes or create new ones
					var offset = p_node - pattern_anchor
					var target_node = anchor_node + offset
					if target_node >= 0 and target_node < num_nodes:
						new_edge_nodes.append(target_node)
					else:
						new_edge_nodes.append(anchor_node)  # Fallback to anchor
			
			# Remove duplicates and add edge if valid
			var unique_nodes = []
			for node in new_edge_nodes:
				if node not in unique_nodes:
					unique_nodes.append(node)
			
			if unique_nodes.size() >= 2:
				add_hyperedge(unique_nodes)

func _remove_hyperedge(edge_idx: int):
	if edge_idx >= num_hyperedges:
		return
	
	# Remove column from incidence matrix
	for i in range(num_nodes):
		incidence_matrix[i].remove_at(edge_idx)
	num_hyperedges -= 1

# Generate random hyperedges for initial graph
func generate_random_hyperedges(num_nodes_param: int):
	var num_hyperedges_to_create = max(1, num_nodes_param - 2)
	for i in range(num_hyperedges_to_create):
		var edge_size = randi() % 3 + 2  # 2 to 4 nodes per hyperedge
		var edge_nodes = []
		for j in range(edge_size):
			var node_idx = randi() % num_nodes_param
			if node_idx not in edge_nodes:
				edge_nodes.append(node_idx)
		if edge_nodes.size() >= 2:
			add_hyperedge(edge_nodes)

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
