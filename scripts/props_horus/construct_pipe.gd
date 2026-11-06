@tool
extends "res://scripts/props_horus/horus_prop.gd"
## The Construct's water pipe: 4 m across, riding A-frame pylons across the dunes to Temek's lake.
## Points (local, the pipe's centre line) make the polyline; a flange every 12 m, a pylon every
## Pylon Every metres, its legs reaching down to Ground Y (local) and a little under the sand.
## Broken tears a section open at Break At metres along the line: torn ends, bent plates, a
## trench of churned sand under the gap, and the child `Spray` (GPUParticles3D, white water
## bursting from the upstream mouth) that a scene shows or hides (`$Pipe/Spray.emitting`).
## Solid along the runs and the pylon legs, so you can walk under it and not through it.

@export var points := PackedVector3Array([Vector3(0, 6, 0), Vector3(0, 6, 120)]):
	set(value):
		points = value
		_rebuild()
@export var radius := 2.0:
	set(value):
		radius = value
		_rebuild()
@export var pylon_every := 24.0:
	set(value):
		pylon_every = value
		_rebuild()
## Where the sand is (local Y): the pylons' feet stand here.
@export var ground_y := 0.0:
	set(value):
		ground_y = value
		_rebuild()
@export var broken := false:
	set(value):
		broken = value
		_rebuild()
## Metres along the line where the tear starts, and how long it is.
@export var break_at := 50.0:
	set(value):
		break_at = value
		_rebuild()
@export var break_length := 12.0:
	set(value):
		break_length = value
		_rebuild()

var _spray: GPUParticles3D


func _init() -> void:
	super()
	_spray = GPUParticles3D.new()
	_spray.name = "Spray"
	_spray.emitting = false
	_spray.amount = 70
	_spray.lifetime = 1.6
	_spray.preprocess = 1.0
	_spray.randomness = 0.4
	_spray.visibility_aabb = AABB(Vector3(-20, -12, -20), Vector3(40, 30, 40))
	_spray.process_material = _spray_process()
	_spray.draw_pass_1 = _drop_mesh()
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spray)


func _build() -> void:
	if points.size() < 2:
		return
	var along_x := Basis(Vector3.FORWARD, PI * 0.5)  # a cylinder's Y turned to lie along local X
	var t0 := break_at
	var t1 := break_at + break_length
	var walked := 0.0
	var next_pylon := pylon_every * 0.5
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var dir := (b - a) / length
		# The run, in one or two pieces when the tear falls on it.
		var pieces := [[0.0, length]]
		if broken:
			var s0 := clampf(t0 - walked, 0.0, length)
			var s1 := clampf(t1 - walked, 0.0, length)
			pieces = [[0.0, s0], [s1, length]]
		for p: Array in pieces:
			if p[1] - p[0] > 0.05:
				_run(a + dir * p[0], a + dir * p[1])
		# Flanges every 12 m, pylons every Pylon Every metres, both skipping the gap.
		var f := 12.0 - fmod(walked, 12.0)
		while f < length:
			if not (broken and walked + f > t0 - 1.0 and walked + f < t1 + 1.0):
				_pm.cyl(M.iron_dark, radius * 1.12, radius * 1.12, 0.5, PropMesh.along(a + dir * (f - 0.25), a + dir * (f + 0.25)), 12)
			f += 12.0
		while next_pylon < walked + length:
			var s := next_pylon - walked
			if not (broken and next_pylon > t0 - 3.0 and next_pylon < t1 + 3.0):
				_pylon(a + dir * s, dir)
			next_pylon += pylon_every
		if broken:
			if t0 >= walked and t0 < walked + length:
				_mouth(a + dir * (t0 - walked), dir, true)
			if t1 > walked and t1 <= walked + length:
				_mouth(a + dir * (t1 - walked), -dir, false)
			if t0 >= walked and t0 < walked + length:
				_trench(a + dir * (t0 - walked), dir)
		walked += length
	for i in range(1, points.size() - 1):  # a fat collar at every bend
		_pm.sphere(M.iron_dark, radius * 1.1, radius * 2.2, Transform3D(Basis(), points[i]), 10, 5)
	_spray.emitting = broken and _spray.emitting


## A straight length of pipe from a to b, with its collision.
func _run(a: Vector3, b: Vector3) -> void:
	var l := a.distance_to(b)
	_pm.cyl(M.iron, radius, radius, l, PropMesh.along(a, b), 12, clampi(int(l / 6.0), 0, 20))
	_boxes.append([Vector3(radius * 1.8, l, radius * 1.8), PropMesh.along(a, b)])


