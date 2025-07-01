extends MeshInstance3D

func _ready():
	# Create a tetrahedron mesh
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Tetrahedron vertices
	var vertices = PackedVector3Array([
		Vector3(0, 1, 0),      # Top vertex
		Vector3(-0.5, 0, 0.5), # Bottom front left
		Vector3(0.5, 0, 0.5),  # Bottom front right
		Vector3(0, 0, -0.5)    # Bottom back
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
	mesh = array_mesh
	
	# Create a material that responds to lighting
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE_RED
	material.metallic = 0.8
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = Color.DARK_RED * 0.3  # Slight glow
	set_surface_override_material(0, material)
	
	# Add wireframe edges
	create_wireframe_edges()
	
	# Add gun barrel
	create_gun_barrel()
	
	# Add laser beam
	create_laser_beam()

func create_wireframe_edges():
	# Define the edges of the tetrahedron (vertex pairs)
	var edge_pairs = [
		# Edges from top vertex (0) to bottom vertices
		[Vector3(0, 1, 0), Vector3(-0.5, 0, 0.5)],  # 0-1
		[Vector3(0, 1, 0), Vector3(0.5, 0, 0.5)],   # 0-2
		[Vector3(0, 1, 0), Vector3(0, 0, -0.5)],    # 0-3
		# Edges of bottom triangle
		[Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5)],  # 1-2
		[Vector3(0.5, 0, 0.5), Vector3(0, 0, -0.5)],    # 2-3
		[Vector3(0, 0, -0.5), Vector3(-0.5, 0, 0.5)]    # 3-1
	]
	
	# Create edge lines
	for i in range(edge_pairs.size()):
		var edge_line = MeshInstance3D.new()
		add_child(edge_line)
		
		# Create line mesh
		var line_mesh = ArrayMesh.new()
		var line_arrays = []
		line_arrays.resize(Mesh.ARRAY_MAX)
		
		var line_vertices = PackedVector3Array([
			edge_pairs[i][0],
			edge_pairs[i][1]
		])
		
		line_arrays[Mesh.ARRAY_VERTEX] = line_vertices
		line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)
		edge_line.mesh = line_mesh
		
		# Create glowing edge material
		var edge_material = StandardMaterial3D.new()
		edge_material.flags_unshaded = true
		edge_material.vertex_color_use_as_albedo = true
		edge_material.albedo_color = Color.CYAN
		edge_material.emission_enabled = true
		edge_material.emission = Color.CYAN * 1.5  # Bright cyan glow
		edge_material.flags_transparent = true
		edge_material.no_depth_test = false
		edge_material.grow_amount = 0.01  # Slight thickness
		edge_line.set_surface_override_material(0, edge_material)

func create_gun_barrel():
	# Create a bullet as the gun - same as projectiles
	var gun_bullet = MeshInstance3D.new()
	add_child(gun_bullet)
	
	# Use the EXACT same mesh as projectiles
	var bullet_mesh = ArrayMesh.new()
	var bullet_arrays = []
	bullet_arrays.resize(Mesh.ARRAY_MAX)
	
	# Same vertices as projectile.gd
	var bullet_vertices = PackedVector3Array([
		Vector3(0, 0.1, 0),      # Top vertex
		Vector3(-0.05, 0, 0.05), # Bottom front left
		Vector3(0.05, 0, 0.05),  # Bottom front right
		Vector3(0, 0, -0.05)     # Bottom back
	])
	
	# Same faces as projectile.gd
	var bullet_indices = PackedInt32Array([
		0, 1, 2,  # Front face
		0, 3, 1,  # Left face
		0, 2, 3,  # Right face
		1, 3, 2   # Bottom face
	])
	
	bullet_arrays[Mesh.ARRAY_VERTEX] = bullet_vertices
	bullet_arrays[Mesh.ARRAY_INDEX] = bullet_indices
	
	bullet_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bullet_arrays)
	gun_bullet.mesh = bullet_mesh
	
	# Position to the left of spaceship (bigger size)
	gun_bullet.position = Vector3(-0.8, 0, 0.3)
	gun_bullet.scale = Vector3(2.0, 2.0, 2.0)  # Make it bigger
	
	# Same material as projectiles
	var bullet_material = StandardMaterial3D.new()
	bullet_material.albedo_color = Color.PURPLE
	bullet_material.emission_enabled = true
	bullet_material.emission = Color.PURPLE
	bullet_material.flags_unshaded = true
	gun_bullet.set_surface_override_material(0, bullet_material)
	
	# Store reference for bullet spawning
	set_meta("gun_barrel", gun_bullet)

func create_laser_beam():
	# Create a simple purple beam extending forward from spaceship
	var beam = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.1, 0.1, 100.0)  # 10 units long, visible beam
	beam.mesh = box
	
	# Purple material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.PURPLE
	material.emission_enabled = true
	material.emission = Color.PURPLE * 2.0
	material.flags_unshaded = true
	beam.set_surface_override_material(0, material)
	
	# Position it extending forward TOWARDS the camera (negative Z)
	beam.position = Vector3(0, 0, -5.0)  # 5 units FORWARD towards camera
	add_child(beam)
	
	# Store reference
	set_meta("laser_beam", beam)

func gun_kickback():
	# Animate gun kickback when shooting
	var gun = get_meta("gun_barrel", null)
	if gun:
		var original_pos = gun.position
		# Quick kick back
		gun.position = original_pos + Vector3(0.1, 0, -0.2)  # Move back and up slightly
		
		# Create a tween to return to original position
		var tween = create_tween()
		tween.tween_property(gun, "position", original_pos, 0.15)
		tween.tween_callback(func(): pass)  # Dummy callback to complete tween

func get_gun_barrel_position() -> Vector3:
	var gun = get_meta("gun_barrel", null)
	if gun:
		return gun.global_position
	else:
		return global_position
