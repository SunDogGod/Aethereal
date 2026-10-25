@tool
extends Node3D
## An air-conditioning unit hung on a wall, with the short pipes a real one has: two
## refrigerant lines out of its side that bend into the wall through a cover plate, and a thin
## drain pipe down from its tray. The origin sits on the wall plane at the unit's middle; the wall
## is behind (-Z), the unit faces +Z (same frame as street_prop.gd's wall things). Variant
## changes the casing and which side the pipes leave from. Purely visual: no collision, so hang
## it above head height or tight to a wall.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	metal = preload("res://materials/metal_worn.tres"), plaster = preload("res://materials/white_plaster.tres"),
	rust = preload("res://materials/pipe_rust.tres"), vent = preload("res://materials/trim_vent_worn.tres"),
	rail = preload("res://materials/trim_rail_worn.tres"), dark = preload("res://materials/black_cube.tres"),
	rubber = preload("res://materials/rubber.tres"), copper = preload("res://materials/brass.tres"),
}
const SIZE := Vector3(0.9, 0.6, 0.36)
const STANDOFF := 0.06  # gap between the wall and the back of the unit (the brackets bridge it)

@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Metres the drain pipe hangs down below the unit (0 = no drain pipe).
@export var drain := 0.45:
	set(value):
		drain = value
		_rebuild()

var _mesh := MeshInstance3D.new()


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_mesh.visibility_range_end = 70.0
	_rebuild()


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _rebuild() -> void:
	var pm := PropMesh.new()
	var casing: Material = [M.plaster, M.metal, M.rust][posmod(variant, 3)]
	var side := 1.0 if posmod(variant, 2) == 0 else -1.0  # which side the pipes leave from
	var cz := STANDOFF + SIZE.z * 0.5
	var front := STANDOFF + SIZE.z
	pm.box(casing, SIZE, _at(0, 0, cz))
	# The fan: a dark well, a ring guard and its cross, offset to one side; slats on the other.
	var fx := -side * 0.14
	pm.cyl(M.dark, 0.2, 0.2, 0.01, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(fx, 0, front + 0.004)), 12)
	pm.ring(M.rail, 0.18, 0.21, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(fx, 0, front + 0.012)), 12, 4)
	pm.stick(M.rail, Vector3(fx - 0.19, 0, front + 0.012), Vector3(fx + 0.19, 0, front + 0.012), 0.015)
	pm.stick(M.rail, Vector3(fx, -0.19, front + 0.012), Vector3(fx, 0.19, front + 0.012), 0.015)
	pm.box(M.vent, Vector3(0.22, 0.4, 0.01), _at(side * 0.25, 0, front + 0.004))
	# Two L brackets under it, into the wall.
	for bx in [-0.28, 0.28]:
		pm.box(M.metal, Vector3(0.04, 0.04, front + 0.02), _at(bx, -SIZE.y * 0.5 - 0.02, front * 0.5))
		pm.stick(M.metal, Vector3(bx, -SIZE.y * 0.5 - 0.02, front - 0.02), Vector3(bx, -SIZE.y * 0.5 - 0.3, 0.02), 0.035)
	# Refrigerant lines: out of the side, a short run, a bend, into the wall through a cover.
	var x0 := side * SIZE.x * 0.5
	var x1 := side * (SIZE.x * 0.5 + 0.16)
	for k in 2:
		var y := -0.08 - k * 0.07
		var z := cz + 0.04 - k * 0.03
		var mat: Material = M.rubber if k == 0 else M.copper
		var r := 0.022 if k == 0 else 0.014
		pm.cyl(mat, r, r, 0.16, PropMesh.along(Vector3(x0, y, z), Vector3(x1, y, z)), 6)
		pm.sphere(mat, r * 1.2, r * 2.4, _at(x1, y, z), 6, 3)
		pm.cyl(mat, r, r, z, PropMesh.along(Vector3(x1, y, z), Vector3(x1, y, 0.0)), 6)
	pm.box(M.metal, Vector3(0.1, 0.18, 0.03), _at(x1, -0.115, 0.015))  # the wall cover plate
	# The drain from the tray, down the wall a little, open at the end.
	if drain > 0.0:
		var dx := -side * 0.3
		var top := Vector3(dx, -SIZE.y * 0.5, cz)
		pm.cyl(M.rubber, 0.012, 0.012, drain, PropMesh.along(top, top + Vector3(0, -drain, -cz + 0.03)), 6)
	_mesh.mesh = pm.commit()
