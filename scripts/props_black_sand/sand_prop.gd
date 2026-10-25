@tool
extends Node3D
## Small things for Black Sand, built from simple shapes and picked from Kind: road lamp heads,
## marker posts, survey stakes, Agency barriers, a floodlight, camp gear, stones and scrap.
## The origin sits on the sand (a Road lamp head's origin is the TOP of its post; its arm reaches
## toward -Z, over the road). Purely visual: no collision, so it never makes a step on a walked
## floor. Change Kind or Variant in the Inspector and it rebuilds. Big things are sand_structure.gd.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	metal = preload("res://materials/metal_worn.tres"), hull = preload("res://materials/black_sand_hull_worn.tres"),
	rust = preload("res://materials/black_sand_hull_rust_worn.tres"), lens = preload("res://materials/precursor_light.tres"),
	warm = preload("res://materials/black_sand_lamp_warm.tres"), beacon = preload("res://materials/black_sand_beacon.tres"),
	reflector = preload("res://materials/black_sand_reflector.tres"), tarp = preload("res://materials/black_sand_tarp.tres"),
	stone = preload("res://materials/black_sand_stone.tres"), yellow = preload("res://materials/paint_yellow.tres"),
	rubber = preload("res://materials/rubber.tres"), dead = preload("res://materials/ceiling_panel_off.tres"),
	brass = preload("res://materials/brass.tres"), wood = preload("res://materials/wood.tres"),
	red = preload("res://materials/paint_red.tres"), glyph = preload("res://materials/black_sand_arch_worn.tres"),
	sand = preload("res://materials/black_sand_dunes.tres"), fire = preload("res://materials/fire.tres"),
}

@export_enum("Road lamp head", "Marker post", "Survey stake", "Glyph marker", "Barrier", "Junction box",
		"Scrap", "Stones", "Camp gear", "Lean-to", "Floodlight", "Cable coil", "Sand mound", "Campfire") var kind := 0:
	set(value):
		kind = value
		_rebuild()
## Changes sizes, tilts and small details, so two of the same Kind don't look identical.
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
## Not drawn beyond this many metres (0 = always drawn). Small things far off are a pixel or two
## inside the fog anyway.
@export var draw_distance := 70.0:
	set(value):
		draw_distance = value
		_mesh.visibility_range_end = maxf(value, 0.0)

var _mesh := MeshInstance3D.new()
var _pm: PropMesh


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_mesh.visibility_range_end = draw_distance
	_rebuild()


func _rebuild() -> void:
	_pm = PropMesh.new()
	match kind:
		0: _lamp_head()
		1: _marker_post()
		2: _stake()
		3: _glyph_marker()
		4: _barrier()
		5: _junction()
		6: _scrap()
		7: _stones()
		8: _camp_gear()
		9: _lean_to()
		10: _floodlight()
		11: _coil()
		12: _mound()
		13: _campfire()
	_mesh.mesh = _pm.commit()


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


## Origin = top of the post. An arm out over the road, a long lamp housing, its lens underneath.
## Variant 1: the lens is dead (no glow). Variant 2: the housing hangs crooked.
func _lamp_head() -> void:
	var tip := Vector3(0, 0.35, -2.3)
	_pm.stick(M.metal, Vector3(0, -0.1, 0), tip, 0.14)
	_pm.stick(M.metal, Vector3(0, -0.9, 0), Vector3(0, 0.2, -1.2), 0.07)  # brace
	_pm.box(M.metal, Vector3(0.3, 0.45, 0.25), _at(0, -1.6, 0.2))  # a junction box on the post
	var hang := Basis() if variant != 2 else Basis(Vector3.RIGHT, 0.35) * Basis(Vector3.FORWARD, 0.12)
	var head := Transform3D(hang, tip + Vector3(0, -0.1, -0.2))
	_pm.box(M.hull, Vector3(0.7, 0.22, 1.5), head)
	_pm.box(M.lens if variant != 1 else M.dead, Vector3(0.5, 0.05, 1.2), head * _at(0, -0.13, 0))


