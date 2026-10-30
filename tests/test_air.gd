extends SceneTree
# Headless: the double jump and landing-speed damage (player_air.gd), on a bare floor.
# Locked he jumps once; unlocked he jumps twice and goes higher. A small drop does nothing, a
# middling one hurts, a long one is a fall, and a double jump just above the floor saves him.

var player: Player
var fell := false


func _initialize() -> void:
	_run()


func _run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	level.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	level.add_child(player)
	player.fell.connect(func() -> void: fell = true)
	var combat: PlayerCombat = player.get_node("Combat")
	var ok := true
	await process_frame

	var one := await _peak(false)
	var two := await _peak(true)
	print("AIR: peak locked %.2f m, unlocked %.2f m" % [one, two])
	ok = ok and one < 1.7 and two > one + 0.8

	for drop in [2.5, 4.5, 8.0]:
		combat.heal_full()
		fell = false
		player.falling_back = false
		player.respawn_at(Vector3(0, drop, 0))
		await _settle()
		var lost := combat.max_health - combat.health
		print("AIR: drop %.1f m -> lost %.0f health, fell %s" % [drop, lost, fell])
		if drop == 2.5:
			ok = ok and lost == 0.0 and not fell
		elif drop == 4.5:
			ok = ok and lost > 0.0 and not fell
		else:
			ok = ok and fell

	# The save: an 8 m drop, double jump about a metre above the floor.
	player.double_jump_unlocked = true
	combat.heal_full()
	fell = false
	player.falling_back = false
	player.respawn_at(Vector3(0, 8.0, 0))
	for i in 3:
		await physics_frame
	_give_air_jump()
	while player.global_position.y > 1.0:
		await physics_frame
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await _settle()
	var saved_lost := combat.max_health - combat.health
	print("AIR: 8 m drop with a late double jump -> lost %.0f, fell %s" % [saved_lost, fell])
	ok = ok and not fell

	print("AIR %s" % ("PASS" if ok else "FAIL"))
	quit()


## Jump, press jump again at the top, and return the highest point he reached.
func _peak(unlocked: bool) -> float:
	player.double_jump_unlocked = unlocked
	player.respawn_at(Vector3.ZERO)
	await _settle()
	Input.action_press("jump")
	var top := 0.0
	var pressed_again := false
	for i in 120:
		await physics_frame
		top = maxf(top, player.global_position.y)
		if not pressed_again and player.velocity.y <= 0.0 and i > 5:
			Input.action_release("jump")
			await physics_frame
			Input.action_press("jump")
			pressed_again = true
		if i > 10 and player.is_on_floor():
			break
	Input.action_release("jump")
	await _settle()
	return top


func _settle() -> void:
	for i in 10:
		await physics_frame
	while not player.is_on_floor():
		await physics_frame
	for i in 3:
		await physics_frame


## Dropped in from a respawn he never touched the floor, so give him his air jump by hand.
func _give_air_jump() -> void:
	player._air._air_jumps = 1
