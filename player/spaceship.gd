extends MeshInstance3D

func _ready():
	# Create a rhombic hexecontahedron mesh
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Generate vertices and faces for rhombic hexecontahedron
	var mesh_data = generate_rhombic_hexecontahedron()
	var vertices = mesh_data.vertices
	var indices = mesh_data.indices
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	# Calculate normals for proper lighting
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	
	# Initialize all normals to zero
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO
	
	# Calculate face normals and accumulate vertex normals
	for i in range(0, indices.size(), 3):
		var i1 = indices[i]
		var i2 = indices[i + 1]
		var i3 = indices[i + 2]
		
		var v1 = vertices[i1]
		var v2 = vertices[i2]
		var v3 = vertices[i3]
		
		# Calculate face normal using cross product
		var edge1 = v2 - v1
		var edge2 = v3 - v1
		var face_normal = edge1.cross(edge2).normalized()
		
		# Accumulate normals for each vertex
		normals[i1] += face_normal
		normals[i2] += face_normal
		normals[i3] += face_normal
	
	# Normalize all vertex normals
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	
	arrays[Mesh.ARRAY_NORMAL] = normals
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh
	
	# Create a material that responds to lighting
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE_RED
	material.metallic = 0.8
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = Color.DARK_RED * 0.3  # Slight glow
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Make double-sided
	material.flags_do_not_use_vertex_normals = false  # Use calculated normals
	set_surface_override_material(0, material)
	
	# Add wireframe edges
	create_wireframe_edges()
	
	# Add gun barrel
	create_gun_barrel()
	
	# Add laser beam
	create_laser_beam()

