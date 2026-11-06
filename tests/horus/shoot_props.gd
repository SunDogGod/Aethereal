extends SceneTree
# Pictures of the Horus props (windowed, not headless): a sand floor under amber fog, one of
# each prop, a camera angle or two per prop, saved as PNGs at the game's 960x540.
# Run: godot --path . -s tests/horus/shoot_props.gd   (out folder: HORUS_SHOTS env var, or below)

var OUT := "C:/Users/ARMAND~1/AppData/Local/Temp/claude/e70bc487b8c449eb/f215b0e0-de31-41e9-8243-47186cd39de1/scratchpad/wf/horus-props/"
const DIR := "res://scripts/props_horus/"

var cam := Camera3D.new()


func _initialize() -> void:
	if OS.has_environment("HORUS_SHOTS"):
		OUT = OS.get_environment("HORUS_SHOTS").trim_suffix("/") + "/"
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.2, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.55, 0.3)
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.36, 0.22, 0.09)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.7, 0.4)
	sun.light_energy = 0.7
	sun.rotation_degrees = Vector3(-38, 30, 0)
	sun.shadow_enabled = false
	world.add_child(sun)
	var sand: Node3D = load("res://scripts/block.gd").new()
	sand.size = Vector3(900, 1, 900)
	sand.material = load("res://materials/horus_sand_heap.tres")
	sand.position = Vector3(0, -0.5, 0)
	world.add_child(sand)
	# One of each, spread out so the fog separates them.
	var pipe := _add("construct_pipe.gd", Vector3(-60, 0, 0))
	pipe.points = PackedVector3Array([Vector3(0, 6, -70), Vector3(0, 6, 10), Vector3(25, 7, 70)])
	pipe.broken = true
	pipe.break_at = 50.0
	pipe.get_node("Spray").emitting = true
	_add("pump_house.gd", Vector3(-60, 0, -80))
	var derrick := _add("derrick.gd", Vector3(60, 0, 0))
	var dead := _add("derrick.gd", Vector3(100, 0, 40))
	dead.lit = false
	dead.variant = 2
	_add("condenser_frame.gd", Vector3(0, 0, 100))
	_add("desert_shack.gd", Vector3(30, 0, 120))
	var obelisk := _add("obelisk.gd", Vector3(0, 0, -200))
	_add("pyramid.gd", Vector3(-150, 0, -330))
	_add("lake.gd", Vector3(100, 0.3, -330))
	_add("causeway_gate.gd", Vector3(100, 0, -260))
	world.add_child(cam)
	cam.fov = 70
	cam.far = 600
	cam.current = true
	await _frames(60)
	await _shot("pipe_broken", Vector3(-46, 3, -32), Vector3(-60, 5, -14))
	await _shot("pipe_break_close", Vector3(-54, 2.5, -2), Vector3(-60, 5, -10))
	await _shot("pipe_pylons", Vector3(-70, 2, -75), Vector3(-60, 6, -30))
	await _shot("pump_house", Vector3(-45, 3, -62), Vector3(-60, 5, -80))
	await _shot("derrick_lit", Vector3(42, 3, 22), Vector3(60, 10, 0))
	await _shot("derrick_dead", Vector3(82, 3, 60), Vector3(100, 9, 40))
	await _shot("condenser", Vector3(-12, 2.2, 112), Vector3(0, 1.2, 100))
	await _shot("shack_front", Vector3(31, 2.0, 131), Vector3(30, 1.2, 122))
	cam.fov = 80
	await _shot("shack_inside", Vector3(31, 1.6, 120.5), Vector3(28, 0.8, 116.5))
	cam.fov = 70
	await _shot("obelisk", Vector3(-30, 3, -150), Vector3(0, 18, -200))
	await _shot("obelisk_foot", Vector3(-6, 2.5, -180), Vector3(0, 6, -200))
	await _shot("pyramid", Vector3(-80, 6, -260), Vector3(-150, 15, -330))
	await _shot("lake_gate", Vector3(96, 3, -232), Vector3(100, 3, -300))
	await _shot("lake", Vector3(60, 4, -262), Vector3(100, 0, -330))
	await _shot("gate_close", Vector3(96, 2, -248), Vector3(100, 5, -260))
	print("shots saved to ", OUT)
	quit()


func _add(script: String, at: Vector3) -> Node3D:
	var n: Node3D = load(DIR + script).new()
	n.position = at
	root.get_child(root.get_child_count() - 1).add_child(n)
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
