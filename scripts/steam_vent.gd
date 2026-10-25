extends Node3D
## Steam drifting out of a wall vent: soft grey puffs that rise slowly and fade.
## Place this node where the steam should come out (just in front of the grille) and set
## `direction` to point away from the wall. The particles are built in code.
## The puffs are the one place we use StandardMaterial3D: the PS1 shader is a surface
## shader and can't read particle transforms. They are unshaded and fogged like everything else.

@export var direction := Vector3(0.4, 1.0, 0.0)  ## which way the steam leaves the vent
@export var amount := 14                          ## puffs alive at once
@export var lifetime := 2.8                       ## seconds a puff lives
@export var speed := 0.8                          ## metres per second at the vent
@export var tint := Color(0.7, 0.73, 0.78)       ## the steam's colour (alpha set by the ramp)

var _particles: GPUParticles3D


func _ready() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "Puffs"
	_particles.amount = amount
	_particles.lifetime = lifetime
	_particles.preprocess = lifetime     # already steaming when the level loads
	_particles.randomness = 0.6
	_particles.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	_particles.process_material = _process_material()
	_particles.draw_pass_1 = _puff_mesh()
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)


func _process_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = direction.normalized()
	m.spread = 25.0
	m.initial_velocity_min = speed * 0.7
	m.initial_velocity_max = speed * 1.3
	m.gravity = Vector3(0, 0.25, 0)        # warm air: it keeps rising, gently
	m.damping_min = 0.0
	m.damping_max = 0.1
	m.scale_min = 0.2
	m.scale_max = 0.35
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.2
	# A little turbulence so the plume wavers instead of rising in a column.
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 2.5
	# Grow as they rise.
	var grow := Curve.new()
	grow.max_value = 3.0
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 2.6))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	# Fade in over the first third, hold, fade out: a plume, not a knot at the grille.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint, 0.0))
	ramp.set_color(1, Color(tint, 0.0))
	ramp.add_point(0.3, Color(tint, 0.13))
	ramp.add_point(0.65, Color(tint, 0.11))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	return m


func _puff_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = _soft_disc()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	return quad


## A soft round blob: white in the middle fading to clear at the edge, made in code.
func _soft_disc() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.5))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t
