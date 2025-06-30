extends Resource
class_name LaserMaterial

static func create_purple_laser_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.PURPLE
	material.emission_enabled = true
	material.emission = Color.PURPLE * 2.0  # Bright glow
	material.flags_unshaded = true
	material.flags_transparent = true
	material.albedo_color.a = 0.7  # Semi-transparent
	return material
