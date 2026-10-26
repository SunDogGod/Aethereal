extends Node3D
## Aeneas's raw aether bursting out of him (Isabella's seal released): a white-hot flash that
## swells round him, a shockwave shell racing out through the hall (shaders/hall_burst.gdshader),
## a flash of light that floods the room, sparks of aether flung out in every direction, and the
## camera shaken. Then hall_crackle.gd keeps a crackling aura on him while the eruption lasts.
## burst(who) makes one at his chest; it frees itself when it is spent. Made in code only.

const SHADER := preload("res://shaders/hall_burst.gdshader")
const HallCrackle := preload("res://scripts/vfx/hall_crackle.gd")
const LIFE := 2.6

var strength := 1.0
var _t := 0.0
var _flash := MeshInstance3D.new()
var _shell := MeshInstance3D.new()
var _flash_mat := ShaderMaterial.new()
var _shell_mat := ShaderMaterial.new()
var _light := OmniLight3D.new()
var _camera: Camera3D
var _camera_rest := Vector2.ZERO


## The burst round `who` (Aeneas). Shakes whatever camera is showing.
static func burst(who: Node3D, strength := 1.0) -> Node3D:
	if who == null or not who.is_inside_tree():
		return null
	var b: Node3D = load("res://scripts/vfx/hall_burst.gd").new()
	b.set("strength", strength)
	who.get_parent().add_child(b)
	b.global_position = who.global_position + Vector3(0, 1.0, 0)
	HallCrackle.on(who)
	return b


func _ready() -> void:
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 16
	ball.rings = 8
	_flash_mat.shader = SHADER
	_flash_mat.render_priority = 3
	_flash_mat.set_shader_parameter("fill", 1.0)
	_shell_mat.shader = SHADER
	_shell_mat.render_priority = 3
	_shell_mat.set_shader_parameter("fill", 0.0)
	for pair in [[_flash, _flash_mat], [_shell, _shell_mat]]:
		var mi: MeshInstance3D = pair[0]
		mi.mesh = ball
		mi.material_override = pair[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 16.0
		mi.scale = Vector3.ONE * 0.2
		add_child(mi)
	_light.light_color = Color(0.75, 0.92, 1.0)
	_light.omni_range = 30.0
	_light.omni_attenuation = 0.7
	_light.light_energy = 0.0
	add_child(_light)
	add_child(_sparks())
	_camera = get_viewport().get_camera_3d()
	if _camera:
		_camera_rest = Vector2(_camera.h_offset, _camera.v_offset)


func _process(delta: float) -> void:
	_t += delta
	# The flash: swells fast, burns, then sinks back into him.
	var f := _t / 0.25
	var flash_size := lerpf(0.3, 3.2 * strength, ease(minf(f, 1.0), 0.4)) * (1.0 if _t < 0.6 else maxf(1.0 - (_t - 0.6) / 0.9, 0.05))
	_flash.scale = Vector3.ONE * flash_size
	_flash_mat.set_shader_parameter("fade", clampf(1.3 - _t / 1.2, 0.0, 1.0))
	# The shockwave shell: out through the hall in under a second.
	var s := _t / 0.8
	_shell.scale = Vector3.ONE * lerpf(0.5, 12.0 * strength, ease(minf(s, 1.0), 0.35))
	_shell_mat.set_shader_parameter("fade", clampf(1.0 - s, 0.0, 1.0) * 1.6)
	_shell.visible = s < 1.0
	# The light: a white flood, then gone.
	_light.light_energy = 14.0 * strength * (minf(_t / 0.06, 1.0)) * clampf(1.0 - (_t - 0.1) / 1.4, 0.0, 1.0)
	# The camera shakes hard, then settles.
	if is_instance_valid(_camera):
		var shake := 0.22 * strength * clampf(1.0 - _t / 1.1, 0.0, 1.0)
		_camera.h_offset = _camera_rest.x + sin(_t * 61.0) * shake
		_camera.v_offset = _camera_rest.y + sin(_t * 47.0 + 1.3) * shake * 0.7
	if _t >= LIFE:
		_settle_camera()
		queue_free()


func _exit_tree() -> void:
	_settle_camera()


func _settle_camera() -> void:
	if is_instance_valid(_camera):
		_camera.h_offset = _camera_rest.x
		_camera.v_offset = _camera_rest.y


## Sparks of aether flung out all round, slowing in the air (a particle draw pass, like the
## fire's embers: the one place the PS1 shader can't be used).
func _sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 1.6
	p.one_shot = true
	p.explosiveness = 0.92
	p.randomness = 0.5
	p.visibility_aabb = AABB(Vector3(-16, -4, -16), Vector3(32, 16, 32))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.4
	m.direction = Vector3(0, 0.3, 0)
	m.spread = 180.0
	m.initial_velocity_min = 8.0
	m.initial_velocity_max = 19.0
	m.damping_min = 6.0
	m.damping_max = 11.0
	m.gravity = Vector3(0, -1.5, 0)
	m.scale_min = 0.7
	m.scale_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(0.3, 0.1, 0.6, 0))
	ramp.add_point(0.25, Color(0.55, 0.9, 1.0, 1))
	ramp.add_point(0.65, Color(0.55, 0.3, 1.0, 1))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	m.color_ramp = tex
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	p.draw_pass_1 = quad
	p.emitting = true
	return p
