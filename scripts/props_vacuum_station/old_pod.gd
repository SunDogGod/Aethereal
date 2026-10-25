@tool
extends "res://scripts/props_vacuum_station/station_prop_base.gd"
## The old capsule Isabella and Aeneas came in, years ago: a much older design than the train,
## a riveted ochre cylinder with a cone nose, banded with hoops, portholes, two skids. It came off
## its line, skidded across the deck and was never moved: rolled a little onto one side, one skid
## snapped off, a hull panel torn open, the side hatch broken off its hinges and lying on the deck
## below the hatchway. Through it: two seats side by side, one of them small.
## Origin on the floor under the middle of the capsule; its nose points +Z, the hatch is on +X.
## Solid (a box round the hull; the flat hatch is walk-through). Change Roll and it rebuilds.

const M := {
	pod = preload("res://materials/vacuum_station_oldpod.tres"), liner = preload("res://materials/metal_worn.tres"),
	rib = preload("res://materials/pipe_rust.tres"), dark = preload("res://materials/rubber.tres"),
	glass = preload("res://materials/vacuum_station_glass.tres"), seat = preload("res://materials/awning_red.tres"),
	screen = preload("res://materials/vacuum_station_screen_dead.tres"), hole = preload("res://materials/black_cube.tres"),
}
const R := 1.3  # hull radius
const HALF := 2.1  # half the cylinder's length (the nose and tail cones add to it)
const SIDES := 14
const THICK := 0.07

## Radians it has rolled onto its side (positive lifts the hatch side).
@export var roll := 0.17:
	set(value):
		roll = value
		_rebuild()

var _frame := Transform3D()  # the capsule's own frame: axis along Z through (0, R, 0), rolled


func _build() -> void:
	_frame = Transform3D(Basis(Vector3.BACK, roll), Vector3(0, R * 1.01, 0))
	_hull()
	_ends()
	_inside()
	_details()
	_hatch()
	fp(Vector3(2.9, R * 2.0 + 0.05, 6.4), Vector3(0, R, 0.25))


## A box in the capsule's frame.
func _box(mat: Material, size: Vector3, xf: Transform3D) -> void:
	pm.box(mat, size, _frame * xf)


## Basis on the hull at angle `ang` (0 = +X, 90 = up): X along the hull's curve, Y outward, Z along.
func _on_hull(ang: float) -> Basis:
	var radial := Vector3(cos(ang), sin(ang), 0)
	return Basis(Vector3(-sin(ang), cos(ang), 0), radial, Vector3.FORWARD)


## The shell: 14 slabs round, six 0.7 m sections long, a liner inside. Slabs left out: the
## hatchway (+X side, the middle two sections) and one torn panel on the top at the back.
func _hull() -> void:
	var step := TAU / SIDES
	for j in 6:
		var z0 := -HALF + j * 0.7
		for i in SIDES:
			var ang := -PI * 0.5 + (i + 0.5) * step
			var hatchway := (i == 3 or i == 4) and (j == 2 or j == 3)
			var torn := i == 8 and j == 0
			if hatchway:
				continue
			var w := 2.0 * R * tan(step * 0.5) * 1.04
			var b := _on_hull(ang)
			var radial := b.y
			if not torn:
				_box(M.pod, Vector3(w, THICK, 0.7), Transform3D(b, radial * (R - THICK * 0.5) + Vector3(0, 0, z0 + 0.35)))
			_box(M.liner, Vector3(w * 0.93, 0.04, 0.7), Transform3D(b, radial * (R - THICK - 0.06) + Vector3(0, 0, z0 + 0.35)))
	for z in [-HALF, -0.7, 0.7, HALF]:  # the hoops (the middle two frame the hatchway)
		pm.ring(M.rib, R - 0.03, R + 0.06, _frame * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, z)), SIDES, 4)
	for ang in [deg_to_rad(-12.9), deg_to_rad(38.6)]:  # the hatchway's long edges
		var p := Vector3(cos(ang), sin(ang), 0) * (R + 0.02)
		pm.stick(M.rib, _frame * (p + Vector3(0, 0, -0.7)), _frame * (p + Vector3(0, 0, 0.7)), 0.08)
	var tb := _on_hull(-PI * 0.5 + 8.5 * step)  # ribs showing through the torn panel, and the panel
	for zz in [-1.85, -1.6]:
		_box(M.rib, Vector3(0.6, 0.06, 0.05), Transform3D(tb, tb.y * (R - 0.05) + Vector3(0, 0, zz)))
	var peel := tb * Basis(Vector3.FORWARD, 0.0) * Basis(Vector3.RIGHT, -0.9)
	_box(M.pod, Vector3(0.6, 0.05, 0.62), Transform3D(peel, tb.y * (R + 0.18) + tb.x * 0.05 + Vector3(0, 0, -1.4 + 0.12)))


## Cone nose (+Z), a short tail cone with the old drive collar, bulkheads closing the cabin.
func _ends() -> void:
	var to_z := Basis(Vector3.RIGHT, PI * 0.5)  # cylinder axis Y -> +Z
	var to_mz := Basis(Vector3.RIGHT, -PI * 0.5)
	pm.cyl(M.pod, 0.38, R, 1.1, _frame * Transform3D(to_z, Vector3(0, 0, HALF + 0.55)), SIDES, 1)
	pm.cyl(M.rib, 0.2, 0.38, 0.2, _frame * Transform3D(to_z, Vector3(0, 0, HALF + 1.2)), 8)
	pm.cyl(M.pod, 0.72, R, 0.6, _frame * Transform3D(to_mz, Vector3(0, 0, -HALF - 0.3)), SIDES, 1)
	pm.ring(M.rib, 0.55, 0.8, _frame * Transform3D(to_z, Vector3(0, 0, -HALF - 0.62)), 12, 4)
	pm.cyl(M.hole, 0.56, 0.56, 0.04, _frame * Transform3D(to_z, Vector3(0, 0, -HALF - 0.62)), 12)
	for z in [-HALF + 0.05, HALF - 0.05]:
		pm.cyl(M.liner, R - 0.1, R - 0.1, 0.05, _frame * Transform3D(to_z, Vector3(0, 0, z)), SIDES)


