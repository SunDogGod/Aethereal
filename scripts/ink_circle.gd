extends Node3D
## Isabella's sigil, burnt into the hall floor round her as she kneels (her "kneel_draw" pose).
## Showing it ([show InkCircle]) starts it: when her brush touches the floor (`draw_start`) the
## ink races round faster than a hand could move, in about `draw_time` seconds: the outer double
## ring, the seven-pointed star inside, the inner ring, then the glyphs between the rings.
## [call InkCircle release] is her sacrifice: the ink flares and her soul rises out of her into
## the Black Cube (`soul_target`, hall_aura.gd: a GREAT sacrifice, which the cube then gives to
## Aeneas). Shown during the level's first second (Continue replaying the scene), it appears finished.
##
## PLACEHOLDER SIGIL: the author will choose Isabella's real symbol. Everything it is made of is
## in sigil_strokes() (lines in a 1 m circle, each with when it draws); replace that to change it.

const INK := Color(0.02, 0.02, 0.03)
const GLOW := Color(0.35, 0.15, 0.5)   ## the violet of her ink (ink_stroke.gd)
const GREAT := 3.0                      ## what her soul is worth to the cube (hall_aura.gd)

@export var radius := 1.05
@export var width := 0.05
@export var drawer: NodePath           ## who paints it (IsabellaHall)
@export var draw_start := 1.1          ## seconds after it's shown that the brush touches the floor
@export var draw_time := 1.2           ## seconds the whole sigil takes to draw
@export var soul_target: NodePath      ## where her soul goes (the CubeAura)

var _strokes: Array = []   # [[points (unit circle), from 0..1, to 0..1], ...]
var _t := 0.0
var _age := 0.0
var _done := 1.0           # 0..1 how much of the sigil is drawn
var _glow := 1.6
var _mesh: ImmediateMesh
var _mat: ShaderMaterial
var _drawing := false


func _ready() -> void:
	_strokes = sigil_strokes()
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


## PLACEHOLDER: the sigil's lines, in a circle of radius 1 (x right, y toward -Z), each with the
## part of the drawing time it takes (0 = the brush touches, 1 = done). Rings are polylines.
static func sigil_strokes() -> Array:
	var out: Array = []
	out.append([_arc(1.0, 0.0, TAU, 48), 0.0, 0.38])          # the outer ring, round in one sweep
	out.append([_arc(0.88, PI, TAU, 48), 0.08, 0.42])         # the second ring, the other way
	# The seven-pointed star {7/3}: one line, point to point.
	var star := PackedVector2Array()
	for i in 8:
		var a := -PI / 2 + TAU * float(i * 3 % 7) / 7.0
		star.append(Vector2(cos(a), sin(a)) * 0.84)
	out.append([star, 0.38, 0.8])
	out.append([_arc(0.3, 0.0, TAU, 20), 0.72, 0.88])         # the inner ring
	# Glyphs between the rings: a short upright, then a crossbar or a hook, in seven places.
	for g in 7:
		var a := -PI / 2 + TAU * (g + 0.5) / 7.0
		var r := Vector2(cos(a), sin(a))
		var t := Vector2(-r.y, r.x)
		var at := 0.8 + 0.025 * g
		out.append([PackedVector2Array([r * 0.9, r * 0.98]), at, at + 0.06])
		var mark := PackedVector2Array([r * 0.94 - t * 0.035, r * 0.94 + t * 0.035]) if g % 2 == 0 \
				else PackedVector2Array([r * 0.97 + t * 0.03, r * 0.92 + t * 0.03, r * 0.92 - t * 0.02])
		out.append([mark, at + 0.04, at + 0.1])
	return out


static func _arc(r: float, from: float, sweep: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := from + sweep * float(i) / steps
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _on_visibility_changed() -> void:
	if not visible:
		return
	_t = 0.0
	_drawing = _age > 1.0
	_done = 0.0 if _drawing else 1.0  # Continue: already drawn
	_rebuild()


func _process(delta: float) -> void:
	_age += delta
	if not visible or not _drawing:
		return
	_t += delta
	_done = clampf((_t - draw_start) / draw_time, 0.0, 1.0)
	# Fresh ink burns brighter while it is drawn, then cools to its glow.
	_set_glow(1.6 + 2.0 * (1.0 - absf(_done * 2.0 - 1.0)) if _done > 0.0 and _done < 1.0 else 1.6)
	_rebuild()
	if _done >= 1.0:
		_drawing = false


## Her sacrifice: the ink flares, and her soul rises out of her into the cube.
func release() -> void:
	_done = 1.0
	_drawing = false
	_rebuild()
	var tween := create_tween()
	tween.tween_method(_set_glow, 1.6, 7.0, 0.4)
	tween.tween_interval(1.6)
	tween.tween_method(_set_glow, 7.0, 0.8, 2.4)
	var cube := get_node_or_null(soul_target)
	if cube and cube.has_method("take"):
		cube.take(self, GREAT)


func _set_glow(v: float) -> void:
	_glow = v
	_mat.set_shader_parameter("emission_energy", v)


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _done <= 0.0:
		return  # nothing drawn yet (an empty surface is an error)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for s: Array in _strokes:
		var k := clampf((_done - float(s[1])) / maxf(float(s[2]) - float(s[1]), 0.001), 0.0, 1.0)
		if k > 0.0:
			_polyline(s[0], k)
	_mesh.surface_end()


## Draws the first `k` (0..1) of a polyline, as flat quads on the floor.
func _polyline(pts: PackedVector2Array, k: float) -> void:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var left := total * k
	for i in pts.size() - 1:
		if left <= 0.0:
			break
		var a := pts[i]
		var b := pts[i + 1]
		var d := a.distance_to(b)
		if d > left:
			b = a.lerp(b, left / d)
		left -= d
		_segment(a * radius, b * radius)


func _segment(a: Vector2, b: Vector2) -> void:
	var dir := (b - a).normalized() if a.distance_to(b) > 0.0001 else Vector2.RIGHT
	var n := Vector2(-dir.y, dir.x) * width
	var e := dir * width * 0.5  # overlap a little, so corners don't gap
	_quad(_v(a - e - n), _v(a - e + n), _v(b + e + n), _v(b + e - n))


static func _v(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, -p.y)


## A flat quad, both faces (the PS1 shader culls back faces; the camera may be low or high).
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d, a, c, b, a, d, c]:
		_mesh.surface_add_vertex(v)
