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


## The eruption's visual on each slam: a smaller burst of raw aether round him (the same burst the
## hall's eruption opens with, scripts/vfx/hall_burst.gd). `reach` is kept for the callers.
static func shockwave_ring(player: Player, _reach: float) -> void:
	load("res://scripts/vfx/hall_burst.gd").burst(player, 0.4)