## An A-frame pylon under the pipe at p: two splayed legs across the line meeting at a saddle,
## a tie halfway, concrete feet, a strap over the pipe.
func _pylon(p: Vector3, dir: Vector3) -> void:
	var across := dir.cross(Vector3.UP).normalized()
	var saddle := p - Vector3(0, radius + 0.3, 0)
	var foot_y := ground_y - 1.5
	var spread := (saddle.y - ground_y) * 0.45 + 1.0
	for s: float in [-1.0, 1.0]:
		var foot := Vector3(p.x, foot_y, p.z) + across * spread * s
		_solid_stick(M.iron_dark, foot, saddle + across * 0.9 * s, 0.5)
		_pm.box(M.concrete, Vector3(2.0, 1.2, 2.0), Transform3D(Basis(), Vector3(p.x, ground_y - 0.2, p.z) + across * spread * s))
		_boxes.append([Vector3(2.0, 1.2, 2.0), Transform3D(Basis(), Vector3(p.x, ground_y - 0.2, p.z) + across * spread * s)])
	var mid_y := lerpf(foot_y, saddle.y, 0.5)
	var mid_spread := lerpf(spread, 0.9, 0.5)
	_pm.stick(M.iron_dark, Vector3(p.x, mid_y, p.z) - across * mid_spread, Vector3(p.x, mid_y, p.z) + across * mid_spread, 0.25)
	_pm.box(M.iron_dark, Vector3(radius * 2.6, 0.5, 1.2), Transform3D(Basis.looking_at(dir, Vector3.UP), saddle))
	_pm.cyl(M.iron_dark, radius * 1.06, radius * 1.06, 0.4, PropMesh.along(p - dir * 0.2, p + dir * 0.2), 12)  # the strap


## A torn end at p: a dark mouth, bent plates peeled back round it, a sag of the stub.
## `upstream` is the end the water comes from: the Spray sits there.
func _mouth(p: Vector3, dir: Vector3, upstream: bool) -> void:
	_pm.cyl(M.hole, radius * 0.94, radius * 0.94, 0.15, PropMesh.along(p - dir * 0.3, p - dir * 0.15), 12)
	var across := dir.cross(Vector3.UP).normalized()
	var n := 5
	for k in n:
		var ang := TAU * k / n + _r.randf_range(-0.3, 0.3)
		var out := (across * cos(ang) + Vector3.UP * sin(ang)).normalized()
		var root := p + out * radius
		var tip := root + dir * _r.randf_range(1.2, 2.6) + out * _r.randf_range(0.8, 2.0)
		_pm.stick(M.iron_dark, root, tip, 0.14)
		_pm.box(M.iron, Vector3(1.1, 0.1, 1.6), Transform3D(Basis.looking_at(tip - root, out).rotated(dir, 0.2), (root + tip) * 0.5))
	if upstream:
		_spray.position = p + dir * 0.5 - Vector3(0, radius * 0.4, 0)
		(_spray.process_material as ParticleProcessMaterial).direction = dir + Vector3(0, 0.5, 0) + across * 0.3


## Churned sand under the gap: a dark strip between two ridges of thrown-up sand, and the
## pipe's fallen middle lying crumpled in it.
func _trench(p: Vector3, dir: Vector3) -> void:
	var across := dir.cross(Vector3.UP).normalized()
	var mid := Vector3(p.x, ground_y, p.z) + dir * break_length * 0.5
	var basis := Basis.looking_at(dir, Vector3.UP)
	_pm.box(M.churned, Vector3(radius * 4.0, 0.3, break_length + 6.0), Transform3D(basis, mid - Vector3(0, 0.08, 0)))
	for s: float in [-1.0, 1.0]:
		for k in 3:
			var q := mid + across * (radius * 2.2 + _r.randf_range(0.0, 1.0)) * s + dir * (k - 1) * break_length * 0.33
			_ball(M.sand, Vector3(2.2, 1.0, break_length * 0.22), Transform3D(basis, q + Vector3(0, 0.1, 0)), 8, 4)
	# The fallen section: two crushed drums and a few plates.
	for k in 2:
		var q := mid + dir * (k - 0.5) * break_length * 0.35 + across * _r.randf_range(-1.5, 1.5)
		var roll := Basis(dir, _r.randf_range(-0.5, 0.5)) * Basis(across, _r.randf_range(-0.2, 0.2))
		_pm.cyl(M.iron, radius * 0.9, radius * 0.7, break_length * 0.3, Transform3D(roll * basis.rotated(across, PI * 0.5), q + Vector3(0, radius * 0.5, 0)), 10, 1)
		_boxes.append([Vector3(radius * 1.6, radius * 1.2, break_length * 0.3), Transform3D(basis, q + Vector3(0, radius * 0.5, 0))])
	for k in 4:
		var q := mid + dir * _r.randf_range(-break_length * 0.5, break_length * 0.5) + across * _r.randf_range(-radius * 2.0, radius * 2.0)
		_pm.box(M.iron_dark, Vector3(1.6, 0.1, 2.2), Transform3D(Basis(Vector3.UP, _r.randf() * TAU) * Basis(Vector3.RIGHT, _r.randf_range(-0.4, 0.4)), q + Vector3(0, 0.3, 0)))


func _spray_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0.5, 1)
	m.spread = 14.0
	m.initial_velocity_min = 10.0
	m.initial_velocity_max = 15.0
	m.gravity = Vector3(0, -9.0, 0)
	m.scale_min = 0.5
	m.scale_max = 1.1
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.9, 0.95, 0.55))
	ramp.set_color(1, Color(0.85, 0.9, 0.95, 0.0))
	ramp.add_point(0.6, Color(0.85, 0.9, 0.95, 0.4))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	return m


## A white drop, a soft disc like steam_vent.gd's puff (the one StandardMaterial3D allowed:
## the PS1 shader cannot read particle transforms).
func _drop_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	mat.albedo_texture = t
	quad.material = mat
	return quad
