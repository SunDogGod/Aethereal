extends SceneTree
# Loads the big world at each chapter's zone and prints what the world set up there.

const LEVELS := ["res://scenes/levels/empty_town.tscn", "res://scenes/levels/black_sand.tscn",
		"res://scenes/levels/vacuum_station.tscn"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var story: Node = root.get_node("Story")
	for path in LEVELS:
		var t0 := Time.get_ticks_msec()
		World.pending_level = path
		var world: World = load(World.SCENE).instantiate()
		root.add_child(world)
		current_scene = world
		var t1 := Time.get_ticks_msec()
		for i in 30:
			await physics_frame
		var p: Player = world.player
		var shown := []
		for z in world.zones:
			if z.visible:
				shown.append(z.name)
		var carry := []
		for c in world.get_node("Carry").get_children():
			carry.append("%s(leader=%s, visible=%s)" % [c.name, c.get("leader") != null if "leader" in c else "-", c.visible])
		var gate := world.find_child("WorldServiceGate", true, false)
		print("== ", path.get_file(), "  load %d ms" % (t1 - t0))
		print("  stage=%d current_level=%s shown=%s" % [world.stage, World.current_level.get_file(), shown])
		print("  player at %s on_floor=%s fall_limit=%.1f" % [p.global_position, p.is_on_floor(), p.fall_limit])
		print("  carry=%s" % [carry])
		print("  gate shut=%s  story playing=%s  env bg=%d fog=%s" % [gate.visible if gate else "?", story.playing,
				world.get_node("WorldEnvironment").environment.background_mode,
				world.get_node("WorldEnvironment").environment.fog_light_color])
		print("  players in tree=%d directors=%d guards=%d checkpoints=%d" % [get_nodes_in_group("player").size(),
				world.find_children("StealthDirector", "", true, false).size(),
				get_nodes_in_group("guards").size(), get_nodes_in_group("checkpoints").size()])
		print("  label=%s" % Chapters.label_of(World.SCENE))
		if story.playing:
			story.stop()
		root.remove_child(world)
		world.free()
		await process_frame
	quit()
