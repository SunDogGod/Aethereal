extends CanvasLayer
## The dev menu (DevTools/Menu), for testing: F1, or hold the gamepad's Back / View button for
## a second. It pauses the game while it's open (like the pause menu) and only opens in a level.
## Pages: the main list, Teleport (every checkpoint, story trigger, camera shot and marker in
## the level) and Chapters. The work is done by DevTools/Cheats and DevTools/Places; this
## script only draws the lines and calls them.

const Rows := preload("res://scripts/dev/dev_rows.gd")
const WIDTH := 300.0   ## the menu lines' width
const HOLD := 1.0      ## seconds the gamepad's Back button is held to open or close it

var cheats: Node
var places: Node
var overlay: CanvasLayer
var is_open := false

@onready var root_control: Control = $Root
@onready var title: Label = $Root/Panel/Box/Title
@onready var where: Label = $Root/Panel/Box/Where
@onready var main_page: VBoxContainer = $Root/Panel/Box/Main
@onready var teleport_page: VBoxContainer = $Root/Panel/Box/Teleport
@onready var teleport_list: VBoxContainer = $Root/Panel/Box/Teleport/Scroll/List
@onready var chapters_page: VBoxContainer = $Root/Panel/Box/Chapters
@onready var hints: Label = $Root/Hints

var items := {}  ## the lines by name ("god", "skip", "teleport"...): a MenuItem or an ON/OFF box
var _page: Control
var _return_to: Control
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _back_down_at := -1  # when the gamepad's Back button went down (msec); -1 = it's up
var _back_used := false


func _ready() -> void:
	root_control.visible = false
	_build_main()
	_build_chapters()
	teleport_page.add_child(Rows.rule())
	teleport_page.add_child(Rows.action("Back", WIDTH, _show_page.bind(main_page)))
	cheats.connect("changed", func() -> void:
		if is_open:
			_refresh())


func _build_main() -> void:
	_add_item("teleport", Rows.action("Teleport...", WIDTH, _open_teleport))
	_add_item("chapters", Rows.action("Chapters...", WIDTH, _open_chapters))
	main_page.add_child(Rows.rule())
	items["god"] = Rows.switch(main_page, "God mode", Callable(cheats, "set_god"))
	items["noclip"] = Rows.switch(main_page, "Noclip fly", Callable(cheats, "set_noclip"))
	items["blind"] = Rows.switch(main_page, "Blind guards", Callable(cheats, "set_blind"))
	items["overlay"] = Rows.switch(main_page, "Overlay", _set_overlay)
	items["time"] = Rows.choice(main_page, "Time scale", Callable(cheats, "cycle_time_scale"))
	main_page.add_child(Rows.rule())
	_add_item("skip", Rows.action("Skip story scene", WIDTH, _skip))
	_add_item("restart", Rows.action("Restart at checkpoint", WIDTH, _after_close.bind(Callable(places, "restart_at_checkpoint"))))
	_add_item("reload_cp", Rows.action("Reload at checkpoint", WIDTH, _after_close.bind(Callable(places, "reload_level").bind(true))))
	_add_item("reload", Rows.action("Reload from start", WIDTH, _after_close.bind(Callable(places, "reload_level").bind(false))))
	main_page.add_child(Rows.rule())
	_add_item("close", Rows.action("Close", WIDTH, close, "F1"))


func _add_item(key: String, item: MenuItem) -> void:
	items[key] = item
	main_page.add_child(item)


func _build_chapters() -> void:
	for entry: Array in Chapters.LIST:
		chapters_page.add_child(Rows.action(entry[1], WIDTH, _after_close.bind(
				Callable(places, "go_to_chapter").bind(entry[2])), entry[0]))
	chapters_page.add_child(Rows.rule())
	chapters_page.add_child(Rows.action("Back", WIDTH, _show_page.bind(main_page)))


# --- Opening and closing ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# F1 works from anywhere, even while a menu line has the keyboard.
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_F1 or event.physical_keycode == KEY_F1):
		toggle()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK:
		if not event.pressed:
			_back_down_at = -1
		elif _back_down_at < 0:
			_back_down_at = Time.get_ticks_msec()
			_back_used = false


func _process(_delta: float) -> void:
	# Holding Back for a second toggles the menu (once per hold; real time, not game time).
	if _back_down_at >= 0 and not _back_used and Time.get_ticks_msec() - _back_down_at >= HOLD * 1000.0:
		_back_used = true
		toggle()


func toggle() -> void:
	if is_open:
		close()
	elif can_open():
		open()


## True in a level with Aeneas in it, with no title screen up and the game not paused.
func can_open() -> bool:
	var tree := get_tree()
	return not tree.paused and tree.current_scene != null and cheats.player() != null \
			and tree.get_first_node_in_group("title_screen") == null


