@tool
extends Node3D
## What the Horus arc's landmark props share (construct_pipe.gd, pump_house.gd, derrick.gd,
## condenser_frame.gd, desert_shack.gd, obelisk.gd, pyramid.gd, lake.gd, causeway_gate.gd):
## one PropMesh built once when the node is in a scene (mesh_build.gd), a StaticBody3D of boxes
## for the parts you can walk into (built when the game runs, never saved in the scene), a seeded
## random generator for variation, and the palette of Temek: oiled iron, warm stone, Voidstone.
## Not used on its own: a script that extends it fills in `_build()`.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const SQRT2 := 1.41421356
const M := {
	iron = preload("res://materials/horus_iron.tres"), iron_dark = preload("res://materials/horus_iron_dark.tres"),
	stone = preload("res://materials/horus_stone.tres"), stone_dark = preload("res://materials/horus_stone_dark.tres"),
	voidstone = preload("res://materials/horus_voidstone.tres"), hole = preload("res://materials/black_sand_void.tres"),
	edge = preload("res://materials/horus_cold_edge.tres"), flame = preload("res://materials/horus_flame.tres"),
	lamp = preload("res://materials/horus_lamp.tres"), cloth = preload("res://materials/horus_cloth.tres"),
	sand = preload("res://materials/horus_sand_heap.tres"), churned = preload("res://materials/horus_churned.tres"),
	water = preload("res://materials/horus_water.tres"), mud = preload("res://materials/horus_mud.tres"),
	timber = preload("res://materials/black_sand_timber.tres"), stripes = preload("res://materials/trim_stripes_worn.tres"),
	concrete = preload("res://materials/concrete_dark_worn.tres"), grating = preload("res://materials/grating.tres"),
	metal = preload("res://materials/metal_worn.tres"),
}

## Changes the small differences (lean, wear, which plates are missing), so two of the same
## prop don't look identical.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Box collision for the parts the player could walk into.
@export var solid := true:
	set(value):
		solid = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _pm: PropMesh
var _boxes: Array = []  # [size, Transform3D] pairs for the collision
var _body: StaticBody3D
var _r := RandomNumberGenerator.new()  # seeded from the variant before each build
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	_apply_collision()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	_pm = PropMesh.new()
	_boxes = []
	_r.seed = 7000 + variant * 31 + hash(get_script().resource_path) % 977
	_build()
	_mesh.mesh = _pm.commit()
	if is_inside_tree():
		_apply_collision()


## The shapes of this prop (the scripts that extend this one fill it in).
func _build() -> void:
	pass


## One StaticBody3D (layer 1, like the Blocks) with a box per solid part.
func _apply_collision() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not solid or _boxes.is_empty():
		return
	_body = StaticBody3D.new()
	add_child(_body, false, INTERNAL_MODE_FRONT)
	for pair in _boxes:
		var shape := BoxShape3D.new()
		shape.size = pair[0]
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = pair[1]
		_body.add_child(col)


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _yaw(a: float, x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, a), Vector3(x, y, z))


## A box that is drawn and also solid.
func _solid(mat: Material, size: Vector3, xf: Transform3D) -> void:
	_pm.box(mat, size, xf)
	_boxes.append([size, xf])


## A drawn stick from a to b that is also solid (a fat bar you could walk into).
func _solid_stick(mat: Material, a: Vector3, b: Vector3, thick: float) -> void:
	_pm.stick(mat, a, b, thick)
	_boxes.append([Vector3(thick, a.distance_to(b), thick), PropMesh.along(a, b)])


## A sphere squashed to `half` (half-sizes along x, y, z): sand heaps, mounds. Built from ONE unit
## sphere per sides/rings, stretched, so each new size is not another trip to the graphics card.
func _ball(mat: Material, half: Vector3, xf: Transform3D, sides := 8, rings := 4) -> void:
	_pm.sphere(mat, 1.0, 2.0, Transform3D(xf.basis * Basis.from_scale(half), xf.origin), sides, rings)


## A square tapered post (a pylon, a plinth block): wider at the foot than at the top. Local Y up.
func _taper(mat: Material, half_bottom: float, half_top: float, height: float, xf: Transform3D) -> void:
	_pm.cyl(mat, half_top * SQRT2, half_bottom * SQRT2, height, xf * Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, height * 0.5, 0)), 4)


## An X of bracing bars between two pairs of points (a lattice face, one level).
func _cross(mat: Material, a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3, thick: float) -> void:
	_pm.stick(mat, a0, b1, thick)
	_pm.stick(mat, b0, a1, thick)


## A lattice tower: four legs from the corners of a `base` square to a `top` square `height` up,
## X bracing on every face per level, a ring beam at each level. `thick` is the legs' bar size.
## `xf` moves (or leans) the whole tower; `skip` is a list of [level, face] pairs left out.
func _lattice(mat: Material, base: float, top: float, height: float, levels: int, thick: float, xf := Transform3D(), skip := []) -> void:
	var corners := [Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1), Vector3(-1, 0, 1)]
	for c: Vector3 in corners:
		_pm.stick(mat, xf * (c * base), xf * (c * top + Vector3(0, height, 0)), thick)
	for i in levels:
		var t0 := float(i) / levels
		var t1 := float(i + 1) / levels
		var r0 := lerpf(base, top, t0)
		var r1 := lerpf(base, top, t1)
		var h0 := height * t0
		var h1 := height * t1
		for f in 4:
			if skip.has([i, f]):
				continue
			var d0: Vector3 = corners[f]
			var d1: Vector3 = corners[(f + 1) % 4]
			_cross(mat, xf * (d0 * r0 + Vector3(0, h0, 0)), xf * (d1 * r0 + Vector3(0, h0, 0)),
					xf * (d0 * r1 + Vector3(0, h1, 0)), xf * (d1 * r1 + Vector3(0, h1, 0)), thick * 0.45)
			if i > 0:
				_pm.stick(mat, xf * (d0 * r0 + Vector3(0, h0, 0)), xf * (d1 * r0 + Vector3(0, h0, 0)), thick * 0.55)


## A low-poly flame: a cone over a ball, `h` tall, in the flame material (emissive).
func _flame(h: float, xf: Transform3D) -> void:
	_pm.sphere(M.flame, h * 0.22, h * 0.36, xf * _at(0, h * 0.18, 0), 6, 3)
	_pm.cyl(M.flame, 0.0, h * 0.2, h * 0.7, xf * _at(0, h * 0.6, 0), 6)


## A warm OmniLight3D for a flame or a lamp, named so a script can find it (no shadows ever).
func _light(light_name: String, at: Vector3, color: Color, energy: float, range_m: float) -> OmniLight3D:
	var old := get_node_or_null(light_name)
	if old:
		old.free()
	var l := OmniLight3D.new()
	l.name = light_name
	l.position = at
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	add_child(l, false, INTERNAL_MODE_FRONT)
	return l


## A flame's flicker: a quick, uneven wobble around 1.0 (call each frame with the running time).
static func flicker(t: float, seed_offset := 0.0) -> float:
	return 1.0 + 0.12 * sin(t * 11.0 + seed_offset) + 0.08 * sin(t * 23.0 + seed_offset * 1.7) + 0.05 * sin(t * 5.3 + seed_offset * 0.3)
