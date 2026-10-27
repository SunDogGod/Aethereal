extends Node
## Build Mode (DevTools/Build), debug builds only: change a level from inside the running game.
## Open it from the dev menu (F1 > Build mode) or with F2. The game pauses and a free camera
## takes over (build_fly.gd).
##   Click a thing to select it (an amber box; red = the story needs it). Drag it to move it
##   along the ground; arrows nudge, PgUp / PgDn raise and lower, Q / E turn, G snaps to a
##   0.5 m grid and 15 degree turns. Delete removes it, Ctrl+D copies it, Ctrl+Z undoes.
##   Tab opens the asset browser: click a tile to place that thing where the crosshair points.
##   F1, F2 or Esc (with nothing selected) goes back to the game.
## Every change is saved at once to data/edits/<level>.json (build_session.gd) and comes back
## each time the level loads; bake it into the scene with the editor dock's button.
## What each key and button does is in build_actions.gd; this file opens and closes the mode,
## and handles selecting and dragging with the mouse.

const Session := preload("res://scripts/dev/build_session.gd")
const Pick := preload("res://scripts/dev/build_pick.gd")
const Catalog := preload("res://scripts/dev/build_catalog.gd")
const Rules := preload("res://scripts/dev/edit_rules.gd")
const Fly := preload("res://scripts/dev/build_fly.gd")
const Gizmo := preload("res://scripts/dev/build_gizmo.gd")
const UI := preload("res://scripts/dev/build_ui.gd")
const Thumbs := preload("res://scripts/dev/build_thumbs.gd")
const Actions := preload("res://scripts/dev/build_actions.gd")
const LevelEdits := preload("res://scripts/dev/level_edits.gd")

const GRID := 0.5        ## snap grid, metres

var cheats: Node         ## DevTools/Cheats (time scale)
var applier: Node        ## DevTools/Edits (rescanned after each save)
var is_open := false
var snap := true
var selected: Node3D
var session: Session
var camera: Camera3D     ## the free camera (build_fly.gd)
var ui: CanvasLayer      ## the screen (build_ui.gd)
var actions := Actions.new(self)

var _game_cam: Camera3D
var _lines: Control
var _thumbs: Node
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _scene: Node         # the scene the session belongs to
var _drag := false
var _drag_from: Transform3D
var _drag_offset := Vector3.ZERO
var _drag_height := 0.0
var _mark_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## True in a running level that isn't paused or loading, with no title screen up.
func can_open() -> bool:
	var tree := get_tree()
	return not is_open and not tree.paused and tree.current_scene is Node3D and not SceneLoader.busy \
			and tree.get_first_node_in_group("title_screen") == null


func open() -> void:
	if not can_open():
		return
	var tree := get_tree()
	if _scene != tree.current_scene:
		_new_session(tree.current_scene)
	is_open = true
	tree.paused = true
	if cheats:
		cheats.hold_time(true)
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_game_cam = get_viewport().get_camera_3d()
	if camera == null:
		_build_once()
	camera.start_from(_game_cam)
	camera.make_current()
	ui.visible = true
	select(selected if is_instance_valid(selected) and selected.is_inside_tree() else null)
	ui.say("")
	_mark_timer = 0.0


func close() -> void:
	if not is_open:
		return
	end_drag(false)
	is_open = false
	(camera as Fly).stop_looking()
	ui.stop_typing()
	ui.visible = false
	if is_instance_valid(_game_cam):
		_game_cam.make_current()
	camera.current = false
	get_tree().paused = false
	if cheats:
		cheats.hold_time(false)
	Input.mouse_mode = _mouse_before


func _build_once() -> void:
	camera = Fly.new()
	camera.name = "Camera"
	add_child(camera)
	ui = UI.new()
	ui.name = "Screen"
	add_child(ui)
	_lines = Gizmo.new()
	_lines.name = "Lines"
	_lines.camera = camera
	ui.add_overlay(_lines)
	ui.asset_chosen.connect(actions.place)
	ui.browser.visibility_changed.connect(_fill_browser)
	_thumbs = Thumbs.new()
	_thumbs.name = "Thumbs"
	add_child(_thumbs)


## The asset list is read when the browser first opens (Tab), and its pictures taken then.
func _fill_browser() -> void:
	if not ui.browser.visible or not (ui.tiles as Dictionary).is_empty():
		return
	var entries := Catalog.list()
	ui.fill(entries)
	_thumbs.fill(entries, ui)


