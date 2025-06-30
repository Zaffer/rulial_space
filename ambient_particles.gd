extends GPUParticles3D

func _ready():
	# Set up the particle system
	emitting = true
	amount = 200  # Dense star field
	lifetime = 3.0  
	visibility_aabb = AABB(Vector3(-300, -300, -300), Vector3(600, 600, 600))
	
	# Create process material
	var material = ParticleProcessMaterial.new()
	
	# Emission settings
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(20, 20, 20)  # Spread them out
	
	# Make particles static (no movement)
	material.direction = Vector3(0, 0, 0)
	material.initial_velocity_min = 0.0
	material.initial_velocity_max = 0.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.05  # Small particles
	material.scale_max = 0.1   # Small max size
	
	# Simple solid color
	material.color = Color(1.0, 1.0, 1.0, 1.0)  # Solid white
	
	# Set the material
	process_material = material
	
	# Use minimal mesh for efficiency
	var point_mesh = SphereMesh.new()
	point_mesh.radius = 0.025  # Tiny radius
	point_mesh.height = 0.05   # Tiny height  
	point_mesh.radial_segments = 3  # Minimum segments
	point_mesh.rings = 1           # Minimum rings
	draw_pass_1 = point_mesh
	
	# Create simple unshaded material
	var particle_material = StandardMaterial3D.new()
	particle_material.flags_unshaded = true
	particle_material.vertex_color_use_as_albedo = true  # Use vertex colors from particles
	particle_material.emission_enabled = true
	particle_material.emission = Color(0.6, 0.8, 1.0, 1.0)  # Soft blue-white
	particle_material.emission_energy = 1.2
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material_override = particle_material
