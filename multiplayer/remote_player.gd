extends Node3D
class_name RemotePlayer

var spaceship_instance: MeshInstance3D

func _ready():
	# Create a visual spaceship for the remote player
	spaceship_instance = MeshInstance3D.new()
	var spaceship_script = preload("res://spaceship.gd")
	spaceship_instance.set_script(spaceship_script)
	add_child(spaceship_instance)
	
	# Make it visually distinct with a different color
	# Wait a frame for the spaceship to initialize its material
	call_deferred("_customize_appearance")

func _customize_appearance():
	# Change the spaceship color to distinguish from local player
	if spaceship_instance and spaceship_instance.get_surface_override_material_count() > 0:
		var material = spaceship_instance.get_surface_override_material(0).duplicate()
		material.albedo_color = Color.CYAN
		material.emission = Color.BLUE * 0.3
		spaceship_instance.set_surface_override_material(0, material)

func update_position(position: Vector3, rotation: Vector3):
	global_position = position
	global_rotation = rotation
