extends SceneTree
# Pictures of the light kit (windowed, not headless): a dark concrete box, one of each prop,
# a few camera angles saved as PNGs. Run: godot --path . -s tests/kit/shoot_kit.gd
# Out folder: KIT_SHOTS env var, or the folder below.

var OUT := "C:/Users/ARMAND~1/AppData/Local/Temp/claude/e70bc487b8c449eb/f215b0e0-de31-41e9-8243-47186cd39de1/scratchpad/wf/kit-light/"
const KIT := "res://scripts/props_kit/"

var cam := Camera3D.new()


func _initialize() -> void:
	if OS.has_environment("KIT_SHOTS"):
		OUT = OS.get_environment("KIT_SHOTS").trim_suffix("/") + "/"
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.37, 0.45)
	env.ambient_light_energy = 0.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.03)
	env.fog_density = 0.015
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	# The room: 16 x 6 x 16 m of dark concrete.
	var concrete := load("res://materials/concrete_dark_worn.tres")
	for b in [[Vector3(16, 0.5, 16), Vector3(0, -0.25, 0)], [Vector3(16, 0.5, 16), Vector3(0, 6.25, 0)],
			[Vector3(16, 6, 0.5), Vector3(0, 3, -8.25)], [Vector3(0.5, 6, 16), Vector3(-8.25, 3, 0)],
			[Vector3(0.5, 6, 16), Vector3(8.25, 3, 0)]]:
		var blk = load("res://scripts/block.gd").new()
		blk.size = b[0]
		blk.material = concrete
		blk.position = b[1]
		world.add_child(blk)
	var post: Node3D = _add(world, "halo_lamp.gd", "HaloPost", Vector3(-4, 0, -2))
	post.rotation.y = 0.35
	var halo_wall: Node3D = _add(world, "halo_lamp.gd", "HaloWall", Vector3(0, 4.6, -8))
	halo_wall.mount = 2
	halo_wall.height = 0.6
	halo_wall.flicker = 1
	var sign: Node3D = _add(world, "neon_sign.gd", "NeonSign", Vector3(4, 3.2, -8))
	sign.flicker = 2
	var blade: Node3D = _add(world, "neon_sign.gd", "NeonBlade", Vector3(6.35, 2.6, 1.5))
	blade.double_sided = true
	blade.bracket = 0.4
	blade.text = "AE THER"
	blade.tint = Color(0.25, 0.9, 1.0)
	blade.glyph_height = 0.32
	blade.rotation.y = PI
	var lamp: Node3D = _add(world, "wall_lamp_sodium.gd", "WallLamp", Vector3(-8, 2.6, 2.5))
	lamp.rotation.y = PI * 0.5
	lamp.flicker = 3
	var ceil_lamp: Node3D = _add(world, "wall_lamp_sodium.gd", "CeilingLamp", Vector3(3, 6, 4))
	ceil_lamp.mount = 1
	var shaft: Node3D = _add(world, "light_shaft.gd", "Shaft", Vector3(0.5, 5.95, 2.5))
	shaft.length = 5.9
	shaft.radius_top = 0.7
	shaft.radius_bottom = 2.2
	var drift: Node3D = _add(world, "drift_lights.gd", "Drift", Vector3(-4, 2.5, 4))
	drift.box_size = Vector3(5, 3, 5)
	drift.random_seed = 3
	world.add_child(cam)
	cam.fov = 70
	cam.current = true
	await _frames(40)
	await _shot("kit_overview", Vector3(1, 2.6, 7.5), Vector3(0, 2.4, -3))
	await _shot("kit_halo_post", Vector3(-2.5, 3.0, 1.5), Vector3(-4, 4.5, -2))
	await _shot("kit_halo_wall", Vector3(0.5, 3.6, -4.5), Vector3(0, 3.9, -8))
	await _shot("kit_neon", Vector3(3.5, 2.8, -4), Vector3(4, 3.2, -8))
	await _shot("kit_blade", Vector3(3.5, 2.6, 5), Vector3(6.4, 2.6, 1.5))
	await _shot("kit_wall_lamp", Vector3(-4.5, 2.2, 3.5), Vector3(-8, 2.6, 2.5))
	await _shot("kit_shaft", Vector3(4.5, 1.8, 6.5), Vector3(0.5, 3.0, 2.5))
	await _frames(90)
	await _shot("kit_drift", Vector3(-1, 2.0, 7.5), Vector3(-4, 2.5, 4))
	print("shots saved to ", OUT)
	quit()


func _add(parent: Node, script: String, name: String, at: Vector3) -> Node3D:
	var n: Node3D = load(KIT + script).new()
	n.name = name
	n.position = at
	parent.add_child(n)
	return n


func _shot(name: String, from: Vector3, to: Vector3) -> void:
	cam.position = from
	cam.look_at(to)
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await process_frame
