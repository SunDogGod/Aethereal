extends SceneTree
# The Horus desert builder (scripts/props_horus/desert_terrain.gd): a 300 x 300 m desert with a
# road, pads and a rim. Headless: chunks, up-facing triangles, rays down at random points and
# along the road (hits, heights, slopes), pads level, the rim higher, a ball rests on the sand.
# Windowed (no --headless): also screenshots across the dunes in amber fog, from under the
# terrain (must show only the background: the faces are culled from below) and from above.
#   godot --headless --path PROJ -s tests/horus/test_terrain.gd
#   godot --path PROJ -s tests/horus/test_terrain.gd      (screenshots too)

var OUT := "C:/Users/ARMAND~1/AppData/Local/Temp/claude/e70bc487b8c449eb/f215b0e0-de31-41e9-8243-47186cd39de1/scratchpad/wf/horus-terrain/"
const AT := Vector3(10.0, 3.0, -20.0)  # the desert sits off the origin: road and pads are world metres
const ROAD := [Vector3(0, 5, 125), Vector3(20, 6.5, 80), Vector3(-15, 9, 0), Vector3(25, 12, -80), Vector3(0, 16, -150)]
const PADS := [Vector3(-40, 7, 40), Vector3(50, 10, -30)]

var fails := 0
var terrain: StaticBody3D
var world := Node3D.new()
var env := Environment.new()
var cam := Camera3D.new()


func _initialize() -> void:
	if OS.has_environment("TERRAIN_SHOTS"):
		OUT = OS.get_environment("TERRAIN_SHOTS").trim_suffix("/") + "/"
	_run()


func _run() -> void:
	root.add_child(world)
	var t0 := Time.get_ticks_msec()
	terrain = load("res://scripts/props_horus/desert_terrain.gd").new()
	terrain.size = Vector2(300, 300)
	terrain.seed = 5
	terrain.amplitude = 9.0
	terrain.road = PackedVector3Array(ROAD)
	terrain.road_width = 12.0
	terrain.pads = PackedVector3Array(PADS)
	terrain.pad_radius = 14.0
	terrain.rim = 12.0
	terrain.material = load("res://materials/horus_sand.tres")
	terrain.position = AT
	world.add_child(terrain)
	print("built in %d ms" % (Time.get_ticks_msec() - t0))
	for i in 3:
		await physics_frame
	_check_chunks()
	_check_normals()
	await _check_rays()
	await _check_ball()
	if DisplayServer.get_name() != "headless":
		await _shots()
	print("PASS" if fails == 0 else "FAIL (%d problems)" % fails)
	quit()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL: ", what)


func _check_chunks() -> void:
	var chunks := []
	for c in terrain.get_children(true):
		if c is MeshInstance3D:
			chunks.append(c)
	print("chunks: %d (expect 25 for 300 m at 64 m)" % chunks.size())
	_ok(chunks.size() == 25, "chunk count")
	_ok(terrain.get_children().is_empty(), "nothing of the terrain would be saved into a scene")


## Every vertex normal points up, and every triangle, read with Godot's clockwise-front rule,
## faces up too (Plane's three-point constructor assumes clockwise).
func _check_normals() -> void:
	var tris := 0
	var bad := 0
	var bad_n := 0
	for c in terrain.get_children(true):
		if not (c is MeshInstance3D):
			continue
		var arr: Array = (c as MeshInstance3D).mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for k in n.size():
			if n[k].y <= 0.0:
				bad_n += 1
		for t in idx.size() / 3:
			tris += 1
			if Plane(v[idx[t * 3]], v[idx[t * 3 + 1]], v[idx[t * 3 + 2]]).normal.y <= 0.0:
				bad += 1
	print("triangles: %d, facing down: %d, vertex normals down: %d" % [tris, bad, bad_n])
	_ok(bad == 0 and bad_n == 0, "faces up")


func _ray(x: float, z: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 200, z), Vector3(x, -200, z), 1)
	q.hit_back_faces = false
	return root.get_world_3d().direct_space_state.intersect_ray(q)


