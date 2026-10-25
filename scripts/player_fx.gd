class_name PlayerFx
extends RefCounted
## Little visual effects on Aeneas, called through the Player (flash, shockwave_ring).


## A brief tint on his whole model (hit = red, parry = white).
static func flash(player: Player, color: Color) -> void:
	for part in player.model.find_children("*", "MeshInstance3D"):
		var mat: Material = part.get_active_material(0)
		if mat is ShaderMaterial:
			var copy: ShaderMaterial = mat.duplicate()
			var base: Color = mat.get_shader_parameter("albedo_color") if mat.get_shader_parameter("albedo_color") != null else Color.WHITE
			copy.set_shader_parameter("albedo_color", color)
			part.material_override = copy
			var tween := player.create_tween()
			tween.tween_property(copy, "shader_parameter/albedo_color", base, 0.25)
			tween.tween_callback(func() -> void: part.material_override = null)


## The eruption's visual: a dark ring that races out along the floor.
static func shockwave_ring(player: Player, reach: float) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	mesh.rings = 16
	mesh.ring_segments = 4
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ps1_surface.gdshader")
	mat.set_shader_parameter("albedo_color", Color(0.1, 0.05, 0.2))
	mat.set_shader_parameter("emission_color", Color(0.5, 0.3, 1.0))
	mat.set_shader_parameter("emission_energy", 2.0)
	mesh.material = mat
	ring.mesh = mesh
	player.get_parent().add_child(ring)
	ring.global_position = player.global_position + Vector3.UP * 0.15
	var tween := player.create_tween()
	tween.tween_property(ring, "scale", Vector3(reach, 1.0, reach), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ring.queue_free)
