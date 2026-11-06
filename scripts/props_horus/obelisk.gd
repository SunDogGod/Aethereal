@tool
extends "res://scripts/props_horus/horus_prop.gd"
## The Barrier Obelisk: a Voidstone monolith Height metres tall on a three-course stone plinth,
## with a ramp of stone up the front (+Z) and down the back, so the way through the ridge is
## across the plinth at its foot (no steps). Lit: a thin cold light runs up its four edges and
## the child `BarrierWall` (two see-through sheets of crawling glyphs, materials/horus_barrier.tres)
## stands across the ridge either side of the plinth. A scene hides `$Obelisk/BarrierWall` (or
## tweens its panels' `fade` instance parameter to 0) when the Obelisk lets them pass.

@export var height := 40.0:
	set(value):
		height = value
		_rebuild()
@export var lit := true:
	set(value):
		lit = value
		_rebuild()
## The wall of light's full width across the ridge, and its height.
@export var barrier_width := 160.0:
	set(value):
		barrier_width = value
		_rebuild()
@export var barrier_height := 24.0:
	set(value):
		barrier_height = value
		_rebuild()

const PLINTH := [9.0, 7.0, 5.0]  # half-widths of the three courses
const COURSE := 0.6
var _barrier := Node3D.new()


func _init() -> void:
	super()
	_barrier.name = "BarrierWall"
	add_child(_barrier)
	for n: String in ["Left", "Right"]:
		var panel := MeshInstance3D.new()
		panel.name = n
		panel.mesh = QuadMesh.new()
		panel.material_override = preload("res://materials/horus_barrier.tres")
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_barrier.add_child(panel)


func _build() -> void:
	var top := COURSE * PLINTH.size()
	for i in PLINTH.size():
		var hw: float = PLINTH[i]
		_solid(M.stone_dark, Vector3(hw * 2.0, COURSE, hw * 2.0), _at(0, COURSE * (i + 0.5), 0))
	# The ramps: from the sand at the first course's edge plus a run, up onto the top course.
	for s: float in [-1.0, 1.0]:
		var a := Vector3(0, -0.25, s * (PLINTH[0] + 5.4))
		var b := Vector3(0, top - 0.25, s * (PLINTH[2] - 0.4))
		_solid(M.stone_dark, Vector3(4.0, a.distance_to(b) + 0.5, 0.5), PropMesh.along(a, b))
		for k: float in [-2.2, 2.2]:  # low kerbs
			_pm.box(M.stone, Vector3(0.3, 0.5, a.distance_to(b)), PropMesh.along(a, b) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(k, 0.0, 0.25)))
	# The monolith: a tapering square shaft and its pyramidion, all Voidstone.
	var shaft := height - 4.0
	var hb := 3.0
	var ht := 2.0
	_taper(M.voidstone, hb, ht, shaft, _at(0, top, 0))
	_boxes.append([Vector3(hb * 2.0, shaft, hb * 2.0), _at(0, top + shaft * 0.5, 0)])
	_pm.cyl(M.voidstone, 0.0, ht * SQRT2, 4.0, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, top + shaft + 2.0, 0)), 4)
	# A band of fat carved blocks round the foot, dark on dark.
	for k in 4:
		var a := k * PI * 0.5
		var xf := Transform3D(Basis(Vector3.UP, a), Vector3(0, top + 2.0, 0))
		for j in 3:
			_pm.box(M.hole, Vector3(0.9, 1.4, 0.1), xf * _at(-1.5 + j * 1.5, 0.0, hb + 0.03))
	# The cold edge light up each edge and the cap's edges.
	if lit:
		for c: Vector3 in [Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1), Vector3(-1, 0, 1)]:
			_pm.stick(M.edge, c * hb + Vector3(0, top + 0.2, 0), c * ht + Vector3(0, top + shaft, 0), 0.16)
			_pm.stick(M.edge, c * ht + Vector3(0, top + shaft, 0), Vector3(0, top + shaft + 4.0, 0), 0.14)
		_light("EdgeLight", Vector3(0, 5.0, PLINTH[2] + 1.0), Color(0.6, 0.8, 1.0), 1.0, 26.0)
	else:
		var old := get_node_or_null("EdgeLight")
		if old:
			old.free()
	_barrier.visible = lit
	var panel_w := barrier_width * 0.5 - PLINTH[0]
	for s: float in [-1.0, 1.0]:
		var panel: MeshInstance3D = _barrier.get_node("Left" if s < 0 else "Right")
		(panel.mesh as QuadMesh).size = Vector2(panel_w, barrier_height)
		panel.position = Vector3(s * (PLINTH[0] + panel_w * 0.5), barrier_height * 0.5 - 1.0, 0)
		panel.set_instance_shader_parameter("wall_size", Vector2(panel_w, barrier_height))
