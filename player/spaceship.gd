extends MeshInstance3D

func _ready():
	# The mesh is now defined in the scene file as a BoxMesh
	print("Spaceship ready!")

func gun_kickback():
	# Animate gun kickback when shooting - now uses scene node
	var gun = get_node("GunBarrel")
	if gun:
		var original_pos = gun.position
		# Quick kick back
		gun.position = original_pos + Vector3(0.1, 0, -0.2)  # Move back and up slightly
		
		# Create a tween to return to original position
		var tween = create_tween()
		tween.tween_property(gun, "position", original_pos, 0.15)
		tween.tween_callback(func(): pass)  # Dummy callback to complete tween

func get_gun_barrel_position() -> Vector3:
	var gun = get_node("GunBarrel")
	if gun:
		return gun.global_position
	else:
		return global_position
