extends SceneTree
# Headless test of the dialogue system in the Empty Town: each trigger plays its scene,
# cameras cut, lines advance on a button press, and control comes back.

var level: Node
var player: Player
var story: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	print("Story autoload present: %s" % root.has_node("Story"))
	story = root.get_node("Story")
	level = load("res://scenes/levels/empty_town.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	var player_camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")

	# 1. The arrival scene starts by itself: Aeneas starts inside its trigger.
	await _frames(10)
	print("ARRIVAL: playing=%s camera=%s controls=%s" % [story.playing, _camera_name(), player.controls_enabled])
	await _read_all("arrival")
	print("ARRIVAL done: camera back to player=%s controls=%s" % [root.get_viewport().get_camera_3d() == player_camera, player.controls_enabled])

	# 2. Walk into the Kael trigger at the end of the bridge.
	player.respawn_at(Vector3(0, 24, 44))
	await _frames(3)
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
		if story.playing:
			break
	Input.action_release("move_forward")
	print("KAEL: playing=%s camera=%s" % [story.playing, _camera_name()])
	await _read_all("kael_meeting")

	# 3. The overlook balcony: the round-up, and Kael leaves.
	player.respawn_at(Vector3(0, 24, 10))
	await _frames(3)
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
		if story.playing:
			break
	Input.action_release("move_forward")
	print("ROUND-UP: playing=%s camera=%s" % [story.playing, _camera_name()])
	await _read_all("round_up")
	print("ROUND-UP done: Kael visible=%s" % level.find_child("Kael", true, false).visible)

	# 4. The courtyard: Valentina.
	player.respawn_at(Vector3(-7.5, 0.2, -7.0))  # the trigger sits on the courtyard floor now (z -8.85..-6.35)
	for i in 30:
		await physics_frame
		if story.playing:
			break
	print("VALENTINA: playing=%s camera=%s" % [story.playing, _camera_name()])
	await _read_all("valentina")

	# 5. Walking back into a trigger doesn't replay it.
	player.respawn_at(Vector3(0, 24, 42))
	await _frames(10)
	print("REPLAY: Kael scene plays again=%s" % story.playing)
	quit()


## Presses "advance" until the scene ends, printing each line once fully shown.
func _read_all(scene: String) -> void:
	var box = story.get("_box")
	var presses := 0
	while story.playing and presses < 40:
		await _frames(20)
		# First press finishes the typing, second moves on.
		await _press()
		print("   %s | %s" % [box.speaker.text if box.speaker.visible else "(narration)", box.words.text])
		await _press()
		presses += 2
	print("   %s finished after %d presses" % [scene, presses])


func _press() -> void:
	Input.action_press("ui_accept")
	await process_frame
	await process_frame
	Input.action_release("ui_accept")
	await process_frame


func _camera_name() -> String:
	var cam := root.get_viewport().get_camera_3d()
	return cam.name if cam else "(none)"


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
