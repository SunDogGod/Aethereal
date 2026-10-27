extends SceneTree
# Headless: swings without lock-on aim themselves (soft assist). An agent 2.6 m away at 55° off
# Aeneas's facing gets turned to and hit; one behind him is ignored; the camera never moves.

var player: Player
var combat: PlayerCombat


func _initialize() -> void:
	_run()


func _run() -> void:
	var level: Node = load("res://scenes/test_yard.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	combat = player.get_node("Combat")
	level.get_node("Isabella").queue_free()
	await _frames(10)
	var ok := true
	# Aeneas faces -z (yaw 0). Agent at 55° to his right, 2.6 m away.
	player.model.rotation.y = 0.0
	var ang := deg_to_rad(-55.0)
	var g := _agent(level, player.global_position + Vector3(-sin(ang), 0, -cos(ang)) * 2.6)
	await _frames(5)
	g.engage()
	g.dormant = false
	var cam_yaw: float = player.camera_pivot.global_rotation.y
	var h0 := g.health
	await _tap("attack")
	await _frames(20)
	var to := g.global_position - player.global_position
	var facing_err := rad_to_deg((-player.model.global_basis.z).angle_to(Vector3(to.x, 0, to.z)))
	print("ASSIST: lock %s, facing error %.0f deg, agent health %.0f -> %.0f, gap now %.2f m, camera yaw moved %.3f" % [
			combat.lock_target, facing_err, h0, g.health, Vector2(to.x, to.z).length(), absf(player.camera_pivot.global_rotation.y - cam_yaw)])
	ok = ok and combat.lock_target == null and g.health < h0 and facing_err < 15.0 and absf(player.camera_pivot.global_rotation.y - cam_yaw) < 0.001
	g.queue_free()
	await _frames(40)
	# Agent straight behind: no turn, no hit.
	player.model.rotation.y = 0.0
	var b := _agent(level, player.global_position + Vector3(0, 0, 2.0))
	await _frames(5)
	b.engage()
	var hb := b.health
	await _tap("attack")
	await _frames(20)
	var yaw := rad_to_deg(wrapf(player.model.rotation.y, -PI, PI))
	print("BEHIND: agent health %.0f -> %.0f, his yaw %.0f deg (want ~0)" % [hb, b.health, yaw])
	ok = ok and b.health == hb and absf(yaw) < 10.0
	# Dodge without lock-on: an agent fighting close by makes Space a roll, not a jump.
	await _frames(60)
	print("pre-dodge: move %s, dodge_ready %s, b %s dist %.1f, controls %s, stamina %.0f" % [combat.move, combat.dodge_ready(), Guard.State.keys()[b.state], b.global_position.distance_to(player.global_position), player.controls_enabled, combat.stamina])
	Input.action_press("move_left")
	await _frames(2)
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	await physics_frame
	var rolled := combat.move == PlayerCombat.Move.DODGE
	await physics_frame
	Input.action_release("jump")
	Input.action_release("move_left")
	await _frames(3)
	print("DODGE: no lock %s, rolled %s, airborne %s" % [combat.lock_target == null, rolled, not player.is_on_floor()])
	ok = ok and rolled and player.is_on_floor()
	b.queue_free()
	await _frames(30)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	print("NO FIGHT: Space jumps again: %s" % (not player.is_on_floor()))
	ok = ok and not player.is_on_floor()
	print("ASSIST %s" % ("PASS" if ok else "FAIL"))
	quit()


func _agent(level: Node, at: Vector3) -> Guard:
	var g: Guard = load("res://scenes/guard.tscn").instantiate()
	g.fights = true
	level.add_child(g)
	g.global_position = at
	g.data = g.data  # keep
	return g


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
