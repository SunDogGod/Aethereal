@tool
extends "res://scripts/props_horus/horus_prop.gd"
## An oil derrick of Temek: a lattice tower of fat iron bars on a concrete slab, a pump jack
## beside it (the child `Beam` nods while the game runs), an engine house, and a flare stack
## whose flame (the child `Flame`, with the OmniLight `FlareLight`) flickers when Lit.
## Dead (Lit off): dark, leaning, bars missing, the beam drooped, sand heaped at its foot.
## Origin on the sand under the tower's middle; the pump jack is on +X, the flare on -X.

@export var height := 20.0:
	set(value):
		height = value
		_rebuild()
@export var lit := true:
	set(value):
		lit = value
		_rebuild()
## How far the dead derrick leans (degrees); a lit one stands straight.
@export var lean := 7.0:
	set(value):
		lean = value
		_rebuild()

var _beam := MeshInstance3D.new()
var _flame_mesh := MeshInstance3D.new()
var _time := 0.0
var _light_energy := 3.0


func _init() -> void:
	super()
	_beam.name = "Beam"
	_flame_mesh.name = "Flame"
	add_child(_beam)
	add_child(_flame_mesh)


func _build() -> void:
	var mat: Material = M.iron_dark if not lit else M.iron
	var tilt := Transform3D(Basis(Vector3.FORWARD, deg_to_rad(lean)) if not lit else Basis(), Vector3.ZERO)
	# The slab and the tower.
	_solid(M.concrete, Vector3(11.0, 0.6, 8.0), _at(1.5, 0.3, 0))
	var skip := []
	if not lit:
		for k in 4:
			skip.append([_r.randi_range(1, 5), _r.randi_range(0, 3)])
	_lattice(mat, 2.6, 0.9, height, 6, 0.32, tilt * _at(0, 0.6, 0), skip)
	for c: Vector3 in [Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1), Vector3(-1, 0, 1)]:
		_boxes.append([Vector3(0.6, 3.0, 0.6), tilt * _at(c.x * 2.5, 2.0, c.z * 2.5)])
		_pm.box(M.concrete, Vector3(1.2, 0.5, 1.2), _at(c.x * 2.6, 0.8, c.z * 2.6))
	# The crown: a grated platform, a block, a rail.
	var top := tilt * _at(0, height + 0.6, 0)
	_pm.box(M.grating, Vector3(3.2, 0.12, 3.2), top)
	_pm.box(mat, Vector3(3.4, 0.3, 0.3), top * _at(0, -0.2, 0))
	_pm.box(mat, Vector3(1.2, 1.4, 1.0), top * _at(0, 0.8, 0))
	_pm.ring(mat, 0.1, 0.5, top * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 1.0, 0.6)), 10, 4)
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		_pm.box(mat, Vector3(0.08, 1.0, 0.08), top * _at(cos(a) * 2.2, 0.5, sin(a) * 2.2))
	_pm.box(mat, Vector3(3.2, 0.06, 0.06), top * _at(0, 1.0, 1.55))
	_pm.box(mat, Vector3(3.2, 0.06, 0.06), top * _at(0, 1.0, -1.55))
	_pump_jack(mat)
	_engine_house(mat)
	_flare(mat)
	if not lit:
		for k in 3:
			var p := Vector3(_r.randf_range(-4.0, 4.0), -0.4, _r.randf_range(-3.5, 3.5))
			_ball(M.sand, Vector3(_r.randf_range(2.5, 4.0), 1.1, _r.randf_range(2.0, 3.0)), _at(p.x, p.y, p.z), 8, 4)


## The pump jack on +X: a samson post, the wellhead, and the walking beam (its own mesh, so
## it can nod): a horse head at the front, a counterweight behind, the polished rod down.
func _pump_jack(mat: Material) -> void:
	var px := 5.0
	var post_top := Vector3(px, 4.2, 0)
	for s: float in [-1.0, 1.0]:
		_solid_stick(mat, Vector3(px - 1.2, 0.6, s * 1.4), post_top + Vector3(0, 0, s * 0.3), 0.3)
		_solid_stick(mat, Vector3(px + 1.2, 0.6, s * 1.4), post_top + Vector3(0, 0, s * 0.3), 0.3)
	_pm.box(mat, Vector3(0.5, 0.5, 1.4), _at(px, 4.2, 0))
	_pm.cyl(mat, 0.5, 0.6, 1.6, _at(px + 4.3, 1.4, 0), 8)  # the wellhead
	_boxes.append([Vector3(1.2, 1.6, 1.2), _at(px + 4.3, 1.4, 0)])
	_pm.ring(M.metal, 0.06, 0.4, _at(px + 4.3, 2.3, 0), 10, 4)
	_pm.cyl(mat, 0.9, 0.9, 0.3, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(px - 3.2, 1.6, 1.0)), 10)  # the crank disc
	_pm.cyl(mat, 0.9, 0.9, 0.3, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(px - 3.2, 1.6, -1.0)), 10)
	var bm := PropMesh.new()
	bm.box(mat, Vector3(9.0, 0.5, 0.7), _at(0.6, 0.0, 0))
	bm.box(mat, Vector3(1.4, 1.7, 0.9), Transform3D(Basis(Vector3.FORWARD, 0.3), Vector3(5.0, -0.5, 0)))  # the horse head
	bm.box(mat, Vector3(1.6, 1.2, 1.4), _at(-4.2, 0.0, 0))  # the counterweight
	bm.stick(M.metal, Vector3(5.0, -1.0, 0), Vector3(5.0, -2.9, 0), 0.08)  # the polished rod
	bm.stick(M.metal, Vector3(-3.4, -0.3, 0.8), Vector3(-3.2, -2.5, 1.0), 0.1)  # the pitman arms
	bm.stick(M.metal, Vector3(-3.4, -0.3, -0.8), Vector3(-3.2, -2.5, -1.0), 0.1)
	_beam.mesh = bm.commit()
	_beam.position = post_top
	_beam.rotation.z = 0.0 if lit else -0.22


