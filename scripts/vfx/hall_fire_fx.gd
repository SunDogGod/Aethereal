extends RefCounted
## The moving parts of the hall's bonfire, built in code for hall_bonfire.gd:
##   flames(): layered flame tongues (quads with materials/hall_flame.tres; each one has its own
##             seed and brightness, so they lick up out of step),
##   embers(): chunky sparks rising from the heap and winking out,
##   smoke():  dark puffs climbing into the roof's dark.
## Embers and smoke are GPUParticles3D with StandardMaterial3D draw passes, the same exception as
## steam_vent.gd (the PS1 shader can't read particle transforms). Nothing here is saved in the scene.

const FLAME := preload("res://materials/hall_flame.tres")


## Flame tongues round a heap of radius `r`, feet at `y0`. Returns the quads (the bonfire scales
## their height when it flares). Three layers: tall core tongues, a ring of middle ones, small
## licks near the stones.
static func flames(parent: Node3D, r: float, y0: float, material: Material) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var layers := [
		# count, distance from the centre, width, height, brightness
		[3, 0.2 * r, 1.6, 3.6, 1.0],
		[6, 0.5 * r, 1.15, 2.5, 0.85],
		[8, 0.8 * r, 0.7, 1.3, 0.7],
	]
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.center_offset = Vector3(0, 0.5, 0)  # the quad's foot at its origin
	for layer: Array in layers:
		for i in int(layer[0]):
			var a := TAU * (i + rng.randf_range(-0.2, 0.2)) / float(layer[0])
			var q := MeshInstance3D.new()
			q.name = "Flame%d" % out.size()
			q.mesh = quad
			q.material_override = material
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			q.extra_cull_margin = 3.0  # the quad turns to the camera in the shader
			var w: float = layer[2] * rng.randf_range(0.85, 1.15)
			var h: float = layer[3] * rng.randf_range(0.8, 1.15)
			q.position = Vector3(cos(a) * layer[1], y0 - 0.05, sin(a) * layer[1])
			q.scale = Vector3(w, h, 1.0)
			q.set_meta("base_height", h)
			q.set_instance_shader_parameter("seed", rng.randf_range(0.0, 50.0))
			q.set_instance_shader_parameter("strength", float(layer[4]))
			parent.add_child(q, false, Node.INTERNAL_MODE_FRONT)
			out.append(q)
	return out


## Sparks: tiny square embers that rise, drift and go out, from a disc of radius `r` at `y0`.
static func embers(parent: Node3D, r: float, y0: float) -> GPUParticles3D:
	var p := _particles("Embers", 46, 2.6)
	p.position = Vector3(0, y0, 0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = r * 0.6
	m.direction = Vector3(0, 1, 0)
	m.spread = 20.0
	m.initial_velocity_min = 1.2
	m.initial_velocity_max = 2.6
	m.gravity = Vector3(0, 0.6, 0)  # the heat carries them up
	m.damping_min = 0.3
	m.damping_max = 0.8
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.4
	m.turbulence_noise_scale = 3.0
	m.scale_min = 0.6
	m.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	ramp.set_color(1, Color(0.5, 0.06, 0.02, 0.0))
	ramp.add_point(0.45, Color(1.0, 0.42, 0.1, 1.0))
	m.color_ramp = _ramp_tex(ramp)
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := _unshaded()
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat
	p.draw_pass_1 = quad
	parent.add_child(p, false, Node.INTERNAL_MODE_FRONT)
	return p


## Smoke: dark soft puffs that grow as they climb toward the roof, about `height` metres.
static func smoke(parent: Node3D, r: float, y0: float, height: float) -> GPUParticles3D:
	var p := _particles("Smoke", 22, 5.5)
	p.position = Vector3(0, y0 + 1.6, 0)
	p.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, height + 3.0, 10))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = r * 0.45
	m.direction = Vector3(0, 1, 0)
	m.spread = 12.0
	m.initial_velocity_min = height / 5.5 * 0.7
	m.initial_velocity_max = height / 5.5 * 1.1
	m.gravity = Vector3(0, 0.1, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.7
	m.turbulence_noise_scale = 3.5
	m.scale_min = 0.8
	m.scale_max = 1.2
	var grow := Curve.new()
	grow.max_value = 4.0
	grow.add_point(Vector2(0.0, 0.8))
	grow.add_point(Vector2(1.0, 3.6))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	var tint := Color(0.09, 0.075, 0.07)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint, 0.0))
	ramp.set_color(1, Color(tint, 0.0))
	ramp.add_point(0.2, Color(tint, 0.5))
	ramp.add_point(0.7, Color(tint, 0.32))
	m.color_ramp = _ramp_tex(ramp)
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := _unshaded()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _soft_disc()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # chunky edges, like the rest
	quad.material = mat
	p.draw_pass_1 = quad
	parent.add_child(p, false, Node.INTERNAL_MODE_FRONT)
	return p


static func _particles(node_name: String, amount: int, lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime  # already burning when the hall comes into view
	p.randomness = 0.5
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 9, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _unshaded() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _ramp_tex(g: Gradient) -> GradientTexture1D:
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## A round blob, solid in the middle and fading out at the edge, at 16 px (hard texels).
static func _soft_disc() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.6))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 16
	t.height = 16
	return t
