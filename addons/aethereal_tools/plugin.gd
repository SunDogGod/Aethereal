@tool
extends EditorPlugin
## The Aethereal editor tools: the "Aethereal" dock (one-click guards, triggers, checkpoints,
## shots, life signs, blocks, props, a navigation bake and the guide) and the patrol-route
## lines drawn over guards. Switch it off in Project > Project Settings > Plugins.

const Dock := preload("res://addons/aethereal_tools/dock.gd")
const Spot := preload("res://addons/aethereal_tools/spot.gd")
const Placer := preload("res://addons/aethereal_tools/placer.gd")
const Query := preload("res://addons/aethereal_tools/scene_query.gd")
const NavBaker := preload("res://addons/aethereal_tools/nav_baker.gd")
const NewLevel := preload("res://addons/aethereal_tools/new_level.gd")
const GuideWindow := preload("res://addons/aethereal_tools/guide_window.gd")
const RouteGizmo := preload("res://addons/aethereal_tools/route_gizmo.gd")

var _dock_frame: EditorDock
var _dock: Dock
var _gizmo: EditorNode3DGizmoPlugin
var _guide: AcceptDialog
var _name_dialog: ConfirmationDialog
var _name_edit: LineEdit
var _timer: Timer
var _route_seen := {}      # guard instance id -> last drawn route, to redraw only on change
var _placers: Array = []   # keeps each action's placer alive for undo/redo
var _test_runner: Object   # automated checks only (see the end of _enter_tree)


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.setup(EditorInterface.get_editor_theme())
	_dock.add_requested.connect(_on_add)
	_dock.bake_requested.connect(_on_bake)
	_dock.guide_requested.connect(_on_guide)
	_dock.new_level_requested.connect(_on_new_level)
	var scroll := ScrollContainer.new()
	scroll.name = "Aethereal"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(200, 300) * EditorInterface.get_editor_scale()
	_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_dock)
	_dock_frame = EditorDock.new()
	_dock_frame.title = "Aethereal"
	_dock_frame.layout_key = "aethereal_tools"
	_dock_frame.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL  # beside the Inspector
	_dock_frame.add_child(scroll)
	add_dock(_dock_frame)
	_gizmo = RouteGizmo.new()
	add_node_3d_gizmo_plugin(_gizmo)
	scene_changed.connect(_dock.show_level)
	_dock.show_level(EditorInterface.get_edited_scene_root())
	_timer = Timer.new()
	_timer.wait_time = 0.3
	_timer.timeout.connect(_refresh_routes)
	add_child(_timer)
	_timer.start()
	# For automated checks only: a script path in this variable gets this plugin to drive.
	var test := OS.get_environment("AETHEREAL_TOOLS_TEST")
	if test != "":
		_test_runner = load(test).new()
		_test_runner.call_deferred("run", self)


func _exit_tree() -> void:
	if _dock_frame:
		remove_dock(_dock_frame)
		_dock_frame.queue_free()
	if _gizmo:
		remove_node_3d_gizmo_plugin(_gizmo)
	for w in [_guide, _name_dialog]:
		if is_instance_valid(w):
			w.queue_free()


## A dock button: works out the spot, plans the thing, adds it with undo, selects it.
func _on_add(kind: String, label: String) -> void:
	var root := EditorInterface.get_edited_scene_root() as Node3D
	if root == null:
		_dock.say("Open a 3D scene (a level) first.")
		return
	var finder := Spot.new(root)
	var selection := EditorInterface.get_selection().get_selected_nodes()
	var selected: Node = selection[0] if not selection.is_empty() else null
	var cam_xf: Variant = _editor_camera()
	var where: Dictionary
	if _dock.place_mode.selected == 1 and selected is Node3D and selected != root:
		where = finder.from_node(selected)
	elif cam_xf is Transform3D:
		where = finder.from_view(cam_xf)
	else:
		where = finder.from_node(root)
	var placer := Placer.new(root, where, finder, selected)
	placer.cam = cam_xf
	var plan := placer.plan(kind)
	if plan.steps.is_empty():
		_dock.say(plan.message)
		return
	add(placer, plan, label)
	var note: String = plan.message if plan.message != "" else "%s added. Move it with W, turn it with E." % plan.select.name
	_dock.say(note)


## Carries out a plan as one undoable step and selects the new thing.
func add(placer: Placer, plan: Dictionary, label: String) -> void:
	var ur := get_undo_redo()
	ur.create_action("Aethereal: add " + label, UndoRedo.MERGE_DISABLE, plan.owner)
	ur.add_do_method(placer, "apply", plan)
	ur.add_undo_method(placer, "revert", plan)
	for step: Dictionary in plan.steps:
		ur.add_do_reference(step.node)
	ur.commit_action()
	_placers.append(placer)
	if _placers.size() > 200:
		_placers.pop_front()
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(plan.select)
	EditorInterface.edit_node(plan.select)


func _on_bake() -> void:
	var root := EditorInterface.get_edited_scene_root()
	var region := NavBaker.find_region(root) if root else null
	if region == null:
		_dock.say("This level has no Navigation node (a NavigationRegion3D), so there is nothing to bake. The guide shows how to add one.")
		return
	var result := NavBaker.bake(region)
	var ur := get_undo_redo()
	ur.create_action("Aethereal: bake navigation", UndoRedo.MERGE_DISABLE, root)
	ur.add_do_method(NavBaker, "restore", region, result.after)
	ur.add_undo_method(NavBaker, "restore", region, result.before)
	ur.commit_action(false)  # already baked
	_dock.say(result.message)


func _on_guide() -> void:
	if not is_instance_valid(_guide):
		_guide = GuideWindow.new()
		EditorInterface.get_base_control().add_child(_guide)
	_guide.show_guide(EditorInterface.get_editor_scale())


func _on_new_level() -> void:
	if not is_instance_valid(_name_dialog):
		_name_dialog = ConfirmationDialog.new()
		_name_dialog.title = "New level"
		var box := VBoxContainer.new()
		var hint := Label.new()
		hint.text = "The level's name (for example: The Old Mill)"
		box.add_child(hint)
		_name_edit = LineEdit.new()
		_name_edit.custom_minimum_size.x = 320 * EditorInterface.get_editor_scale()
		box.add_child(_name_edit)
		_name_dialog.add_child(box)
		_name_dialog.register_text_enter(_name_edit)
		_name_dialog.confirmed.connect(func() -> void: make_level(_name_edit.text))
		EditorInterface.get_base_control().add_child(_name_dialog)
	_name_edit.text = ""
	_name_dialog.popup_centered()
	_name_edit.grab_focus()


func make_level(display_name: String) -> void:
	var result := NewLevel.create(display_name)
	_dock.say(result.message)
	if result.ok:
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.open_scene_from_path(result.path)


## The 3D view's camera, or null when there is none.
func _editor_camera() -> Variant:
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	var cam := viewport.get_camera_3d() if viewport else null
	return cam.global_transform if cam else null


## Redraws the patrol line of a selected guard (or of the guard whose point you're moving).
func _refresh_routes() -> void:
	for node in EditorInterface.get_selection().get_selected_nodes():
		var n: Node = node
		while n != null and not Query.is_guard(n):
			n = n.get_parent()
		if n == null:
			continue
		var points := RouteGizmo.route_points(n)
		var key := n.get_instance_id()
		if _route_seen.get(key) != points:
			_route_seen[key] = points
			(n as Node3D).update_gizmos()