func open() -> void:
	is_open = true
	get_tree().paused = true
	cheats.hold_time(true)
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var label := Chapters.label_of(get_tree().current_scene.scene_file_path)
	where.text = (label if label != "" else str(get_tree().current_scene.name)) + "      debug builds only"
	root_control.visible = true
	root_control.modulate.a = 0.0
	create_tween().tween_property(root_control, "modulate:a", 1.0, 0.12)
	MenuFx.blip(self, true)
	_return_to = null
	_show_page(main_page)


## Back to the game: unpause, give the game its time scale and the mouse back.
func close() -> void:
	if not is_open:
		return
	is_open = false
	root_control.visible = false
	get_viewport().gui_release_focus()
	get_tree().paused = false
	cheats.hold_time(false)
	Input.mouse_mode = _mouse_before


## Skips the scene that is playing (the menu stays open when there is none).
func _skip() -> void:
	if cheats.story_playing():
		_after_close(Callable(cheats, "skip_scene"))


## Closes the menu, then does something in the running game (a teleport, a reload...).
func _after_close(action: Callable) -> void:
	close()
	action.call()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):  # Esc or B: one step back
		_back()
	elif event.is_action_pressed("pause"):    # Start: straight back to the game
		close()
	elif _step_with_keys(event) or MenuFx.extra_nav(event, get_viewport()):
		pass
	elif get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_down") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept")):
		_focus_first()  # the mouse clicked the focus away
	else:
		return
	get_viewport().set_input_as_handled()


## A / D on the time scale steps it (the arrows already do, through the box itself).
func _step_with_keys(event: InputEvent) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if not (event is InputEventKey and event.is_pressed()) or focused == null or not focused.has_meta(Rows.STEP):
		return false
	var step := -1 if event.is_action("move_left") else (1 if event.is_action("move_right") else 0)
	if step != 0:
		(focused.get_meta(Rows.STEP) as Callable).call(step)
	return step != 0


func _back() -> void:
	if _page != main_page:
		_show_page(main_page)
	else:
		close()


# --- Pages --------------------------------------------------------------------------------

func _show_page(page: Control) -> void:
	for p: Control in [main_page, teleport_page, chapters_page]:
		p.visible = p == page
	_page = page
	title.text = {main_page: "DEV MENU", teleport_page: "TELEPORT", chapters_page: "CHAPTERS"}[page]
	hints.text = "Enter / A   select        Left / Right   change        Esc / B   back        F1   close" \
			if page == main_page else "Enter / A   go        Esc / B   back        F1   close"
	_refresh()
	if page == main_page and is_instance_valid(_return_to):
		MenuFx.focus_quietly(_return_to)
	else:
		_focus_first()


func _focus_first() -> void:
	for child in _page.find_children("*", "BaseButton", true, false):
		if child.is_visible_in_tree():
			MenuFx.focus_quietly(child)
			return


func _open_teleport() -> void:
	_return_to = items["teleport"]
	for child in teleport_list.get_children():
		teleport_list.remove_child(child)
		child.queue_free()
	var group := ""
	for target: Array in places.targets():
		if target[0] != group:
			group = target[0]
			teleport_list.add_child(Rows.section(group))
		var node: Node3D = target[2]
		var at := node.global_position
		teleport_list.add_child(Rows.action(target[1], WIDTH - 12.0, _after_close.bind(
				Callable(places, "teleport_to").bind(node)), "%.0f  %.0f  %.0f" % [at.x, at.y, at.z]))
	if group == "":
		teleport_list.add_child(Rows.section("NOTHING TO TELEPORT TO IN THIS LEVEL"))
	_show_page(teleport_page)
	(teleport_page.get_node("Scroll") as ScrollContainer).scroll_vertical = 0


func _open_chapters() -> void:
	_return_to = items["chapters"]
	_show_page(chapters_page)


func _set_overlay(on: bool) -> void:
	overlay.visible = on
	if on:
		overlay.refresh()


## Brings every switch and the small right-hand texts up to date.
func _refresh() -> void:
	for key: String in ["god", "blind"]:
		_set_switch(key, bool(cheats.get(key)))
	_set_switch("noclip", cheats.noclip.on)
	_set_switch("overlay", overlay.visible)
	(items["time"] as Button).text = "%sx" % str(cheats.time_scale).trim_suffix(".0")
	Rows.set_detail(items["teleport"], "%d places" % places.targets().size())
	var here := Chapters.find(get_tree().current_scene.scene_file_path) if get_tree().current_scene else []
	Rows.set_detail(items["chapters"], ("now " + str(here[0])) if not here.is_empty() and here[0] != "" else "")
	Rows.set_detail(items["skip"], "scene playing" if cheats.story_playing() else "no scene")
	Rows.set_detail(items["restart"], places.checkpoint_name)
	Rows.set_detail(items["reload_cp"], places.checkpoint_name)


func _set_switch(key: String, on: bool) -> void:
	var box: Button = items[key]
	box.set_pressed_no_signal(on)
	box.text = "ON" if on else "OFF"