## A marker post on the verge: a metal post with an amber reflector band and a cap. Odd variants
## lean and sit lower, half swallowed by the sand.
func _marker_post() -> void:
	var lean := Basis(Vector3.RIGHT, 0.0 if variant % 2 == 0 else 0.25) * Basis(Vector3.FORWARD, 0.05 * (variant % 3 - 1))
	var h := 1.1 if variant % 2 == 0 else 0.7
	_pm.box(M.metal, Vector3(0.12, h, 0.12), Transform3D(lean, lean * Vector3(0, h * 0.5 - 0.1, 0)))
	_pm.box(M.reflector, Vector3(0.13, 0.12, 0.13), Transform3D(lean, lean * Vector3(0, h - 0.3, 0)))
	_pm.box(M.hull, Vector3(0.16, 0.05, 0.16), Transform3D(lean, lean * Vector3(0, h - 0.08, 0)))


## A thin survey stake with a strip of cloth tied on, leaning with the wind.
func _stake() -> void:
	var top := Vector3(0.15 + 0.05 * (variant % 3), 1.3, 0.05)
	_pm.stick(M.wood, Vector3(0, -0.2, 0), top, 0.035)
	_pm.box(M.red if variant % 2 == 0 else M.yellow, Vector3(0.32, 0.12, 0.01), Transform3D(Basis(Vector3.UP, 0.1), top + Vector3(0.17, -0.1, 0)))


## A standing stone (1.5 m above the sand) with an inscribed, faintly lit face: a Precursor marker.
func _glyph_marker() -> void:
	var tilt := Basis(Vector3.FORWARD, 0.08 * (variant % 3 - 1)) * Basis(Vector3.RIGHT, 0.06)
	_pm.box(M.glyph, Vector3(0.8, 1.9, 0.45), Transform3D(tilt, tilt * Vector3(0, 0.55, 0)))
	_pm.box(M.stone, Vector3(0.92, 0.14, 0.56), Transform3D(tilt, tilt * Vector3(0, 1.54, 0)))


## A trestle barrier: two A-frame legs and a striped plank, a little red lamp on one end.
func _barrier() -> void:
	for x in [-1.1, 1.1]:
		_pm.stick(M.metal, Vector3(x, 0, -0.35), Vector3(x, 0.95, 0), 0.06)
		_pm.stick(M.metal, Vector3(x, 0, 0.35), Vector3(x, 0.95, 0), 0.06)
	for i in 6:  # the stripes, as blocks of paint
		var mat: Material = M.yellow if i % 2 == 0 else M.rubber
		_pm.box(mat, Vector3(0.44, 0.24, 0.05), _at(-1.1 + 0.22 + i * 0.44, 0.85, 0.03))
	_pm.box(M.beacon, Vector3(0.12, 0.12, 0.12), _at(1.15, 1.06, 0))


## A utility box on a short stand, a conduit running down into the sand.
func _junction() -> void:
	_pm.box(M.metal, Vector3(0.1, 0.8, 0.1), _at(0, 0.4, 0))
	_pm.box(M.hull, Vector3(0.6, 0.75, 0.3), _at(0, 1.05, 0))
	_pm.box(M.reflector if variant % 2 == 0 else M.dead, Vector3(0.06, 0.06, 0.02), _at(0.18, 1.3, 0.16))
	_pm.stick(M.rubber, Vector3(-0.2, 0.7, 0), Vector3(-0.35, -0.1, 0.25), 0.05)


## Plates and rods half sunk in the sand, as if something came apart here long ago.
func _scrap() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77 + variant
	for i in 5:
		var size := Vector3(r.randf_range(0.6, 1.8), 0.06, r.randf_range(0.4, 1.2))
		var b := Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(0.2, 0.9))
		_pm.box(M.hull if i % 2 == 0 else M.rust, size, Transform3D(b, Vector3(r.randf_range(-1.5, 1.5), 0.05, r.randf_range(-1.5, 1.5))))
	for i in 3:
		var a := Vector3(r.randf_range(-1.5, 1.5), -0.2, r.randf_range(-1.5, 1.5))
		_pm.stick(M.metal, a, a + Vector3(r.randf_range(-0.6, 0.6), r.randf_range(0.5, 1.2), r.randf_range(-0.6, 0.6)), 0.05)


## A handful of stones laid in a ring (around a grave, a fire), sitting in the sand.
func _stones() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 11 + variant
	var n := 9
	for i in n:
		var a := TAU * i / n + r.randf_range(-0.15, 0.15)
		var rad := 1.6 + r.randf_range(-0.15, 0.2)
		var s := r.randf_range(0.14, 0.24)
		_pm.sphere(M.stone, s, s * 1.2, _at(cos(a) * rad, s * 0.35, sin(a) * rad), 6, 3)


