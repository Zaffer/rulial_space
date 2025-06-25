extends RigidBody3D

@export var speed := 20.0
@export var lifetime := 5.0

func _ready():
	# Create a tetrahedron mesh for the projectile
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Tetrahedron vertices (smaller scale)
	var vertices = PackedVector3Array([
		Vector3(0, 0.1, 0),      # Top vertex
		Vector3(-0.05, 0, 0.05), # Bottom front left
		Vector3(0.05, 0, 0.05),  # Bottom front right
		Vector3(0, 0, -0.05)     # Bottom back
	])
	
	# Tetrahedron faces (triangles)
	var indices = PackedInt32Array([
		# Front face
		0, 1, 2,
		# Left face
		0, 3, 1,
		# Right face
		0, 2, 3,
		# Bottom face
		1, 3, 2
	])
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	add_child(mesh_instance)
	
	# Create a simple glowing material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.PURPLE
	material.emission_enabled = true
	material.emission = Color.PURPLE
	material.flags_unshaded = true
	mesh_instance.set_surface_override_material(0, material)
	
	# Add collision shape (keep sphere for simple physics)
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.05
	collision_shape.shape = sphere_shape
	add_child(collision_shape)
	
	# Set physics properties
	gravity_scale = 0  # No gravity in space
	
	# Set collision layers to avoid spaceship interactions
	collision_layer = 4  # Layer 4 for projectiles
	collision_mask = 1   # Only collide with layer 1 (nodes)
	
	# Auto-destroy after lifetime
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_expired)
	add_child(timer)
	timer.start()

func launch(direction: Vector3):
	linear_velocity = direction * speed

func _on_lifetime_expired():
	queue_free()
