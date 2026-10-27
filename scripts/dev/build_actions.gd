extends RefCounted
## What Build Mode's keys and gamepad buttons do (build_mode.gd hands them over):
##   Del / Backspace / X: delete     Ctrl+D: copy         Ctrl+Z: undo     G: snap on / off
##   Q / E: turn left / right        arrows: nudge along the ground       PgUp / PgDn: up / down
##   Tab: the asset browser          F1 / F2: leave       Esc: drop the selection, then leave
## Gamepad: A selects at the crosshair, B deselects / leaves, Y deletes, X copies, LB / RB turn,
## the d-pad nudges, Back undoes (the sticks fly and look: build_fly.gd).

const FINE := 0.1        ## nudge step without snap, metres
const TURN_SNAP := 15.0  ## degrees per Q / E press with snap on (5 without)
const REPEATS := [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN, KEY_Q, KEY_E]

var mode: Node           ## build_mode.gd (untyped: the two scripts know each other)


func _init(build_mode: Node) -> void:
	mode = build_mode


func key(k: InputEventKey) -> void:
	var code := k.keycode
	var vp: Viewport = mode.get_viewport()
	if mode.ui.typing():
		if k.pressed and code in [KEY_ESCAPE, KEY_TAB, KEY_ENTER, KEY_KP_ENTER]:
			mode.ui.stop_typing()
			vp.set_input_as_handled()
		return  # the letters go to the search box
	vp.set_input_as_handled()  # nothing else in the game hears the keyboard
	if not k.pressed or (k.echo and not code in REPEATS):
		return
	var ctrl := k.ctrl_pressed or k.meta_pressed
	match code:
		KEY_F1, KEY_F2:
			mode.close()
		KEY_ESCAPE:
			if mode._drag:
				mode.end_drag(false)
			elif mode.selected:
				mode.select(null)
			else:
				mode.close()
		KEY_TAB:
			mode.ui.toggle_browser()
		KEY_DELETE, KEY_BACKSPACE, KEY_X:
			delete_selected()
		KEY_Z when ctrl:
			undo()
		KEY_D when ctrl:
			duplicate_selected()
		KEY_G:
			mode.snap = not mode.snap
			mode.ui.say("Snap " + ("on: 0.5 m, 15 degrees." if mode.snap else "off."))
		KEY_Q:
			turn_selected(1)
		KEY_E:
			turn_selected(-1)
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			nudge_selected(code)
		KEY_PAGEUP:
			nudge(Vector3.UP)
		KEY_PAGEDOWN:
			nudge(Vector3.DOWN)


func pad(b: InputEventJoypadButton) -> void:
	match b.button_index:
		JOY_BUTTON_A:
			mode.click(mode.center())
			mode.end_drag(false)
		JOY_BUTTON_B:
			if mode.selected:
				mode.select(null)
			else:
				mode.close()
		JOY_BUTTON_Y:
			delete_selected()
		JOY_BUTTON_X:
			duplicate_selected()
		JOY_BUTTON_LEFT_SHOULDER:
			turn_selected(1)
		JOY_BUTTON_RIGHT_SHOULDER:
			turn_selected(-1)
		JOY_BUTTON_DPAD_LEFT:
			nudge_selected(KEY_LEFT)
		JOY_BUTTON_DPAD_RIGHT:
			nudge_selected(KEY_RIGHT)
		JOY_BUTTON_DPAD_UP:
			nudge_selected(KEY_UP)
		JOY_BUTTON_DPAD_DOWN:
			nudge_selected(KEY_DOWN)
		JOY_BUTTON_BACK:
			undo()


func delete_selected() -> void:
	if mode.selected == null:
		return
	if mode.session.delete(mode.selected):
		mode.select(null)
	mode.ui.say(mode.session.message)


## A copy beside the selection (to the camera's right), selected so it can be moved at once.
func duplicate_selected() -> void:
	if mode.selected == null:
		return
	var right: Vector3 = mode.camera.global_basis.x
	right = Vector3(right.x, 0, right.z).normalized()
	var copy: Node3D = mode.session.duplicate(mode.selected, right * (mode.GRID * 2.0 if mode.snap else 1.0))
	if copy:
		mode.select(copy)
	mode.ui.say(mode.session.message)


func undo() -> void:
	mode.end_drag(false)
	mode.session.undo()
	mode.ui.say(mode.session.message)
	if mode.selected and not mode.selected.is_inside_tree():
		mode.select(null)


## Turns the selection around the vertical (+1 = left / Q).
func turn_selected(step: int) -> void:
	var node: Node3D = mode.selected
	if node == null:
		return
	var before := node.transform
	var g := node.global_transform
	node.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad((TURN_SNAP if mode.snap else 5.0) * step)) * g.basis, g.origin)
	var turned := node.transform
	node.transform = before
	mode.session.move(node, turned, null, true)
	mode.ui.say(mode.session.message)


## Arrow keys: along the ground, the way the camera looks (snapped to the nearest axis).
func nudge_selected(code: Key) -> void:
	var fwd: Vector3 = -mode.camera.global_basis.z
	fwd = Vector3(signf(fwd.x), 0, 0) if absf(fwd.x) > absf(fwd.z) else Vector3(0, 0, signf(fwd.z))
	var right := fwd.cross(Vector3.UP)
	nudge({KEY_UP: fwd, KEY_DOWN: -fwd, KEY_RIGHT: right, KEY_LEFT: -right}[code])


## Moves the selection one step (0.5 m with snap, 0.1 m without) along `dir`.
func nudge(dir: Vector3) -> void:
	var node: Node3D = mode.selected
	if node == null:
		return
	var before := node.transform
	node.global_position += dir * (mode.GRID if mode.snap else FINE)
	var moved := node.transform
	node.transform = before
	mode.session.move(node, moved, null, true)
	mode.ui.say(mode.session.message)


## Places a catalog thing where the crosshair points, turned to face the camera, and selects it.
func place(entry: Dictionary) -> Node3D:
	var cam: Camera3D = mode.camera
	var hit: Dictionary = mode.pick_at(mode.center(), false).hit
	var at: Vector3 = hit.position if not hit.is_empty() else cam.global_position - cam.global_basis.z * 8.0
	if mode.snap:
		at = Vector3(snappedf(at.x, mode.GRID), at.y, snappedf(at.z, mode.GRID))
	var look := -cam.global_basis.z
	look = Vector3(look.x, 0, look.z)
	var basis := Basis.looking_at(look.normalized() if look.length() > 0.01 else Vector3.FORWARD, Vector3.UP)
	var node: Node3D = mode.session.add(entry, Transform3D(basis, at), hit.get("node"))
	if node:
		mode.select(node)
	mode.ui.say(mode.session.message)
	return node
