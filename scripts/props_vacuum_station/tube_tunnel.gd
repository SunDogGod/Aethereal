@tool
extends Node3D
## The inside of a vacuum tube, seen through its mouth: a ring of wall slabs running back along
## -Z from this node (the mouth), ribs every `rib_every` metres, small guide lights low on both
## walls, and a black plate at the far end. `end_radius` smaller than `radius` narrows it as it
## goes back, so a 10 m tube reads much deeper than it is (forced perspective). `arc_from` and
## `arc_to` (degrees, 0 = +X, 90 = up) build only part of the ring, e.g. the top of a tube that a
## capsule fills. `sealed` builds a round blast door across the mouth instead.
## Built from boxes (correct winding by construction). Purely visual: no collision.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")

@export var radius := 6.3:
	set(value):
		radius = value
		_rebuild()
@export var end_radius := 6.3:
	set(value):
		end_radius = value
		_rebuild()
@export var length := 10.0:
	set(value):
		length = value
		_rebuild()
@export var sides := 16:
	set(value):
		sides = maxi(value, 3)
		_rebuild()
@export var arc_from := -90.0:
	set(value):
		arc_from = value
		_rebuild()
@export var arc_to := 270.0:
	set(value):
		arc_to = value
		_rebuild()
@export var rib_every := 2.0:
	set(value):
		rib_every = value
		_rebuild()
## Light every other guide lamp (false = all dark).
@export var lights_on := true:
	set(value):
		lights_on = value
		_rebuild()
@export var end_cap := true:
	set(value):
		end_cap = value
		_rebuild()
@export var sealed := false:
	set(value):
		sealed = value
		_rebuild()
@export var material: Material = preload("res://materials/vacuum_station_tunnel.tres")
@export var rib_material: Material = preload("res://materials/metal.tres")
@export var light_material: Material = preload("res://materials/vacuum_station_guide.tres")
@export var dark_material: Material = preload("res://materials/black_cube.tres")
@export var stripe_material: Material = preload("res://materials/trim_stripes.tres")

const THICK := 0.6
var _mesh := MeshInstance3D.new()


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _rebuild() -> void:
	var pm := PropMesh.new()
	if sealed:
		_door(pm)
	else:
		_lining(pm)
	_mesh.mesh = pm.commit()


## Slab i of a ring at apothem a, from z0 to z1 (negative, going back).
func _slab(pm: PropMesh, mat: Material, angle: float, step: float, a: float, z0: float, z1: float, thick: float) -> void:
	var radial := Vector3(cos(angle), sin(angle), 0)
	var tangent := Vector3(-sin(angle), cos(angle), 0)
	var width := 2.0 * (a + thick) * tan(step * 0.5) * 1.06  # wide enough to close the outer corners too
	var b := Basis(tangent, radial, Vector3.FORWARD)  # right-handed: tangent x radial = -Z
	pm.box(mat, Vector3(width, thick, absf(z1 - z0)), Transform3D(b, radial * (a + thick * 0.5) + Vector3(0, 0, (z0 + z1) * 0.5)))


func _lining(pm: PropMesh) -> void:
	var n := maxi(int(ceil(sides * (arc_to - arc_from) / 360.0)), 1)
	var step := deg_to_rad(arc_to - arc_from) / n
	var rings := maxi(int(round(length / rib_every)), 1)
	var seg := length / rings
	for j in rings:
		var z0 := -j * seg
		var z1 := -(j + 1) * seg
		var a := lerpf(radius, end_radius, (j + 0.5) / rings)
		for i in n:
			var ang := deg_to_rad(arc_from) + (i + 0.5) * step
			_slab(pm, material, ang, step, a, z0 + 0.01, z1 - 0.01, THICK)
			# A rib at the front of each ring: a lip standing a little proud of the wall.
			_slab(pm, rib_material, ang, step, a - 0.14, z0 - 0.02, z0 - 0.3, 0.16)
		# Guide lamps low on both walls, every other one lit (the rest are dead).
		for side in [-1.0, 1.0]:
			var ang := deg_to_rad(90.0 + side * 130.0)
			if rad_to_deg(ang) < arc_from or rad_to_deg(ang) > arc_to:
				continue
			var radial := Vector3(cos(ang), sin(ang), 0)
			var lit := lights_on and j % 2 == 0
			var p := radial * (a - 0.06) + Vector3(0, 0, (z0 + z1) * 0.5)
			pm.box(light_material if lit else rib_material, Vector3(0.12, 0.12, 0.7), Transform3D(Basis(), p))
	if end_cap:  # a black disc just covering the last ring
		var r := end_radius * 1.06
		pm.cyl(dark_material, r, r, 0.1, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -length - 0.05)), sides)


## A round blast door filling the mouth: a thick disc, six seams from a hub, locking bolts round
## the edge, a striped ring. Faces +Z.
func _door(pm: PropMesh) -> void:
	var face := Basis(Vector3.RIGHT, PI * 0.5)  # cylinder axis Y -> Z
	pm.cyl(material, radius, radius, 0.6, Transform3D(face, Vector3(0, 0, -0.3)), 24, 1)
	pm.cyl(rib_material, 1.3, 1.5, 0.35, Transform3D(face, Vector3(0, 0, 0.17)), 16)
	pm.cyl(dark_material, 0.5, 0.5, 0.1, Transform3D(face, Vector3(0, 0, 0.38)), 12)
	for i in 6:
		var ang := TAU * i / 6.0 + 0.3
		var dir := Vector3(cos(ang), sin(ang), 0)
		var b := Basis(Vector3(-dir.y, dir.x, 0), dir, Vector3.FORWARD)
		pm.box(dark_material, Vector3(0.08, radius - 1.5, 0.04), Transform3D(b, dir * (1.5 + (radius - 1.5) * 0.5) + Vector3(0, 0, 0.02)))
	for i in 12:
		var ang := TAU * i / 12.0
		var dir := Vector3(cos(ang), sin(ang), 0)
		pm.box(rib_material, Vector3(0.5, 0.35, 0.25), Transform3D(Basis(Vector3.BACK, ang), dir * (radius - 0.35) + Vector3(0, 0, 0.12)))
	pm.ring(stripe_material, radius - 1.25, radius - 0.85, Transform3D(face, Vector3(0, 0, 0.02)), 32, 4)
