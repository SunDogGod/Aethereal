extends Node3D
## Someone the Black Cube has just given to glows with it for a while (hall_aura.gd): a light on
## him in the aura's colour, a soft flare round his body, and motes curling up round him. It
## rides along as his child, swells in, holds `seconds`, and fades away. `strength` 1 is the
## captain's brief glow from a body; Isabella's gift to Aeneas uses much more.
## on() starts one, or tops up the one already on him. Made in code; nothing is saved.

const FLAME := preload("res://shaders/hall_flame.gdshader")
const NAME := "HallGlow"
const MOTES := 28

var color := Color(0.95, 0.15, 0.2)
var strength := 1.0
var seconds := 1.6

var _t := 0.0
var _light := OmniLight3D.new()
var _flare := MeshInstance3D.new()
var _flare_mat := ShaderMaterial.new()
var _multi := MultiMesh.new()


## Glows `who` in `color` for `seconds` (then fades over about a second).
static func on(who: Node3D, color: Color, strength := 1.0, seconds := 1.6) -> Node3D:
	if who == null or not is_instance_valid(who):
		return null
	var glow: Node3D = who.get_node_or_null(NAME)
	if glow:  # already glowing: brighter if need be, and held again from full
		glow.set("color", color)
		glow.set("strength", maxf(strength, float(glow.get("strength"))))
		glow.set("seconds", seconds)
		glow.set("_t", minf(float(glow.get("_t")), 0.3))
		return glow
	glow = load("res://scripts/vfx/hall_glow.gd").new()
	glow.name = NAME
	glow.set("color", color)
	glow.set("strength", strength)
	glow.set("seconds", seconds)
	who.add_child(glow)
	return glow


## Lets the glow go now (it fades over a second): Aeneas's, when the burst takes over.
static func off(who: Node3D) -> void:
	var glow: Node3D = who.get_node_or_null(NAME) if who and is_instance_valid(who) else null
	if glow:
		glow.set("seconds", minf(float(glow.get("seconds")), float(glow.get("_t"))))


func _ready() -> void:
	position = Vector3(0, 1.1, 0)
	_light.omni_range = 4.0 + 2.0 * strength
	_light.shadow_enabled = false
	add_child(_light)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_flare_mat.shader = FLAME
	_flare_mat.render_priority = 1
	_flare_mat.set_shader_parameter("shape", 1)
	_flare_mat.set_shader_parameter("pixels", Vector2(20, 20))
	_flare_mat.set_shader_parameter("core_color", Color(1, 1, 1))
	_flare_mat.set_shader_parameter("mid_color", Color(0.6, 0.6, 0.6))
	_flare_mat.set_shader_parameter("edge_color", Color(0.3, 0.3, 0.3))
	_flare.mesh = quad
	_flare.material_override = _flare_mat
	_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flare.extra_cull_margin = 3.0
	add_child(_flare)
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.mesh = quad
	_multi.instance_count = MOTES
	_multi.custom_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 6, 6))
	var mm := MultiMeshInstance3D.new()
	mm.multimesh = _multi
	mm.material_override = HallStream.mote_material()
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm)


func _process(delta: float) -> void:
	_t += delta
	# In fast (0.3 s), hold, then out over a second.
	var level := minf(_t / 0.3, 1.0) * clampf(1.0 - (_t - seconds) / 1.0, 0.0, 1.0)
	if _t > seconds + 1.0:
		queue_free()
		return
	var flicker := 0.85 + 0.15 * sin(_t * 23.0) * sin(_t * 7.0)
	_light.light_color = color
	_light.omni_range = 4.0 + 2.0 * strength
	_light.light_energy = (2.2 + 2.0 * strength) * level * flicker
	var s := (1.2 + 0.12 * strength) * (0.9 + 0.1 * sin(_t * 9.0))
	_flare.scale = Vector3(s, s * 1.5, 1.0)
	_flare_mat.set_shader_parameter("brightness", 0.4 * level * minf(strength, 1.6))
	var tint := color.lerp(Color.WHITE, 0.35)
	_flare_mat.set_shader_parameter("core_color", tint)
	_flare_mat.set_shader_parameter("mid_color", tint * 0.7)
	_flare_mat.set_shader_parameter("edge_color", tint * 0.4)
	for i in MOTES:
		# Each mote curls up round him and starts again at his feet.
		var k := fmod(_t * (0.55 + 0.25 * fmod(i * 0.37, 1.0)) + i * 0.618, 1.0)
		var a := i * 2.39 + k * TAU * 1.3
		var r := (0.35 + 0.15 * strength) * (1.0 - 0.4 * k)
		var p := Vector3(cos(a) * r, -1.0 + k * 2.4, sin(a) * r)
		var sz := 0.07 * minf(strength, 2.0) * sin(k * PI) * level
		_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(sz, sz, sz)), p))
		_multi.set_instance_color(i, Color(tint.r, tint.g, tint.b, 1.0))
