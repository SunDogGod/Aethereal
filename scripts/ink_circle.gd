extends Node3D
## Isabella's circle, painted on the floor round her as she kneels (her "kneel_draw" pose).
## Showing it ([show InkCircle]) starts the painting: the ring follows her brush tip from about
## 1.1 s to 3.0 s into the pose (her right-back, round the front, to her left), then the ink closes
## the ring behind her by itself and the inner ring and marks fade in. [call InkCircle release]
## is her sacrifice: the ink glows and a pale light (her soul) rises into the cube.
## Shown during the level's first second (Continue replaying the scene), it appears finished.

const SEGMENTS := 48
const INK := Color(0.02, 0.02, 0.03)
const GLOW := Color(0.35, 0.15, 0.5)   ## the violet of her ink (ink_stroke.gd)
const TIP := Vector3(0.0, 0.27, 0.0)   ## the brush's bristles in the Brush node's space

@export var radius := 1.05
@export var width := 0.08
@export var drawer: NodePath           ## who paints it (IsabellaHall): her brush leads the ring
@export var draw_start := 1.1          ## seconds after it's shown that the brush touches the floor
@export var draw_end := 3.0
@export var soul_target: NodePath      ## where her soul goes (the CubeAura)

var _painted: Array[bool] = []
var _t := 0.0
var _age := 0.0
var _last := -1
var _marks := 0.0      # 0..1: the inner ring and the marks
var _glow := 1.6
var _mesh: ImmediateMesh
var _mat: ShaderMaterial
var _drawing := false


func _ready() -> void:
	_painted.resize(SEGMENTS)
	_painted.fill(false)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/ps1_surface.gdshader")
	_mat.set_shader_parameter("albedo_color", INK)
	_mat.set_shader_parameter("emission_color", GLOW)
	_mat.set_shader_parameter("emission_energy", _glow)
	_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "Ink"
	mi.mesh = _mesh
	mi.layers = 1
	add_child(mi)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if not visible:
		return
	_t = 0.0
	_last = -1
	_painted.fill(false)
	_marks = 0.0
	_drawing = _age > 1.0
	if not _drawing:  # Continue: already painted
		_painted.fill(true)
		_marks = 1.0
	_rebuild()


func _process(delta: float) -> void:
	_age += delta
	if not visible or not _drawing:
		return
	_t += delta
	var brush := _brush()
	if _t >= draw_start and _t <= draw_end and brush:
		var tip := brush.global_transform * TIP
		_paint_to(_index_of(tip))
	elif _t > draw_end:
		_close_gap(delta)
	_rebuild()
	if _marks >= 1.0 and not _painted.has(false):
		_drawing = false


## Her sacrifice: the ink flares and a pale light rises from her into the cube.
func release() -> void:
	var tween := create_tween()
	tween.tween_method(_set_glow, 1.6, 6.0, 0.4)
	tween.tween_method(_set_glow, 6.0, 0.8, 2.2)
	var soul := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	ball.radial_segments = 8
	ball.rings = 4
	var mat := ShaderMaterial.new()
	mat.shader = _mat.shader
	mat.set_shader_parameter("albedo_color", Color(0.85, 0.85, 1.0))
	mat.set_shader_parameter("emission_color", Color(0.8, 0.8, 1.0))
	mat.set_shader_parameter("emission_energy", 2.0)
	ball.material = mat
	soul.mesh = ball
	soul.layers = 2
	add_child(soul)
	soul.global_position = global_position + Vector3.UP * 0.9
	var to: Vector3 = global_position + Vector3(0, 2.5, -8)
	var target := get_node_or_null(soul_target) as Node3D
	if target:
		to = target.global_position
	var from := soul.global_position
	var mid := (from + to) * 0.5 + Vector3.UP * 2.5
	var fly := create_tween()
	fly.tween_interval(0.5)
	fly.tween_method(func(k: float) -> void: soul.global_position = _arc(from, mid, to, k),
		0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(soul, "scale", Vector3.ZERO, 0.25)
	fly.tween_callback(soul.queue_free)


static func _arc(a: Vector3, b: Vector3, c: Vector3, k: float) -> Vector3:
	return a.lerp(b, k).lerp(b.lerp(c, k), k)


func _set_glow(v: float) -> void:
	_glow = v
	_mat.set_shader_parameter("emission_energy", v)


func _brush() -> Node3D:
	var who := get_node_or_null(drawer)
	return who.find_child("Brush", true, false) as Node3D if who else null


func _index_of(p: Vector3) -> int:
	var local := to_local(p)
	var a := atan2(local.z, local.x)
	return posmod(int(round(a / TAU * SEGMENTS)), SEGMENTS)


## Paints from the last brush segment to this one, the short way round.
func _paint_to(i: int) -> void:
	if _last < 0:
		_last = i
	var step := 1 if posmod(i - _last, SEGMENTS) <= SEGMENTS / 2 else -1
	var j := _last
	while j != i:
		_painted[j] = true
		j = posmod(j + step, SEGMENTS)
	_painted[i] = true
	_last = i


## After the brush lifts: the unpainted arc fills from both ends, then the marks come.
func _close_gap(delta: float) -> void:
	var rate := int(ceil(delta * SEGMENTS / 0.7))
	for n in rate:
		var gap := _painted.find(false)
		if gap < 0:
			break
		for j in SEGMENTS:  # paint the unpainted segments that touch a painted one
			if not _painted[j] and (_painted[posmod(j - 1, SEGMENTS)] or _painted[posmod(j + 1, SEGMENTS)]):
				_painted[j] = true
				break
	if not _painted.has(false):
		_marks = minf(1.0, _marks + delta / 0.6)


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if not _painted.has(true):
		return  # nothing painted yet (an empty surface is an error)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for i in SEGMENTS:
		if _painted[i]:
			_band(radius, width, float(i) - 0.55, float(i) + 0.55)
	if _marks > 0.0:
		_band(radius * 0.72, width * 0.6 * _marks, 0.0, float(SEGMENTS))
		for k in 6:  # six short marks between the rings, like brush ticks
			var a := (float(k) + 0.25) * SEGMENTS / 6.0
			_tick(a, radius * 0.76, radius * (0.76 + 0.2 * _marks))
	_mesh.surface_end()


func _band(r: float, w: float, from: float, to: float) -> void:
	var steps := maxi(1, int(ceil(to - from)))
	for s in steps:
		var a0 := (from + (to - from) * s / steps) / SEGMENTS * TAU
		var a1 := (from + (to - from) * (s + 1) / steps) / SEGMENTS * TAU
		_quad(Vector3(cos(a0) * (r - w), 0, sin(a0) * (r - w)), Vector3(cos(a0) * (r + w), 0, sin(a0) * (r + w)),
				Vector3(cos(a1) * (r + w), 0, sin(a1) * (r + w)), Vector3(cos(a1) * (r - w), 0, sin(a1) * (r - w)))


func _tick(seg: float, r0: float, r1: float) -> void:
	var a := seg / SEGMENTS * TAU
	var along := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-sin(a), 0, cos(a)) * width * 0.5
	_quad(along * r0 - side, along * r0 + side, along * r1 + side, along * r1 - side)


## A flat quad, both faces (the PS1 shader culls back faces; the camera may be low or high).
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d, a, c, b, a, d, c]:
		_mesh.surface_add_vertex(v)
