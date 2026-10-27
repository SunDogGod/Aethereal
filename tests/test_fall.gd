extends SceneTree
# Falling off the bridge sends Aeneas back to the last checkpoint (the bridge end), with the
# FELL card, healed and in control again.

var story: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	story = root.get_node("Story")
	var level: Node = load("res://scenes/levels/empty_town.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Player = level.get_node("Player")
	var director: Node = level.get_node("StealthDirector")
	var message: Label = director.get_node("Screen/Message")
	await _frames(10)
	await _skip()
	# Walk to the bridge end checkpoint, then skip Kael's scene.
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation.y = 0.0
	Input.action_press("move_forward")
	for i in 900:
		await physics_frame
		if player.global_position.z < 33.5:
			break
		if story.playing:
			Input.action_release("move_forward")
			await _skip()
			Input.action_press("move_forward")
	Input.action_release("move_forward")
	await _frames(5)
	print("at bridge end: %s" % player.global_position)
	# Off the edge.
	player.global_position = Vector3(6, 24, 60)
	var seen_card := ""
	for i in 300:
		await physics_frame
		if message.visible and seen_card == "":
			seen_card = message.text
	print("FALL: card '%s', back at %s (checkpoint ~(0,24,33)), controls %s, Isabella at %s" % [
			seen_card, player.global_position, player.controls_enabled, level.get_node("Isabella").global_position])
	quit()


func _skip() -> void:
	var presses := 0
	while story.playing and presses < 60:
		await _frames(6)
		Input.action_press("ui_accept")
		await process_frame
		await process_frame
		Input.action_release("ui_accept")
		await process_frame
		presses += 1
	await _frames(5)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
