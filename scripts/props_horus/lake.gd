@tool
extends "res://scripts/props_horus/horus_prop.gd"
## Temek's dying lake: a flat plane of dark water (materials/horus_water.tres, its texture
## drifting slowly while the game runs) with a shore of dark mud strips round its edge, the
## water a hand's breadth below the mud. Size is the water's x and z extent; the mud reaches
## Shore metres further out. Origin at the water's surface. Not solid unless you ask (then the
## water is a floor: for a scene where he wades).

@export var size := Vector2(200.0, 160.0):
	set(value):
		size = value
		_rebuild()
@export var shore := 8.0:
	set(value):
		shore = value
		_rebuild()
## Metres per second the water's texture drifts (x, z).
@export var drift := Vector2(0.06, 0.025)

var _water_mat: ShaderMaterial
var _offset := Vector2.ZERO


func _init() -> void:
	solid = false
	super()


func _build() -> void:
	var water := BoxMesh.new()
	water.size = Vector3(size.x, 0.2, size.y)
	water.subdivide_width = clampi(int(size.x / 12.0), 1, 24)
	water.subdivide_depth = clampi(int(size.y / 12.0), 1, 24)
	_pm._add(M.water, water, _at(0, -0.1, 0))
	if solid:
		_boxes.append([Vector3(size.x, 0.2, size.y), _at(0, -0.1, 0)])
	# The mud: overlapping strips along each edge, each a little different, then a few flats.
	for edge in 4:
		var along_x := edge < 2
		var s := 1.0 if edge % 2 == 0 else -1.0
		var length := size.x if along_x else size.y
		var at := (size.y if along_x else size.x) * 0.5
		var n := maxi(int(length / 14.0), 2)
		for i in n:
			var c := -length * 0.5 + length * (i + 0.5) / n
			var l := length / n * _r.randf_range(1.1, 1.5)
			var w := shore * _r.randf_range(0.8, 1.3)
			var off := at + w * 0.5 - _r.randf_range(0.5, 2.0)
			var y := 0.08 + _r.randf_range(0.0, 0.08)
			if along_x:
				_pm.box(M.mud, Vector3(l, 0.16, w), _at(c, y, s * off))
			else:
				_pm.box(M.mud, Vector3(w, 0.16, l), _at(s * off, y, c))
	for k in 6:
		var p := Vector3(_r.randf_range(-size.x * 0.45, size.x * 0.45), 0.0, _r.randf_range(-size.y * 0.45, size.y * 0.45))
		_ball(M.mud, Vector3(_r.randf_range(4.0, 9.0), 0.25, _r.randf_range(3.0, 6.0)), Transform3D(Basis(Vector3.UP, _r.randf() * TAU), p), 8, 3)
	# A few dead posts standing in the water, the stumps of old jetties.
	for k in 5:
		var p := Vector3(_r.randf_range(-size.x * 0.4, size.x * 0.4), 0.0, _r.randf_range(-size.y * 0.4, size.y * 0.4))
		_pm.cyl(M.timber, 0.18, 0.22, _r.randf_range(0.6, 1.8), Transform3D(Basis(Vector3.RIGHT, _r.randf_range(-0.15, 0.15)), p + Vector3(0, 0.4, 0)), 6)


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		set_process(false)
		return
	# The game's own copy of the water material, so the drift never reaches the shared file.
	var mesh := _mesh.mesh
	if mesh:
		for i in mesh.get_surface_count():
			if mesh.surface_get_material(i) == M.water:
				_water_mat = M.water.duplicate()
				_mesh.set_surface_override_material(i, _water_mat)


func _process(delta: float) -> void:
	if _water_mat == null:
		return
	_offset += drift * delta
	_water_mat.set_shader_parameter("uv_offset", _offset)