## The engine house on -Z: a plated shed, a small chimney, a door, drums by its wall.
func _engine_house(mat: Material) -> void:
	_solid(mat, Vector3(4.0, 2.6, 3.0), _at(4.5, 1.9, -5.0))
	_pm.box(M.iron_dark, Vector3(4.4, 0.3, 3.4), _at(4.5, 3.2, -5.0))
	_pm.cyl(M.iron_dark, 0.25, 0.3, 2.0, _at(3.2, 4.2, -5.6), 8)
	_pm.box(M.hole, Vector3(0.9, 1.9, 0.1), _at(5.2, 1.55, -3.46))
	_pm.box(M.stripes, Vector3(1.4, 0.25, 0.08), _at(5.2, 2.62, -3.46))
	for k in 2:
		_pm.cyl(M.iron, 0.4, 0.4, 1.1, _at(1.8 + k * 0.95, 1.15, -5.2 + k * 0.2), 10)
		_boxes.append([Vector3(0.8, 1.1, 0.8), _at(1.8 + k * 0.95, 1.15, -5.2 + k * 0.2)])
	_pm.cyl(M.iron, 0.35, 0.35, 4.0, PropMesh.along(Vector3(4.5, 1.6, -3.5), Vector3(4.5, 1.6, 0.2)), 8)  # a line to the well


## The flare stack on -X: a thin pipe with guy wires, a wider tip, and the flame (its own mesh,
## so it can flicker) with its light. Dead: the tip is a dark mouth and no flame.
func _flare(mat: Material) -> void:
	var fx := -6.0
	var fz := 2.5
	var fh := height * 1.15
	_pm.cyl(mat, 0.35, 0.45, fh, _at(fx, fh * 0.5, fz), 8, 2)
	_boxes.append([Vector3(0.9, 4.0, 0.9), _at(fx, 2.0, fz)])
	_pm.box(M.concrete, Vector3(1.6, 0.8, 1.6), _at(fx, 0.3, fz))
	_pm.cyl(mat, 0.55, 0.45, 1.4, _at(fx, fh + 0.5, fz), 8)
	_pm.cyl(M.hole, 0.45, 0.45, 0.1, _at(fx, fh + 1.2, fz), 8)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var foot := Vector3(fx + cos(a) * 5.0, 0.0, fz + sin(a) * 5.0)
		_pm.stick(M.metal, Vector3(fx, fh * 0.75, fz), foot, 0.05)
		_pm.box(M.concrete, Vector3(0.5, 0.6, 0.5), _at(foot.x, 0.1, foot.z))
	var fm := PropMesh.new()
	if lit:
		fm.sphere(M.flame, 0.7, 1.2, _at(0, 0.5, 0), 6, 3)
		fm.cyl(M.flame, 0.0, 0.6, 2.6, _at(0, 1.9, 0), 6)
		fm.cyl(M.flame, 0.0, 0.3, 3.8, Transform3D(Basis(Vector3.FORWARD, -0.15), Vector3(0.2, 2.4, 0)), 5)
	_flame_mesh.mesh = fm.commit()
	_flame_mesh.position = Vector3(fx, fh + 1.2, fz)
	var old := get_node_or_null("FlareLight")
	if old:
		old.free()
	if lit:
		var l := _light("FlareLight", Vector3(fx, fh + 2.5, fz), Color(1.0, 0.6, 0.25), _light_energy, 45.0)
		l.omni_attenuation = 1.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not lit:
		return
	_time += delta
	_beam.rotation.z = sin(_time * 1.6) * 0.13
	var f := flicker(_time, float(variant))
	_flame_mesh.scale = Vector3(1.0, f, 1.0)
	_flame_mesh.rotation.y = _time * 0.8
	var l := get_node_or_null("FlareLight") as OmniLight3D
	if l:
		l.light_energy = _light_energy * (0.7 + 0.3 * f)
