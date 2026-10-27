extends SceneTree
# Headless test of the inspect prompts: loads a COPY of the town (env TEST_SCENE), puts Aeneas
# beside the well facing it, expects the Look prompt, presses "interact" and reads the narration.

var level: Node
var player: Player
var story: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	story = root.get_node("Story")
	var path := OS.get_environment("TEST_SCENE")
	level = load(path).instantiate()
	# No story triggers: the arrival scene would otherwise start on its own.
	level.get_node("StoryTriggers").free()
	root.add_child(level)
	current_scene = level
	await _frames(3)  # let the level enter the tree and everything run _ready
	player = level.get_node("Player")
	var hud = player.get_node("Hud")
	print("interact action registered: %s" % InputMap.has_action("interact"))
	print("Inspect node: %d interactables" % level.get_node("Inspect").get_child_count())

	# 1. Beside the well, facing it.
	player.respawn_at(Vector3(0, 0.2, 2.6))
	player.face(Vector3(0, 0, 0))
	await _frames(20)
	print("WELL prompt: '%s' visible=%s" % [hud.prompt.text, hud.prompt.visible])

	# 2. Turn his back on it: the prompt should go.
	player.face(Vector3(0, 0, 10))
	await _frames(5)
	print("BACK TURNED prompt: '%s' visible=%s" % [hud.prompt.text, hud.prompt.visible])
	player.face(Vector3(0, 0, 0))
	await _frames(5)

	# 3. Press E.
	Input.action_press("interact")
	await _frames(3)
	Input.action_release("interact")
	await _frames(5)
	var box = story.get("_box")
	print("AFTER E: playing=%s controls=%s cutscene=%s prompt visible=%s" % [story.playing, player.controls_enabled, player.in_cutscene, hud.prompt.visible])
	print("   speaker shown=%s | %s" % [box.speaker.visible, box.words.text])
	var went_true: bool = story.playing
	var presses := 0
	while story.playing and presses < 12:
		await _frames(20)
		await _press()
		print("   line: %s" % box.words.text)
		await _press()
		presses += 2
	await _frames(3)
	print("NARRATION over: went true=%s now playing=%s controls=%s cutscene=%s presses=%d" % [went_true, story.playing, player.controls_enabled, player.in_cutscene, presses])
	await _frames(5)
	print("PROMPT back: '%s' visible=%s" % [hud.prompt.text, hud.prompt.visible])

	# 4. The others: stand in each and read the prompt (text from the file by node name).
	for check: Array in [
			["DoorlessShop", Vector3(-1.6, 24.2, 17.5), Vector3(-3, 24, 17.5)],
			["DroppedBasket", Vector3(-14.8, 8.2, 7.9), Vector3(-14, 8, 7.9)],
			["RunningTap", Vector3(-3.5, 0.2, 2.0), Vector3(-3.5, 0, 0.75)],  # round 5: the tap is at the well
			["AgencyPoster", Vector3(-18.4, 8.2, 2), Vector3(-17, 8, 2)],
			["DeadVending", Vector3(-0.9, 24.2, 22), Vector3(-3, 24, 22)],
			["Laundry", Vector3(-18.5, 8.2, -3), Vector3(-18.5, 8, -3)],
			["HallDoor", Vector3(0, 0.2, -7), Vector3(0, 0, -9)]]:
		var name: String = check[0]
		var stand: Vector3 = check[1]
		var look_at: Vector3 = check[2]
		player.respawn_at(stand)
		player.face(look_at)
		await _frames(15)
		var lines: Array = level.get_node("Inspect/" + name)._lines()
		print("%s: prompt '%s' | %d lines, first: %s" % [name, hud.prompt.text if hud.prompt.visible else "(none)", lines.size(), lines[0] if lines.size() > 0 else "-"])
	quit()


func _press() -> void:
	Input.action_press("ui_accept")
	await process_frame
	await process_frame
	Input.action_release("ui_accept")
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