## The cabin: a floor plate, two seats facing the nose (the right one child-sized), harness
## straps hanging loose, a dead panel on the nose bulkhead, dust drifted against the back.
func _inside() -> void:
	_box(M.liner, Vector3(1.5, 0.06, 4.1), Transform3D(Basis(), Vector3(0, -0.78, 0)))
	for s in [[-0.38, 1.0], [0.36, 0.72]]:  # [x, scale]
		var x: float = s[0]
		var k: float = s[1]
		_box(M.dark, Vector3(0.12, 0.3 * k, 0.12), Transform3D(Basis(), Vector3(x, -0.6 + 0.15 * k - 0.15, 0.25)))  # pedestal
		_box(M.seat, Vector3(0.56 * k, 0.12, 0.55 * k), Transform3D(Basis(), Vector3(x, -0.4 - 0.1 * (1.0 - k), 0.25)))
		_box(M.seat, Vector3(0.56 * k, 0.75 * k, 0.12), Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(x, -0.4 + 0.38 * k, -0.02)))
		pm.stick(M.dark, _frame * Vector3(x - 0.15 * k, -0.05 + 0.5 * k, -0.02), _frame * Vector3(x - 0.12 * k, -0.45, 0.32), 0.04)
		pm.stick(M.dark, _frame * Vector3(x + 0.15 * k, -0.05 + 0.5 * k, -0.02), _frame * Vector3(x + 0.2 * k, -0.55, 0.12), 0.04)
	_box(M.liner, Vector3(1.0, 0.5, 0.18), Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, -0.15, 1.85)))
	_box(M.screen, Vector3(0.7, 0.3, 0.02), Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, -0.1, 1.75)))
	_box(M.pod, Vector3(1.3, 0.08, 0.5), Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, -0.7, -1.85)))  # drift


## Portholes on the far side and the nose, the two skids (one snapped, its back half lying on
## the deck), an antenna stub, a faded roundel.
func _details() -> void:
	for p in [[deg_to_rad(165.0), 1.1], [deg_to_rad(165.0), -1.2], [deg_to_rad(120.0), 1.6]]:
		var b := _on_hull(p[0])
		var c: Vector3 = b.y * (R + 0.01) + Vector3(0, 0, p[1])
		pm.ring(M.liner, 0.17, 0.25, _frame * Transform3D(b, c), 12, 4)
		pm.cyl(M.glass, 0.19, 0.19, 0.03, _frame * Transform3D(b, c), 12)
	for side in [-1.0, 1.0]:
		var ang: float = -PI * 0.5 + side * deg_to_rad(40.0)
		var b := _on_hull(ang)
		var reach: float = 4.6 if side > 0.0 else 2.3  # the -X skid snapped halfway
		var z0 := HALF + 0.4 - reach
		_box(M.rib, Vector3(0.12, 0.14, reach), Transform3D(b, b.y * (R + 0.09) + Vector3(0, 0, z0 + reach * 0.5)))
		for z in [1.5, -1.5]:
			if z > z0:
				_box(M.rib, Vector3(0.08, 0.12, 0.08), Transform3D(b, b.y * (R + 0.02) + Vector3(0, 0, z)))
	# The snapped half on the deck (prop space, not the rolled frame), a little skewed.
	pm.box(M.rib, Vector3(0.14, 0.12, 2.2), Transform3D(Basis(Vector3.UP, 0.22), Vector3(-1.45, 0.06, -1.3)))
	var top := _on_hull(PI * 0.5 + 0.2)
	_box(M.rib, Vector3(0.05, 0.35, 0.05), Transform3D(top, top.y * (R + 0.17) + Vector3(0, 0, -1.0)))
	var side_b := _on_hull(PI)
	pm.ring(M.rib, 0.32, 0.4, _frame * Transform3D(side_b, side_b.y * (R + 0.01)), 12, 4)


## The hatch, torn off its hinges, lying face down on the deck below the hatchway (prop space),
## its inner lining and locking wheel up, one edge propped on the bent hinge arm.
func _hatch() -> void:
	var lie := Basis(Vector3.UP, 0.35) * Basis(Vector3.BACK, 0.1)
	var c := Vector3(2.25, 0.12, -0.1)
	pm.box(M.pod, Vector3(1.15, 0.08, 1.36), Transform3D(lie, c))
	pm.box(M.liner, Vector3(1.0, 0.03, 1.2), Transform3D(lie, c + lie.y * 0.05))
	pm.ring(M.rib, 0.16, 0.24, Transform3D(lie, c + lie.y * 0.08), 10, 4)  # the locking wheel
	pm.stick(M.rib, c + lie.y * 0.08 + lie.x * -0.22, c + lie.y * 0.08 + lie.x * 0.22, 0.04)
	pm.stick(M.rib, c + lie.y * 0.08 + lie.z * -0.22, c + lie.y * 0.08 + lie.z * 0.22, 0.04)
	var edge := c + lie.x * 0.6
	pm.stick(M.rib, edge + Vector3(0, -0.08, -0.4), edge + Vector3(0.05, 0.02, 0.3), 0.07)  # bent hinge arm under it
