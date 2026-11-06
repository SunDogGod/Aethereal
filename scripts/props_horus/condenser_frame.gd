@tool
extends "res://scripts/props_horus/horus_prop.gd"
## The farmer's moisture frames: rows of iron A-frames with cloth stretched on one face, a gutter
## along the cloth's foot sloping to a jar at the end of each row. Rows run along local X,
## Row Gap apart along Z; the Variant seeds the lean of each frame, a torn cloth here and there,
## a jar knocked over. The cloth is solid (you walk round a frame, not through it).

@export var rows := 3:
	set(value):
		rows = value
		_rebuild()
@export var per_row := 4:
	set(value):
		per_row = value
		_rebuild()
## Metres between frames along a row, and between rows.
@export var spacing := 3.0:
	set(value):
		spacing = value
		_rebuild()
@export var row_gap := 4.0:
	set(value):
		row_gap = value
		_rebuild()
@export var frame_height := 2.4:
	set(value):
		frame_height = value
		_rebuild()


func _build() -> void:
	for row in rows:
		var z := (row - (rows - 1) * 0.5) * row_gap
		var x0 := -(per_row - 1) * 0.5 * spacing
		for i in per_row:
			_frame(Vector3(x0 + i * spacing, 0, z), row)
		# The gutter along the row's foot, a little lower at the jar's end, into the jar.
		var jar_x := x0 + per_row * spacing - spacing * 0.5 + 0.6
		var ga := Vector3(x0 - spacing * 0.5, 0.42, z + 0.95)
		var gb := Vector3(jar_x - 0.5, 0.3, z + 0.95)
		_pm.box(M.iron_dark, Vector3(ga.distance_to(gb), 0.14, 0.3), PropMesh.along(ga, gb) * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO))
		_pm.box(M.hole, Vector3(ga.distance_to(gb) - 0.1, 0.05, 0.18), PropMesh.along(ga + Vector3(0, 0.06, 0), gb + Vector3(0, 0.06, 0)) * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO))
		_jar(Vector3(jar_x, 0, z + 0.95), row)


## One A-frame at p: two pairs of legs, a ridge bar, the cloth on the +Z face, a foot bar.
func _frame(p: Vector3, row: int) -> void:
	var h := frame_height * _r.randf_range(0.92, 1.06)
	var w := spacing * 0.8
	var yaw := _r.randf_range(-0.08, 0.08)
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _r.randf_range(-0.04, 0.04)), p)
	var half := 0.95
	for s: float in [-1.0, 1.0]:
		var ridge := Vector3(s * w * 0.5, h, 0)
		_pm.stick(M.iron_dark, xf * Vector3(s * w * 0.5, -0.2, half), xf * ridge, 0.1)
		_pm.stick(M.iron_dark, xf * Vector3(s * w * 0.5, -0.2, -half), xf * ridge, 0.1)
	_pm.stick(M.iron_dark, xf * Vector3(-w * 0.5, h, 0), xf * Vector3(w * 0.5, h, 0), 0.12)
	_pm.stick(M.iron_dark, xf * Vector3(-w * 0.5, 0.35, half * 0.75), xf * Vector3(w * 0.5, 0.35, half * 0.75), 0.08)
	_pm.stick(M.iron_dark, xf * Vector3(-w * 0.5, 0.35, -half * 0.75), xf * Vector3(w * 0.5, 0.35, -half * 0.75), 0.08)
	# The cloth: a thin sheet on the +Z slope, from the ridge down to the foot bar.
	var top := xf * Vector3(0, h - 0.05, 0.05)
	var foot := xf * Vector3(0, 0.4, half * 0.75)
	var cloth_xf := PropMesh.along(foot, top)
	var torn := _r.randf() < 0.18
	var size := Vector3(w - 0.2, foot.distance_to(top) - 0.1, 0.04)
	if torn:
		size.y *= 0.55
		cloth_xf.origin = top.lerp(foot, 0.28)
		_pm.box(M.cloth, Vector3(size.x * 0.3, size.y * 0.5, 0.04), cloth_xf * Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(-size.x * 0.2, -size.y * 0.7, 0)))
	_pm.box(M.cloth, size, cloth_xf)
	_boxes.append([Vector3(size.x, size.y, 0.3), cloth_xf])
	# Ties at the ridge: fat knots.
	for s: float in [-1.0, 1.0]:
		_pm.box(M.timber, Vector3(0.14, 0.14, 0.2), xf * Transform3D(Basis(), Vector3(s * (w * 0.5 - 0.3), h, 0)))


## The jar at the gutter's end: a clay drum with a lip, a lid leaning on it; sometimes toppled.
func _jar(p: Vector3, row: int) -> void:
	var toppled := _r.randf() < 0.2 and row > 0
	var xf := Transform3D(Basis(Vector3.FORWARD, PI * 0.5), p + Vector3(0.4, 0.35, 0.4)) if toppled else Transform3D(Basis(), p)
	_pm.cyl(M.stone_dark, 0.32, 0.26, 0.9, xf * _at(0, 0.45, 0), 8, 1)
	_pm.cyl(M.stone_dark, 0.36, 0.3, 0.12, xf * _at(0, 0.9, 0), 8)
	_pm.cyl(M.hole, 0.26, 0.26, 0.05, xf * _at(0, 0.95, 0), 8)
	_boxes.append([Vector3(0.7, 1.0, 0.7), xf * _at(0, 0.5, 0)])
	if not toppled:
		_pm.cyl(M.timber, 0.34, 0.34, 0.06, Transform3D(Basis(Vector3.RIGHT, 1.2), p + Vector3(0.45, 0.32, 0.1)), 8)
