extends MeshInstance3D

func _ready():
	# The mesh data is already defined in the scene file
	# Just create the wireframe edges
	create_wireframe_edges()

func create_wireframe_edges():
	# Get the mesh data from the scene
	var array_mesh = mesh as ArrayMesh
	if not array_mesh or array_mesh.get_surface_count() == 0:
		print("No mesh data found")
		return
		
	var arrays = array_mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var indices = arrays[Mesh.ARRAY_INDEX]
	
	print("Creating wireframe from ", vertices.size(), " vertices and ", indices.size(), " indices")
	
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
		edge_material.albedo_color = Color.CYAN
		edge_material.emission_enabled = true
		edge_material.emission = Color.CYAN * 1.5
		edge_material.flags_transparent = true
		edge_line.set_surface_override_material(0, edge_material)

func gun_kickback():
	# Animate gun kickback when shooting
	var gun = get_node("GunBarrel")
	if gun:
		var original_pos = gun.position
		gun.position = original_pos + Vector3(0.1, 0, -0.2)
		
		var tween = create_tween()
		tween.tween_property(gun, "position", original_pos, 0.15)

func get_gun_barrel_position() -> Vector3:
	var gun = get_node("GunBarrel")
	if gun:
		return gun.global_position
	else:
		return global_position