func _check_rays() -> void:
	await physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var misses := 0
	var off := 0.0
	var steep := 0.0
	var steep_inner := 0.0  # away from the rim wall
	for i in 50:
		var x := AT.x + rng.randf_range(-149.0, 149.0)
		var z := AT.z + rng.randf_range(-149.0, 149.0)
		var hit := _ray(x, z)
		if hit.is_empty() or hit.collider != terrain:
			misses += 1
			continue
		off = maxf(off, absf(hit.position.y - terrain.height_at(x, z)))
		var deg := rad_to_deg(acos(hit.normal.y))
		steep = maxf(steep, deg)
		if absf(x - AT.x) < 110.0 and absf(z - AT.z) < 110.0:
			steep_inner = maxf(steep_inner, deg)
	print("random: %d misses of 50, height_at off by %.3f m at most, steepest %.1f deg (%.1f away from the rim)" % [misses, off, steep, steep_inner])
	_ok(misses == 0, "every random ray hits the sand")
	_ok(off < 0.05, "height_at matches the collision")
	# Along the road and near its edges: level across, under 25 degrees along.
	var road_misses := 0
	var road_off := 0.0
	var road_steep := 0.0
	for s in ROAD.size() - 1:
		var a: Vector3 = ROAD[s]
		var b: Vector3 = ROAD[s + 1]
		var side := Vector3(b.z - a.z, 0, -(b.x - a.x)).normalized()
		for k in 10:
			var t := (k + 0.5) / 10.0
			var p: Vector3 = a.lerp(b, t)
			for w in [-5.0, 0.0, 5.0]:
				var at: Vector3 = p + side * w
				var hit := _ray(at.x, at.z)
				if hit.is_empty():
					road_misses += 1
					continue
				road_off = maxf(road_off, absf(hit.position.y - p.y))
				road_steep = maxf(road_steep, rad_to_deg(acos(hit.normal.y)))
	print("road: %d misses, off the road's height by %.3f m at most, steepest %.1f deg" % [road_misses, road_off, road_steep])
	_ok(road_misses == 0 and road_off < 0.3, "the road is at its points' heights")
	_ok(road_steep < 25.0, "the road is walkable (under 25 degrees)")
	for pad: Vector3 in PADS:
		var worst := 0.0
		for k in 8:
			var at: Vector3 = pad + Vector3(cos(k), 0, sin(k)) * 11.0
			worst = maxf(worst, absf(terrain.height_at(at.x, at.z) - pad.y))
		worst = maxf(worst, absf(terrain.height_at(pad.x, pad.z) - pad.y))
		print("pad %s: off by %.3f m at most" % [pad, worst])
		_ok(worst < 0.05, "pad is level")
	# The rim: the border stands well above the middle.
	var edge := 0.0
	var inner := 0.0
	for k in 20:
		var x := AT.x - 140.0 + 14.0 * k
		edge += terrain.height_at(x, AT.z - 149.0) + terrain.height_at(x, AT.z + 149.0)
		inner += terrain.height_at(x, AT.z - 100.0) + terrain.height_at(x, AT.z + 100.0)
	print("rim: border averages %.1f m, 50 m in %.1f m" % [edge / 40.0, inner / 40.0])
	_ok(edge / 40.0 > inner / 40.0 + 6.0, "the rim is a wall")
	_ok(absf(terrain.height_at(AT.x + 400.0, AT.z) - terrain.height_at(AT.x + 150.0, AT.z)) < 0.001, "height_at past the edge holds")


## A ball dropped on a dune comes to rest on the sand, not through it.
func _check_ball() -> void:
	var ball := RigidBody3D.new()
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	col.shape = sphere
	ball.add_child(col)
	ball.collision_mask = 1
	var at := Vector3(AT.x + 60.0, 0, AT.z + 60.0)
	ball.position = Vector3(at.x, terrain.height_at(at.x, at.z) + 6.0, at.z)
	world.add_child(ball)
	for i in 240:
		await physics_frame
	var floor_y: float = terrain.height_at(ball.position.x, ball.position.z)
	print("ball: at y %.2f, sand under it %.2f (radius 0.5), speed %.2f" % [ball.position.y, floor_y, ball.linear_velocity.length()])
	_ok(ball.position.y > floor_y and ball.position.y < floor_y + 1.2, "the ball rests on the sand")
	ball.queue_free()


# ---------------------------------------------------------------- windowed screenshots
func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.9, 0.7, 0.45)
	sun.light_energy = 0.35
	sun.rotation_degrees = Vector3(-62, 35, 0)
	world.add_child(sun)
	world.add_child(cam)
	cam.fov = 65
	cam.far = 400
	cam.current = true
	_amber(true)
	await _frames(30)
	var r := Vector3(0, 6.5, 80) + Vector3(0, 1.7, 0)
	await _shot("dunes_road", r, Vector3(-15, 10, 0))
	await _shot("dunes_across", Vector3(AT.x + 60, terrain.height_at(AT.x + 60, AT.z + 20) + 2.0, AT.z + 20), Vector3(AT.x - 80, 8, AT.z - 120))
	await _shot("dunes_high", Vector3(AT.x, 60, AT.z + 170), Vector3(AT.x, 6, AT.z - 40))
	# Winding: a magenta background and no fog. From under the sand, looking steeply up (so the
	# rim wall's inner slope at the far edge stays out of view), only magenta should show.
	_amber(false)
	await _frames(5)
	var below := Vector3(AT.x + 20, AT.y - 6.0, AT.z + 20)
	await _shot("winding_below", below, below + Vector3(0, 10, -2))
	var above := Vector3(AT.x + 20, terrain.height_at(AT.x + 20, AT.z + 20) + 3.0, AT.z + 20)
	await _shot("winding_above", above, above + Vector3(0, -2, -10))
	var pct_below := _background("winding_below")
	var pct_above := _background("winding_above")
	print("from below: %.0f%% background (expect ~100), from above: %.0f%% (expect well under)" % [pct_below, pct_above])
	_ok(pct_below > 99.0, "nothing of the sand shows from below")
	_ok(pct_above < 60.0, "the sand shows from above")
	print("shots saved to ", OUT)


func _amber(on: bool) -> void:
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.48, 0.32)
	env.ambient_light_energy = 0.5
	env.fog_enabled = on
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.45, 0.3, 0.14)
	env.fog_density = 1.0
	env.fog_depth_begin = 6.0
	env.fog_depth_end = 180.0
	env.fog_sky_affect = 0.0
	env.background_color = Color(0.45, 0.3, 0.14) if on else Color(1, 0, 1)


func _background(name: String) -> float:
	var img := Image.load_from_file(OUT + name + ".png")
	var magenta := 0
	var total := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			total += 1
			if c.r > 0.8 and c.g < 0.3 and c.b > 0.8:
				magenta += 1
	return 100.0 * magenta / total


func _shot(name: String, from: Vector3, to: Vector3) -> void:
	cam.position = from
	cam.look_at(to)
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await process_frame
