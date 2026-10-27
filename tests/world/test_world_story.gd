extends SceneTree
# The story across the big world: the Massacre's whiteout lands in the world at Black Sand, every
# chapter of the world starts at its zone, Continue follows a walk into the next zone, and scenes
# find their own level's cameras. Saves go to a scratch folder (SaveGame.folder), never to the real one.

var story: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	story = root.get_node("Story")
	SaveGame.folder = "C:/Users/ArmandoSanchez/Documents/Aethereal 3D Godot/aethereal-3d/tests/world/saves"
	DirAccess.make_dir_recursive_absolute(SaveGame.folder)
	for f in DirAccess.get_files_at(SaveGame.folder):
		DirAccess.remove_absolute(SaveGame.folder.path_join(f))  # start with no save
	SaveGame.recording = true

	# 1. The memory ends: whiteout -> the world, at Black Sand.
	var massacre: Node = load("res://scenes/levels/massacre.tscn").instantiate()
	root.add_child(massacre)
	current_scene = massacre
	await _frames(10)
	await _skip()
	story.play("res://data/dialogue/massacre.txt", "whiteout")
	var world := await _wait_for_world()
	print("WHITEOUT: now %s, zone %s, stage %d, player %s" % [world.name if world else "?",
			World.current_level.get_file(), world.stage if world else -1, world.player.global_position if world else Vector3.ZERO])
	await _frames(5)
	var cam := root.get_viewport().get_camera_3d()
	print("WAKING: playing %s, camera %s (in Black Sand: %s)" % [story.playing, cam.name,
			world.get_node("Zones/BlackSand").is_ancestor_of(cam)])
	await _skip(true)
	print("SAVE after whiteout: %s" % SaveGame.last_level().get_file())

	# 2. Walk on into the station: Continue moves there.
	world.player.respawn_at(Vector3(0, -54, -300))
	await _frames(20)  # the zone save waits for a quiet physics tick
	print("WALKED INTO STATION: zone %s, stage %d, save %s, flashlight carried %s" % [World.current_level.get_file(),
			world.stage, SaveGame.last_level().get_file(), world.get_node("Carry").has_node("Flashlight")])

	# 3. Every chapter of the world starts at its zone.
	for entry: Array in Chapters.LIST:
		if not World.has_level(entry[2]):
			continue
		story.go_to_level(entry[2])
		await _frames(2)
		var w := await _wait_for_world(world)
		world = w
		await _frames(10)
		var start: Vector3 = w.zone_of(entry[2]).start_transform(w).origin
		print("CHAPTER %s: zone %s, at start %s, story %s, camera %s, followers %s" % [entry[0],
				World.current_level.get_file(), w.player.global_position.distance_to(start) < 0.5,
				story.playing, root.get_viewport().get_camera_3d().name, _carry(w)])
		await _skip()
	print("PAUSE LABEL: %s" % Chapters.label_of(World.SCENE))

	quit()


func _wait_for_world(old: Node = null) -> World:
	var deadline := Time.get_ticks_msec() + 30000  # real time: headless frames run uncapped
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene is World and current_scene != old and current_scene.is_inside_tree():
			return current_scene
	return null


func _carry(w: World) -> Array:
	var out := []
	for c in w.get_node("Carry").get_children():
		out.append(str(c.name))
	return out


func _skip(verbose := false) -> void:
	var presses := 0
	while story.playing and presses < 60:
		await _frames(8)
		if verbose:
			var cam := root.get_viewport().get_camera_3d()
			print("   camera %s" % cam.get_path())
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await process_frame
		presses += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
