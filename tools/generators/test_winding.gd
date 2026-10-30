extends SceneTree
# Is the Block mesh inside out? Put a camera INSIDE a closed Block: with correct winding every
# face is culled and the frame is pure background colour; inside out, you see the walls.
# Then a camera OUTSIDE looking at a Block in front of a contrasting backdrop.

const OUT := "C:/Users/ArmandoSanchez/Documents/Aethereal 3D Godot/aethereal-3d/tools/generators/out/"


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 1)  # magenta background: anything else is geometry
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var block = load("res://scripts/block.gd").new()
	block.size = Vector3(6, 6, 6)
	block.material = load("res://materials/dev_grid.tres")
	world.add_child(block)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 0, 0)  # inside
	cam.current = true
	await _frames(5)
	await _shot("inside")
	cam.position = Vector3(0, 2, 12)  # outside, looking at the block
	cam.look_at(Vector3.ZERO)
	await _frames(5)
	await _shot("outside")
	# Count magenta pixels in each to decide.
	for name in ["inside", "outside"]:
		var img := Image.load_from_file(OUT + name + ".png")
		var magenta := 0
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				var c := img.get_pixel(x, y)
				if c.r > 0.8 and c.g < 0.3 and c.b > 0.8:
					magenta += 1
		var total := (img.get_width() / 4) * (img.get_height() / 4)
		print("%s: %.0f%% background" % [name, 100.0 * magenta / total])
	print("Correct winding => inside ~100% background, outside well under 100%.")
	quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