## Kael's things by the fire: a bedroll, a kettle, two tins, a canteen. Laid out around the
## origin, the fire at +X.
func _camp_gear() -> void:
	_pm.cyl(M.tarp, 0.22, 0.22, 1.7, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.6, 0.22, 0)), 8)
	_pm.cyl(M.rubber, 0.23, 0.23, 0.08, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.2, 0.22, 0)), 8)
	_pm.cyl(M.metal, 0.12, 0.14, 0.2, _at(0.9, 0.1, 0.45), 8)
	_pm.stick(M.metal, Vector3(0.82, 0.22, 0.45), Vector3(0.98, 0.22, 0.45), 0.02)
	_pm.cyl(M.brass, 0.05, 0.05, 0.11, _at(0.4, 0.055, 0.7), 6)
	_pm.cyl(M.brass, 0.05, 0.05, 0.11, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.55, 0.05, 0.85)), 6)
	_pm.cyl(M.tarp, 0.11, 0.11, 0.3, Transform3D(Basis(Vector3.FORWARD, 1.4), Vector3(-0.3, 0.11, 0.7)), 8)


## A tarp slung from a ridge pole on two sticks down to the sand, open toward +Z.
func _lean_to() -> void:
	for x in [-1.3, 1.3]:
		_pm.stick(M.wood, Vector3(x, -0.1, 0), Vector3(x, 1.5, 0), 0.05)
	_pm.stick(M.wood, Vector3(-1.45, 1.5, 0), Vector3(1.45, 1.5, 0), 0.05)
	var slope := Basis(Vector3.RIGHT, -0.95)
	_pm.box(M.tarp, Vector3(2.8, 0.03, 1.85), Transform3D(slope, Vector3(0, 0.75, -0.62)))


## A portable floodlight on a tripod, the head tipped down toward +Z.
func _floodlight() -> void:
	var top := Vector3(0, 2.8, 0)
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		_pm.stick(M.metal, Vector3(cos(a) * 0.8, 0, sin(a) * 0.8), top + Vector3(0, -0.3, 0), 0.05)
	_pm.stick(M.metal, top + Vector3(0, -0.6, 0), top, 0.07)
	var tip := Basis(Vector3.RIGHT, 0.5)
	_pm.box(M.hull, Vector3(0.7, 0.5, 0.3), Transform3D(tip, top + Vector3(0, 0.25, 0)))
	_pm.box(M.warm, Vector3(0.6, 0.4, 0.04), Transform3D(tip, top + Vector3(0, 0.25, 0) + tip * Vector3(0, 0, 0.16)))
	_pm.stick(M.rubber, Vector3(0, 2.2, 0), Vector3(0.6, -0.1, -0.9), 0.04)  # its cable


## A loose coil of heavy cable lying on the sand.
func _coil() -> void:
	for i in 3:
		_pm.ring(M.rubber, 0.42 + i * 0.05, 0.5 + i * 0.05, _at(0.04 * i, 0.04 + i * 0.03, 0.03 * i), 12, 3)
	_pm.stick(M.rubber, Vector3(0.5, 0.05, 0), Vector3(2.0, -0.1, 0.6), 0.07)


## A low mound of heaped sand, 3.6 m across and 1.25 m high from its centre: built over the
## grave's cairn blocks so only the top stones show. Origin at the mound's centre.
func _mound() -> void:
	_pm.sphere(M.sand, 1.8, 2.5, Transform3D(Basis().scaled(Vector3(1.0, 1.0, 0.75)), Vector3.ZERO), 12, 6)
	_pm.sphere(M.sand, 0.9, 1.0, _at(1.3, -0.35, 0.5), 8, 4)  # sand slumped off one side


## A small fire: crossed logs and three tongues of flame. The flame uses fire.tres, so a
## glow_pulse.gd in Fire mode (Material = fire.tres) can make it flicker.
func _campfire() -> void:
	for i in 3:
		var a := TAU * i / 3.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		_pm.stick(M.wood, d * 0.55 + Vector3(0, 0.05, 0), -d * 0.15 + Vector3(0, 0.22, 0), 0.11)
	_pm.cyl(M.fire, 0.0, 0.26, 0.7, _at(0, 0.45, 0), 6)
	_pm.cyl(M.fire, 0.0, 0.16, 0.45, _at(0.15, 0.32, 0.08), 5)
	_pm.cyl(M.fire, 0.0, 0.14, 0.4, _at(-0.12, 0.3, -0.1), 5)
	_pm.cyl(M.dead, 0.42, 0.45, 0.06, _at(0, 0.03, 0), 8)  # ash