func _new_session(scene: Node) -> void:
	if session:
		session.clear()
	_scene = scene
	selected = null
	session = Session.new(scene)
	session.saved.connect(func(_path: String) -> void:
		if applier:
			applier.rescan())


# --- Every frame --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_open:
		return
	(camera as Fly).enabled = not ui.typing()
	if selected and not is_instance_valid(selected):
		select(null)
	_lines.show_selection(selected, selected != null and Rules.protected_reason(selected) != "")
	_mark_timer -= delta / maxf(Engine.time_scale, 0.01)
	if _mark_timer <= 0.0:
		_mark_timer = 0.3
		_lines.show_markers(_scene, camera.global_position)
	var file := ""
	if selected:
		var root := session.edit_root_of(selected)
		file = root.scene_file_path.get_file() if root else ""
	ui.set_status(snap, session.undo_count(), file)


# --- Input --------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2 and can_open():
			open()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		actions.key(event as InputEventKey)
	elif event is InputEventJoypadButton and event.pressed:
		actions.pad(event as InputEventJoypadButton)
		get_viewport().set_input_as_handled()
	elif (camera as Fly).looking and (event is InputEventMouseMotion or event is InputEventMouseButton):
		(camera as Fly).handle(event)  # looking around: the mouse belongs to the camera
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if (camera as Fly).handle(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			click((event as InputEventMouseButton).position)
		else:
			end_drag(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag:
		_drag_to((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


# --- Selecting and dragging ---------------------------------------------------------------

## What is under a screen point: {node (the editable thing or null), hit (the raw pick)}.
func pick_at(screen: Vector2, with_proxies := true) -> Dictionary:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var skip := get_tree().get_nodes_in_group("player")
	var hit := Pick.cast(_scene, from, dir, skip, with_proxies)
	return {"node": session.target_of(hit.get("node")), "hit": hit}


## A click (or the gamepad's A at the crosshair): select, or start dragging the selection.
func click(screen: Vector2) -> void:
	if ui.mouse_over_panel():
		return
	ui.stop_typing()
	var found := pick_at(screen)
	var target: Node3D = found.node
	if target == null:
		select(null)
		return
	if target != selected:
		select(target)
		return
	if Rules.locked_reason(target) != "":
		ui.say("Can't move %s: %s." % [target.name, Rules.locked_reason(target)])
		return
	# A press on the selection starts a drag along the flat plane at its height.
	_drag = true
	_drag_from = target.transform
	_drag_height = target.global_position.y
	var on_plane: Variant = _plane_point(screen)
	_drag_offset = target.global_position - on_plane if on_plane is Vector3 else Vector3.ZERO


func _drag_to(screen: Vector2) -> void:
	if not is_instance_valid(selected):
		_drag = false
		return
	var on_plane: Variant = _plane_point(screen)
	if not on_plane is Vector3:
		return
	var at: Vector3 = on_plane + _drag_offset
	if snap:
		at = Vector3(snappedf(at.x, GRID), at.y, snappedf(at.z, GRID))
	selected.global_position = Vector3(at.x, _drag_height, at.z)


## Ends a drag: `keep` records the move, otherwise the thing goes back where it was.
func end_drag(keep: bool) -> void:
	if not _drag:
		return
	_drag = false
	if not is_instance_valid(selected):
		return
	if not keep:
		selected.transform = _drag_from
	elif not selected.transform.is_equal_approx(_drag_from):
		session.move(selected, selected.transform, _drag_from)
		ui.say(session.message)


func _plane_point(screen: Vector2) -> Variant:
	var plane := Plane(Vector3.UP, _drag_height)
	return plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))


func select(node: Node3D) -> void:
	selected = node
	if ui == null:
		return
	if node == null:
		ui.show_selection("Nothing selected", "Click a thing, or Tab for the assets.")
		return
	var root := session.edit_root_of(node)
	var path := str(root.get_path_to(node)) if root else str(node.name)
	var why := Rules.protected_reason(node)
	var kind := node.get_class()
	if node.scene_file_path != "":
		kind = node.scene_file_path.get_file()
	elif node.get_script():
		kind = (node.get_script() as Script).resource_path.get_file()
	var detail := "%s   %s" % [kind, "added in game" if node.has_meta(LevelEdits.ADDED_META) else ""]
	if why != "":
		detail = "protected: %s" % why
	ui.show_selection(path, detail, why != "")


func center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5
