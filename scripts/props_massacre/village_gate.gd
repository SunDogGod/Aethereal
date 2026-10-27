@tool
extends "res://scripts/props_massacre/village_prop_base.gd"
## An estate gate (a small roofed gate, like a farmhouse's): two heavy timber posts set in the
## wall ends, a tie beam and a lintel, a little gable roof of round tiles, two paper lanterns
## under it, and the two plank leaves swung open flat against the outside of the wall.
## Origin on the ground in the middle of the gap; the wall runs along local X, the outside of the
## estate is +Z. Width = the gap; Wall height and Wall thickness = the estate wall's.
## Walk-through (the posts sit inside the wall ends, which already collide).

const Roof := preload("res://scripts/props_massacre/roof_kit.gd")

@export var width := 3.0:
	set(value):
		width = value
		_rebuild()
@export var wall_height := 2.6:
	set(value):
		wall_height = value
		_rebuild()
@export var wall_thickness := 0.4:
	set(value):
		wall_thickness = value
		_rebuild()


func _build() -> void:
	var hw := width * 0.5
	var t := wall_thickness
	var post_h := wall_height + 1.1
	for sx: float in [-1.0, 1.0]:
		pm.box(M.timber, Vector3(0.32, post_h, t + 0.12), at(sx * (hw + 0.14), post_h * 0.5, 0))
		pm.box(M.stone, Vector3(0.44, 0.3, t + 0.2), at(sx * (hw + 0.14), 0.15, 0))
		# A leaf, opened flat against the outside face of the wall.
		var leaf := hw - 0.05
		var lx: float = sx * (hw + 0.3 + leaf * 0.5)
		pm.box(M.plank, Vector3(leaf, wall_height - 0.2, 0.07), at(lx, (wall_height - 0.2) * 0.5 + 0.08, t * 0.5 + 0.075))
		for y: float in [0.45, wall_height * 0.5, wall_height - 0.5]:
			pm.box(M.timber, Vector3(leaf, 0.12, 0.05), at(lx, y, t * 0.5 + 0.135))
		pm.cyl(M.iron, 0.05, 0.05, 0.03, at(sx * (hw + 0.3 + leaf * 0.8), 1.1, t * 0.5 + 0.175, Basis(Vector3.RIGHT, PI * 0.5)), 6)
	# The lintel and the tie beam above it.
	var beam_y := wall_height + 0.25
	pm.box(M.timber, Vector3(width + 0.9, 0.24, t + 0.06), at(0, beam_y, 0))
	pm.box(M.timber, Vector3(width + 0.5, 0.16, 0.2), at(0, wall_height - 0.2, 0))
	for k in 2:  # struts between them
		pm.box(M.timber, Vector3(0.12, 0.3, 0.12), at((k - 0.5) * width * 0.5, wall_height + 0.0, 0))
	var mats := {roof = M.clay, ridge = M.ridge, timber = M.timber, gable = M.plaster}
	Roof.gable(pm, mats, Transform3D(), width + 0.6, t + 0.4, beam_y + 0.12, 32.0, Vector2(0.55, 0.55), 0.3)
	# Two paper lanterns on arms off the posts, outside, clear of the opening.
	for sx: float in [-1.0, 1.0]:
		var c := Vector3(sx * (hw + 0.14), wall_height - 0.1, t * 0.5 + 0.36)
		pm.box(M.timber, Vector3(0.07, 0.07, 0.42), at(c.x, wall_height + 0.42, t * 0.5 + 0.19))
		pm.box(M.timber, Vector3(0.02, 0.3, 0.02), at(c.x, wall_height + 0.27, c.z))
		pm.cyl(M.red_paper if variant % 2 == 0 else M.lit, 0.17, 0.17, 0.42, at(c.x, c.y, c.z), 8)
		pm.cyl(M.timber, 0.12, 0.12, 0.05, at(c.x, c.y + 0.23, c.z), 8)
		pm.cyl(M.timber, 0.12, 0.12, 0.05, at(c.x, c.y - 0.23, c.z), 8)
	# A low stone sill (walk-through: no collision, so no lip to climb).
	pm.box(M.stone, Vector3(width - 0.1, 0.09, t + 0.3), at(0, 0.045, 0))
