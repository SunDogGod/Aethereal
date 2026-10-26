class_name InkStroke
extends MeshInstance3D
## Isabella's brush stroke drawn in the air: a ribbon of ink that follows the tip of her brush
## while she slashes (thin at the start, full in the middle, tapering off the end like a
## calligraphy stroke), then a drop of ink flies from the end of the stroke to the agent she
## binds. It fades and frees itself. companion.gd makes one per bind.

const INK := Color(0.02, 0.02, 0.03)
const GLOW := Color(0.35, 0.15, 0.5)      ## the same violet glow as the agent's ink glyph
const TIP := Vector3(0.0, 0.27, 0.0)      ## the brush's bristles, in the Brush node's space (its bone points along +Y)

var brush: Node3D                ## her Brush prop (Model/Brush); the ribbon follows its tip
var target := Vector3.ZERO       ## where the ink drop lands (the agent's glyph)
var start := 0.08                ## seconds into the slash when the brush starts to mark the air
var finish := 0.24               ## ...and lifts off (the stroke's end: CharacterAnimator.CAST_HIT)
var width := 0.11                ## the stroke's widest, metres
var fly_time := 0.1              ## seconds the drop takes to reach the agent
var linger := 0.35               ## seconds the ribbon hangs in the air before it thins away

var _points: Array[Vector3] = []
var _t := 0.0
var _drop: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	layers = 2
	mesh = ImmediateMesh.new()
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/ps1_surface.gdshader")
	_material.set_shader_parameter("albedo_color", INK)
	_material.set_shader_parameter("emission_color", GLOW)
	_material.set_shader_parameter("emission_energy", 1.6)


func _process(delta: float) -> void:
	_t += delta
	if _t >= start and _t <= finish and is_instance_valid(brush):
		var tip := brush.global_transform * TIP
		if _points.is_empty() or _points.back().distance_to(tip) > 0.02:
			_points.append(tip)
	if _t >= finish and _drop == null and not _points.is_empty():
		_fling(_points.back())
	var fade := 1.0 - clampf((_t - finish - linger * 0.3) / linger, 0.0, 1.0)
	_draw(fade)
	if _t > finish + linger * 1.3:
		queue_free()


## The ribbon: two edges either side of the brush's path, facing the camera.
func _draw(fade: float) -> void:
	var im := mesh as ImmediateMesh
	im.clear_surfaces()
	if _points.size() < 2 or fade <= 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	var n := _points.size()
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in n:
		var p := _points[i]
		var along := (_points[mini(i + 1, n - 1)] - _points[maxi(i - 1, 0)]).normalized()
		var view := (cam.global_position - p).normalized() if cam else Vector3.UP
		var side := along.cross(view)
		if side.length() < 0.01:
			side = along.cross(Vector3.UP)
		var k := float(i) / float(n - 1)
		var w := width * fade * sin(PI * clampf(k * 0.85 + 0.1, 0.0, 1.0))  # thin, full, tapering
		left.append(p + side.normalized() * w * 0.5)
		right.append(p - side.normalized() * w * 0.5)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	for i in n - 1:
		for tri in [[left[i], right[i], left[i + 1]], [right[i], right[i + 1], left[i + 1]]]:
			for v: Vector3 in tri:          # one side...
				im.surface_add_vertex(v)
			for j in [2, 1, 0]:             # ...and the other (the PS1 shader culls back faces)
				im.surface_add_vertex(tri[j])
	im.surface_end()


## A drop of ink flicks off the end of the stroke and flies to the agent.
func _fling(from: Vector3) -> void:
	_drop = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.06
	ball.height = 0.12
	ball.radial_segments = 6
	ball.rings = 3
	ball.material = _material
	_drop.mesh = ball
	_drop.layers = 2
	add_child(_drop)
	_drop.global_position = from
	var tween := create_tween()
	tween.tween_property(_drop, "global_position", target, fly_time)
	tween.tween_property(_drop, "scale", Vector3.ZERO, 0.05)
