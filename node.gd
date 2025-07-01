extends RigidBody3D

@export var connected_nodes: Array = []
@export var repulsion_strength: float = 10.0
@export var attraction_strength: float = 20.0
@export var anchor_strength: float = 100.0
@export var optimal_distance: float = 3.0

var is_anchor: bool = false
var external_attraction_force: Vector3 = Vector3.ZERO
var external_attraction_strength: float = 5.0

func _ready():
	add_to_group("nodes")
	# Use Godot's built-in damping
	linear_damp = 5.0
	angular_damp = 5.0
	
	# Set collision layer for proper interaction
	collision_layer = 1  # Layer 1 for nodes
	collision_mask = 7   # Collide with layers 1,2,4 (nodes, spaceship, projectiles)
	
	# Enable contact monitoring for collision detection
	contact_monitor = true
	max_contacts_reported = 10
	
	# Connect collision signal
	body_entered.connect(_on_collision)

func _process(_delta):
	# Visual feedback for anchor node
	var mesh_instance = get_node("MeshInstance3D")
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if is_anchor:
			# Make anchor node yellow
			material.albedo_color = Color.YELLOW
			material.emission = Color.YELLOW * 0.3
		else:
			# Normal blue color
			material.albedo_color = Color(0.2, 0.6, 1, 1)
			material.emission = Color(0.1, 0.3, 0.8, 1)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	apply_forces(state.get_step())

func apply_forces(_delta: float):
	# Apply external attraction force (from laser)
	if external_attraction_force.length() > 0:
		apply_central_force(external_attraction_force * external_attraction_strength)
		# Decay the external force over time
		external_attraction_force = external_attraction_force * 0.98

	# 1. Anchor force - keep anchor node at center
	if is_anchor:
		var center = Vector3.ZERO
		var direction_to_center = center - global_transform.origin
		var anchor_force = direction_to_center * anchor_strength
		apply_central_force(anchor_force)
	
	# 2. Forces between nodes
	for node in get_tree().get_nodes_in_group("nodes"):
		if node != self and node is RigidBody3D:
			var direction = node.global_transform.origin - global_transform.origin
			var distance = direction.length()
			
			if distance > 0.1:  # Avoid division by zero
				direction = direction.normalized()
				
				if node in connected_nodes:
					# Spring force - pull connected nodes to optimal distance
					var displacement = distance - optimal_distance
					var spring_force = direction * displacement * attraction_strength
					apply_central_force(spring_force)
				else:
					# Repulsion force - push unconnected nodes away
					var repulsion_force = direction * repulsion_strength / distance
					apply_central_force(-repulsion_force)
	
	# 3. External attraction force - for laser attraction
	if external_attraction_force != Vector3.ZERO:
		var external_direction = external_attraction_force.normalized()
		var external_distance = global_transform.origin.distance_to(external_attraction_force)
		var external_attraction = external_direction * (external_distance * external_attraction_strength)
		apply_central_force(external_attraction)

func _on_collision(body):
	# When spaceship or other physics bodies collide with this node
	if body != self:  # Don't react to self
		print("Node collision with: ", body.name)
		# The physics engine will handle the collision response automatically
		# You could add special effects here like particles, sounds, etc.

func apply_laser_attraction(laser_position: Vector3):
	# Apply attraction force towards the laser position
	var direction = laser_position - global_position
	if direction.length() > 0.1:
		external_attraction_force = direction.normalized()
