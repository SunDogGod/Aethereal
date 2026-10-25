@tool
extends Node3D
## Wrecks in the black sand, picked from Kind: a hauler half sunk in a dune, one of the ceiling's
## light panels that fell and lies in the sand, an old sign gantry keeled over, a stack of cargo
## crates. Tilt and sink the node itself to bury it. Origin on the sand. With Solid on, it gets box
## collision (built when the game runs, never saved in the scene).

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const M := {
	metal = preload("res://materials/metal.tres"), hull = preload("res://materials/black_sand_hull.tres"),
	rust = preload("res://materials/black_sand_hull_rust.tres"), hole = preload("res://materials/black_sand_void.tres"),
	rubber = preload("res://materials/rubber.tres"), dead = preload("res://materials/ceiling_panel_off.tres"),
	glyph = preload("res://materials/black_sand_arch.tres"), yellow = preload("res://materials/paint_yellow.tres"),
	lens = preload("res://materials/precursor_light.tres"), grating = preload("res://materials/grating.tres"),
}

@export_enum("Hauler", "Fallen light panel", "Sign gantry", "Cargo crates") var kind := 0:
	set(value):
		kind = value
		_rebuild()
@export var variant := 0:
	set(value):
		variant = value
		_rebuild()
@export var solid := true:
	set(value):
		solid = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _pm: PropMesh
var _boxes: Array = []
var _body: StaticBody3D


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	_apply_collision()


func _rebuild() -> void:
	_pm = PropMesh.new()
	_boxes.clear()
	match kind:
		0: _hauler()
		1: _panel()
		2: _gantry()
		3: _crates()
	_mesh.mesh = _pm.commit()
	if is_inside_tree():
		_apply_collision()


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


func _solid(mat: Material, size: Vector3, xf: Transform3D) -> void:
	_pm.box(mat, size, xf)
	_boxes.append([size, xf])


## A long hauler, nose toward +X: a cab with dark windows, a cargo bed of ribs with a torn cover,
## big wheels. Sink and tilt the node so a dune swallows the back half.
func _hauler() -> void:
	_solid(M.hull, Vector3(11.0, 1.2, 3.6), _at(0, 1.3, 0))  # chassis
	_solid(M.rust if variant % 2 == 1 else M.hull, Vector3(3.2, 2.6, 3.4), _at(4.2, 3.2, 0))  # cab
	_pm.box(M.hole, Vector3(0.1, 0.9, 2.8), _at(5.82, 3.8, 0))  # windscreen
	for z in [-1.71, 1.71]:
		_pm.box(M.hole, Vector3(1.6, 0.8, 0.05), _at(4.3, 3.8, z))
	_pm.box(M.metal, Vector3(0.3, 0.6, 3.7), _at(5.9, 1.6, 0))  # bumper
	for x in [-4.4, -2.6, -0.8, 1.0]:  # cargo ribs
		_pm.box(M.metal, Vector3(0.18, 2.4, 0.18), _at(x, 3.1, -1.65))
		_pm.box(M.metal, Vector3(0.18, 2.4, 0.18), _at(x, 3.1, 1.65))
		_pm.box(M.metal, Vector3(0.18, 0.18, 3.5), _at(x, 4.3, 0))
	_pm.box(M.rubber, Vector3(3.8, 0.05, 3.6), Transform3D(Basis(Vector3.FORWARD, 0.15), Vector3(-3.3, 4.45, 0)))  # torn cover
	_pm.box(M.rust, Vector3(7.0, 0.5, 3.4), _at(-1.9, 2.15, 0))  # bed floor
	for x in [-3.8, -1.2, 3.6]:
		for z in [-1.9, 1.9]:
			_pm.cyl(M.rubber, 0.9, 0.9, 0.6, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.9, z)), 10)
			_pm.cyl(M.metal, 0.45, 0.45, 0.62, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.9, z)), 8)


## One of the ceiling's 10 m light panels, fallen: a heavy frame, a grid of dead diffusers,
## torn hanger cables. Lay it tilted in the sand.
func _panel() -> void:
	var s := 10.0
	for side in [-1, 1]:
		_solid(M.hull, Vector3(s, 0.6, 0.5), _at(0, 0, side * (s * 0.5 - 0.25)))
		_solid(M.hull, Vector3(0.5, 0.6, s), _at(side * (s * 0.5 - 0.25), 0, 0))
	for i in range(1, 5):
		var t := -s * 0.5 + s * i / 5.0
		_pm.box(M.metal, Vector3(s - 0.4, 0.2, 0.12), _at(0, 0.05, t))
		_pm.box(M.metal, Vector3(0.12, 0.2, s - 0.4), _at(t, 0.05, 0))
	_pm.box(M.dead, Vector3(s - 0.6, 0.08, s - 0.6), _at(0, -0.05, 0))
	_boxes.append([Vector3(s, 0.4, s), _at(0, 0, 0)])
	for k in 3:  # hanger cables, snapped
		var a := Vector3(-s * 0.5 + 1.0 + k * 4.0, 0.3, -s * 0.5 + 0.5 + k * 3.0)
		_pm.stick(M.rubber, a, a + Vector3(0.6, 2.2 - k * 0.5, 0.4), 0.06)


## A sign gantry that keeled over: two legs and a long board with an inscribed, faintly lit band.
func _gantry() -> void:
	for x in [-5.0, 5.0]:
		_solid(M.metal, Vector3(0.4, 7.0, 0.4), _at(x, 2.5, 0))
	_pm.box(M.hull, Vector3(11.0, 0.3, 0.6), _at(0, 6.0, 0))
	_solid(M.hull, Vector3(9.0, 2.2, 0.3), _at(0, 4.8, 0.2))
	_pm.box(M.glyph, Vector3(8.4, 1.6, 0.05), _at(0, 4.8, 0.38))
	if variant % 2 == 0:
		_pm.box(M.lens, Vector3(8.4, 0.06, 0.06), _at(0, 3.85, 0.4))


## Cargo crates stacked as cover: two on the bottom, one on top, a strap round each. Variant
## changes which way the top one is turned.
func _crates() -> void:
	var c := Vector3(1.6, 1.4, 1.6)
	_solid(M.hull, c, _at(-0.85, 0.7, 0))
	_solid(M.rust, c, _at(0.85, 0.7, 0.1))
	var top := Basis(Vector3.UP, 0.3 + 0.4 * (variant % 3))
	_solid(M.hull, c, Transform3D(top, Vector3(0, 2.1, 0.05)))
	for x in [-0.85, 0.85]:
		_pm.box(M.yellow, Vector3(0.1, 1.42, 1.62), _at(x, 0.7, 0.1 if x > 0 else 0.0))
	_pm.box(M.yellow, Vector3(0.1, 1.42, 1.62), Transform3D(top, Vector3(0, 2.1, 0.05)))
