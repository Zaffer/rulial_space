class_name RewritingRules
extends RefCounted

# Collection of predefined rewrite rules for the hypergraph

# Triangle to edge: simplifies a 3-node hyperedge to a 2-node edge
static func triangle_to_edge() -> Dictionary:
	return HypergraphLogic.create_rule(
		3, [[0, 1, 2]],  # LHS: 3 nodes in one hyperedge
		2, [[0, 1]]      # RHS: 2 nodes in one hyperedge
	)

# Edge to triangle: expands a 2-node edge to a 3-node hyperedge
static func edge_to_triangle() -> Dictionary:
	return HypergraphLogic.create_rule(
		2, [[0, 1]],     # LHS: 2 nodes in one hyperedge
		3, [[0, 1, 2]]   # RHS: 3 nodes in one hyperedge
	)

# Node isolation: removes all connections from a node
static func isolate_node() -> Dictionary:
	return HypergraphLogic.create_rule(
		2, [[0, 1]],     # LHS: any edge involving the node
		1, []            # RHS: no edges (isolated node)
	)

# Star formation: connects a node to multiple neighbors
static func create_star() -> Dictionary:
	return HypergraphLogic.create_rule(
		1, [],           # LHS: isolated node
		4, [[0, 1], [0, 2], [0, 3]]  # RHS: star pattern
	)

# Duplicate node: creates a new node connected to the original
static func duplicate_node() -> Dictionary:
	return HypergraphLogic.create_rule(
		1, [],           # LHS: single node (no edges required)
		2, [[0, 1]]      # RHS: original node + new node connected by edge
	)

# Apply a rule by name to a hypergraph at a specific node
static func apply_rule(hypergraph: HypergraphLogic, rule_name: String, anchor_node: int) -> bool:
	var rule = get_rule_by_name(rule_name)
	if rule.is_empty():
		print("Unknown rule: ", rule_name)
		return false
	
	var success = hypergraph.apply_rewrite_rule_at_node(rule.lhs, rule.rhs, anchor_node)
	if success:
		print("Applied rule '", rule_name, "' at node ", anchor_node)
	else:
		print("Rule '", rule_name, "' could not be applied at node ", anchor_node)
	
	return success

# Get rule by name
static func get_rule_by_name(rule_name: String) -> Dictionary:
	match rule_name:
		"triangle_to_edge":
			return triangle_to_edge()
		"edge_to_triangle":
			return edge_to_triangle()
		"isolate_node":
			return isolate_node()
		"create_star":
			return create_star()
		"duplicate_node":
			return duplicate_node()
		_:
			return {}

# Get list of all available rule names
static func get_all_rule_names() -> Array:
	return ["triangle_to_edge", "edge_to_triangle", "isolate_node", "create_star", "duplicate_node"]
