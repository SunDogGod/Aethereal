class_name CombatInput
extends RefCounted
## The combat buttons, registered in code (like sprint) so the Input Map needn't be edited and
## the editor being open can't overwrite them. PlayerCombat calls ensure_actions() when it starts.


static func ensure_actions() -> void:
	_action("heavy_attack", [_key(KEY_G)], [_button(JOY_BUTTON_Y)])
	_action("block", [_mouse(MOUSE_BUTTON_RIGHT)], [_button(JOY_BUTTON_LEFT_SHOULDER)])
	_action("lock_on", [_key(KEY_Q)], [_button(JOY_BUTTON_RIGHT_STICK)])


## The enemy a lock-on press picks: near him and near the middle of the camera's view.
static func pick_lock_target(player: Player, lock_range: float) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var camera: Node3D = player.camera_pivot.get_node("SpringArm3D/Camera3D")
	var forward: Vector3 = -camera.global_basis.z
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		if not enemy.can_be_locked():
			continue
		var to: Vector3 = enemy.global_position - player.global_position
		if to.length() > lock_range:
			continue
		var score: float = to.length() + rad_to_deg(forward.angle_to(to)) * 0.1
		if score < best_score:
			best = enemy
			best_score = score
	return best


static func _action(name: String, keys: Array, buttons: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name)
	for e in keys + buttons:
		InputMap.action_add_event(name, e)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(index: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = index
	return e


static func _button(index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e
