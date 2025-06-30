extends Node3D

@export var start_node: Node3D
@export var end_node: Node3D
@export var node_radius: float = 0.5  # Adjust based on the radius of the node spheres

func _ready():
	_update_edge()

func _process(_delta):
	_update_edge()

func _update_edge():
	if start_node and end_node:
		var start_pos = start_node.global_transform.origin
		var end_pos = end_node.global_transform.origin
		var direction = end_pos - start_pos
		var distance = direction.length()

		# Adjust positions to connect node surfaces rather than centers
		direction = direction.normalized()
		var adjusted_start_pos = start_pos + direction * node_radius
		var adjusted_end_pos = end_pos - direction * node_radius
		var adjusted_distance = (adjusted_end_pos - adjusted_start_pos).length()

		# Position the edge at the midpoint between adjusted positions
		global_transform.origin = (adjusted_start_pos + adjusted_end_pos) * 0.5

		# Orient the edge to look along the connection direction
		look_at(adjusted_end_pos, Vector3.UP)

		# Scale the tube to fit the distance between node surfaces
		# The default cylinder mesh has height 2, so we scale Z by half the distance
		scale = Vector3(1, 1, adjusted_distance * 0.5)