func create_wireframe_edges():
	# Get the mesh data for edge detection
	var mesh_data = generate_rhombic_hexecontahedron()
	var vertices = mesh_data.vertices
	var indices = mesh_data.indices
	
	# Create edges from triangular faces
	var edge_set = {}
	
	# Process triangular faces to find unique edges
	for i in range(0, indices.size(), 3):
		var v1 = indices[i]
		var v2 = indices[i + 1]
		var v3 = indices[i + 2]
		
		# Add the three edges of this triangle
		var edges = [
			[min(v1, v2), max(v1, v2)],
			[min(v2, v3), max(v2, v3)],
			[min(v3, v1), max(v3, v1)]
		]
		
		for edge in edges:
			var edge_key = str(edge[0]) + "_" + str(edge[1])
			edge_set[edge_key] = [edge[0], edge[1]]
	
	# Create edge lines from unique edges
	for edge_key in edge_set:
		var edge = edge_set[edge_key]
		var v1_idx = edge[0]
		var v2_idx = edge[1]
		
		# Skip if indices are out of bounds
		if v1_idx >= vertices.size() or v2_idx >= vertices.size():
			continue
			
		var edge_line = MeshInstance3D.new()
		add_child(edge_line)
		
		# Create line mesh
		var line_mesh = ArrayMesh.new()
		var line_arrays = []
		line_arrays.resize(Mesh.ARRAY_MAX)
		
		var line_vertices = PackedVector3Array([
			vertices[v1_idx],
			vertices[v2_idx]
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
	box.size = Vector3(0.1, 0.1, 50.0)  # 50 units long, visible beam
	beam.mesh = box
	
	# Purple material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.PURPLE
	material.emission_enabled = true
	material.emission = Color.PURPLE * 2.0
	material.flags_unshaded = true
	beam.set_surface_override_material(0, material)
	
	# Position it starting from gun barrel and extending forward (positive Z)
	# Gun barrel is at (-0.8, 0, 0.3), laser should extend from there forward
	beam.position = Vector3(-0.8, 0, -24.7)  # Start at gun barrel + half laser length forward
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

func generate_rhombic_hexecontahedron():
	# Generate vertices for a true rhombic hexecontahedron
	# This polyhedron has 60 rhombic faces and 62 vertices
	# Scale factor to keep the spaceship at a reasonable size
	var size_scale = 0.3
	
	# True rhombic hexecontahedron vertices (62 vertices)
	var vertices := PackedVector3Array([
		Vector3( 0.000000000,  0.000000000,  1.701301617) * size_scale,
		Vector3( 0.000000000,  0.000000000, -1.701301617) * size_scale,
		Vector3( 1.701301617,  0.000000000,  0.000000000) * size_scale,
		Vector3(-1.701301617,  0.000000000,  0.000000000) * size_scale,
		Vector3( 0.000000000,  1.701301617,  0.000000000) * size_scale,
		Vector3( 0.000000000, -1.701301617,  0.000000000) * size_scale,
		Vector3( 0.000000000,  0.850650808,  2.227032729) * size_scale,
		Vector3( 0.000000000,  0.850650808, -2.227032729) * size_scale,
		Vector3( 0.000000000, -0.850650808,  2.227032729) * size_scale,
		Vector3( 0.000000000, -0.850650808, -2.227032729) * size_scale,
		Vector3( 2.227032729,  0.000000000,  0.850650808) * size_scale,
		Vector3( 2.227032729,  0.000000000, -0.850650808) * size_scale,
		Vector3(-2.227032729,  0.000000000,  0.850650808) * size_scale,
		Vector3(-2.227032729,  0.000000000, -0.850650808) * size_scale,
		Vector3( 0.850650808,  2.227032729,  0.000000000) * size_scale,
		Vector3( 0.850650808, -2.227032729,  0.000000000) * size_scale,
		Vector3(-0.850650808,  2.227032729,  0.000000000) * size_scale,
		Vector3(-0.850650808, -2.227032729,  0.000000000) * size_scale,
		Vector3( 0.525731112,  0.000000000,  0.850650808) * size_scale,
		Vector3( 0.525731112,  0.000000000, -0.850650808) * size_scale,
		Vector3(-0.525731112,  0.000000000,  0.850650808) * size_scale,
		Vector3(-0.525731112,  0.000000000, -0.850650808) * size_scale,
		Vector3( 0.850650808,  0.525731112,  0.000000000) * size_scale,
		Vector3( 0.850650808, -0.525731112,  0.000000000) * size_scale,
		Vector3(-0.850650808,  0.525731112,  0.000000000) * size_scale,
		Vector3(-0.850650808, -0.525731112,  0.000000000) * size_scale,
		Vector3( 0.000000000,  0.850650808,  0.525731112) * size_scale,
		Vector3( 0.000000000,  0.850650808, -0.525731112) * size_scale,
		Vector3( 0.000000000, -0.850650808,  0.525731112) * size_scale,
		Vector3( 0.000000000, -0.850650808, -0.525731112) * size_scale,
		Vector3( 0.525731112,  0.850650808,  1.376381920) * size_scale,
		Vector3( 0.525731112,  0.850650808, -1.376381920) * size_scale,
		Vector3( 0.525731112, -0.850650808,  1.376381920) * size_scale,
		Vector3( 0.525731112, -0.850650808, -1.376381920) * size_scale,
		Vector3(-0.525731112,  0.850650808,  1.376381920) * size_scale,
		Vector3(-0.525731112,  0.850650808, -1.376381920) * size_scale,
		Vector3(-0.525731112, -0.850650808,  1.376381920) * size_scale,
		Vector3(-0.525731112, -0.850650808, -1.376381920) * size_scale,
		Vector3( 1.376381920,  0.525731112,  0.850650808) * size_scale,
		Vector3( 1.376381920,  0.525731112, -0.850650808) * size_scale,
		Vector3( 1.376381920, -0.525731112,  0.850650808) * size_scale,
		Vector3( 1.376381920, -0.525731112, -0.850650808) * size_scale,
		Vector3(-1.376381920,  0.525731112,  0.850650808) * size_scale,
		Vector3(-1.376381920,  0.525731112, -0.850650808) * size_scale,
		Vector3(-1.376381920, -0.525731112,  0.850650808) * size_scale,
		Vector3(-1.376381920, -0.525731112, -0.850650808) * size_scale,
		Vector3( 0.850650808,  1.376381920,  0.525731112) * size_scale,
		Vector3( 0.850650808,  1.376381920, -0.525731112) * size_scale,
		Vector3( 0.850650808, -1.376381920,  0.525731112) * size_scale,
		Vector3( 0.850650808, -1.376381920, -0.525731112) * size_scale,
		Vector3(-0.850650808,  1.376381920,  0.525731112) * size_scale,
		Vector3(-0.850650808,  1.376381920, -0.525731112) * size_scale,
		Vector3(-0.850650808, -1.376381920,  0.525731112) * size_scale,
		Vector3(-0.850650808, -1.376381920, -0.525731112) * size_scale,
		Vector3( 1.376381920,  1.376381920,  1.376381920) * size_scale,
		Vector3( 1.376381920,  1.376381920, -1.376381920) * size_scale,
		Vector3( 1.376381920, -1.376381920,  1.376381920) * size_scale,
		Vector3( 1.376381920, -1.376381920, -1.376381920) * size_scale,
		Vector3(-1.376381920,  1.376381920,  1.376381920) * size_scale,
		Vector3(-1.376381920,  1.376381920, -1.376381920) * size_scale,
		Vector3(-1.376381920, -1.376381920,  1.376381920) * size_scale,
		Vector3(-1.376381920, -1.376381920, -1.376381920) * size_scale
	])
	
	# True rhombic hexecontahedron triangular faces (120 triangles from 60 rhombi)
	var indices := PackedInt32Array([
		18, 0, 8, 18, 8, 32, 18, 32, 56, 18, 56, 40,
		18, 40, 10, 18, 10, 38, 18, 38, 54, 18, 54, 30,
		18, 30, 6, 18, 6, 0, 19, 1, 7, 19, 7, 31,
		19, 31, 55, 19, 55, 39, 19, 39, 11, 19, 11, 41,
		19, 41, 57, 19, 57, 33, 19, 33, 9, 19, 9, 1,
		20, 0, 6, 20, 6, 34, 20, 34, 58, 20, 58, 42,
		20, 42, 12, 20, 12, 44, 20, 44, 60, 20, 60, 36,
		20, 36, 8, 20, 8, 0, 21, 1, 9, 21, 9, 37,
		21, 37, 61, 21, 61, 45, 21, 45, 13, 21, 13, 43,
		21, 43, 59, 21, 59, 35, 21, 35, 7, 21, 7, 1,
		22, 2, 11, 22, 11, 39, 22, 39, 55, 22, 55, 47,
		22, 47, 14, 22, 14, 46, 22, 46, 54, 22, 54, 38,
		22, 38, 10, 22, 10, 2, 23, 2, 10, 23, 10, 40,
		23, 40, 56, 23, 56, 48, 23, 48, 15, 23, 15, 49,
		23, 49, 57, 23, 57, 41, 23, 41, 11, 23, 11, 2,
		24, 3, 12, 24, 12, 42, 24, 42, 58, 24, 58, 50,
		24, 50, 16, 24, 16, 51, 24, 51, 59, 24, 59, 43,
		24, 43, 13, 24, 13, 3, 25, 3, 13, 25, 13, 45,
		25, 45, 61, 25, 61, 53, 25, 53, 17, 25, 17, 52,
		25, 52, 60, 25, 60, 44, 25, 44, 12, 25, 12, 3,
		26, 4, 16, 26, 16, 50, 26, 50, 58, 26, 58, 34,
		26, 34, 6, 26, 6, 30, 26, 30, 54, 26, 54, 46,
		26, 46, 14, 26, 14, 4, 27, 4, 14, 27, 14, 47,
		27, 47, 55, 27, 55, 31, 27, 31, 7, 27, 7, 35,
		27, 35, 59, 27, 59, 51, 27, 51, 16, 27, 16, 4,
		28, 5, 15, 28, 15, 48, 28, 48, 56, 28, 56, 32,
		28, 32, 8, 28, 8, 36, 28, 36, 60, 28, 60, 52,
		28, 52, 17, 28, 17, 5, 29, 5, 17, 29, 17, 53,
		29, 53, 61, 29, 61, 37, 29, 37, 9, 29, 9, 33,
		29, 33, 57, 29, 57, 49, 29, 49, 15, 29, 15, 5
	])
	
	return {"vertices": vertices, "indices": indices}
