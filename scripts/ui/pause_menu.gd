extends CanvasLayer
## The pause menu (autoload "PauseMenu"). In a level, Esc or Start (the gamepad's menu
## button) pauses the game: Resume, Skills (once the story opens the skill tree), Settings,
## Return to Title, Quit Game.
## It keeps running while the game is paused (process mode Always), so a story scene, a
## fade or a fight just freezes behind it and carries on when you resume.
## It only opens in a level with a Player, never over the title screen.
## It also applies your saved settings when the game starts.

const TITLE := "res://scenes/ui/title_screen.tscn"
const ITEM_WIDTH := 220.0

@onready var root_control: Control = $Root
@onready var main_box: Control = $Root/Main
@onready var where: Label = $Root/Main/Where
@onready var items: VBoxContainer = $Root/Main/Items
@onready var settings: PanelContainer = $Root/Settings
@onready var confirm: PanelContainer = $Root/Confirm
@onready var question: Label = $Root/Confirm/Box/Question
@onready var note: Label = $Root/Confirm/Box/Note
@onready var answers: HBoxContainer = $Root/Confirm/Box/Answers
@onready var hints: Label = $Root/Hints
@onready var black: ColorRect = $Black

var is_open := false
var mouse_wanted := Input.MOUSE_MODE_VISIBLE  ## the mouse mode we last asked for (headless tests can't read the real one)

var _busy := false             # on the way back to the title
var _return_to: Control        # the line that opened a page or a question
var _on_yes := Callable()      # what "Yes" does in the question box
var _no: MenuItem
var _skills_item: MenuItem
var _skills_page := SkillsPanel.new()  # built in code, placed like the Settings page


func _ready() -> void:
	_ensure_pause_action()
	GameSettings.apply()
	MenuFx.paused_player = $Blip
	root_control.visible = false
	items.add_child(MenuItem.make("Resume", ITEM_WIDTH, resume))
	_skills_item = MenuItem.make("Skills", ITEM_WIDTH, _open_skills)
	items.add_child(_skills_item)
	items.add_child(MenuItem.make("Settings", ITEM_WIDTH, _open_settings))
	items.add_child(MenuItem.make("Return to Title", ITEM_WIDTH, _ask.bind(
			"Return to the title screen?", "", _return_to_title)))
	items.add_child(MenuItem.make("Quit Game", ITEM_WIDTH, _ask.bind(
			"Quit the game?", "", func() -> void: get_tree().quit())))
	_no = MenuItem.make("No", 96.0, _show_main)
	answers.add_child(_no)
	answers.add_child(MenuItem.make("Yes", 96.0, func() -> void: _on_yes.call()))
	settings.closed.connect(_show_main)
	_skills_page.visible = false
	root_control.add_child(_skills_page)
	root_control.move_child(_skills_page, settings.get_index() + 1)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_skills_page.set_anchor(side, settings.get_anchor(side))
		_skills_page.set_offset(side, settings.get_offset(side))
	_skills_page.grow_vertical = settings.grow_vertical
	_skills_page.closed.connect(_show_main)


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if not is_open:
		if event.is_action_pressed("pause") and can_open():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):  # Esc or B: one step back
		_back()
	elif event.is_action_pressed("pause"):    # Start: straight back to the game
		resume()
	elif MenuFx.extra_nav(event, get_viewport()):
		pass
	elif get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_down") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept")):
		_refocus()  # the mouse clicked the focus away
	else:
		return
	get_viewport().set_input_as_handled()


## True in a level with a Player, with no title screen up, the game not already paused and no
## level loading behind the black screen.
func can_open() -> bool:
	var tree := get_tree()
	return not tree.paused and tree.current_scene != null and not SceneLoader.busy \
			and tree.get_first_node_in_group("player") != null \
			and tree.get_first_node_in_group("title_screen") == null


func open() -> void:
	is_open = true
	get_tree().paused = true
	_set_mouse(Input.MOUSE_MODE_VISIBLE)
	where.text = Chapters.label_of(get_tree().current_scene.scene_file_path)
	where.visible = where.text != ""
	var player := get_tree().get_first_node_in_group("player") as Player
	_skills_item.visible = player != null and player.skills != null and player.skills.tree_open
	root_control.visible = true
	root_control.modulate.a = 0.0
	create_tween().tween_property(root_control, "modulate:a", 1.0, 0.12)
	MenuFx.blip(self, true)
	_return_to = null
	_show_main()


## Back to the game: unpause and grab the mouse again for the camera.
func resume() -> void:
	if not is_open:
		return
	is_open = false
	root_control.visible = false
	settings.visible = false
	_skills_page.visible = false
	confirm.visible = false
	get_viewport().gui_release_focus()
	get_tree().paused = false
	_set_mouse(Input.MOUSE_MODE_CAPTURED)


func _back() -> void:
	if confirm.visible:
		_show_main()
	elif settings.visible:
		settings.close()  # its closed signal brings the main list back
	elif _skills_page.visible:
		_skills_page.close()
	else:
		resume()


func _show_main() -> void:
	confirm.visible = false
	settings.visible = false
	_skills_page.visible = false
	main_box.visible = true
	MenuFx.focus_quietly(_return_to if is_instance_valid(_return_to) else items.get_child(0))
	hints.text = "Enter / A   select        Esc / Start   resume"


func _open_settings() -> void:
	_return_to = get_viewport().gui_get_focus_owner()
	main_box.visible = false
	settings.open()
	hints.text = "Left / Right   change        Esc / B   back"


func _open_skills() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	_return_to = get_viewport().gui_get_focus_owner()
	main_box.visible = false
	_skills_page.open(player.skills)
	hints.text = "Enter / A   buy        Esc / B   back"


## A yes/no question; "No" has the focus, so a stray press never quits. With no small print it
## says where Continue will pick up (the game saves by itself: scripts/autosave.gd).
func _ask(text: String, small_print: String, on_yes: Callable) -> void:
	_return_to = get_viewport().gui_get_focus_owner()
	_on_yes = on_yes
	question.text = text
	if small_print == "":
		small_print = "Continue returns to your last save." if SaveGame.recording \
				else "This level is running on its own: nothing is saved."
	note.text = small_print
	note.visible = small_print != ""
	main_box.visible = false
	confirm.visible = true
	confirm.modulate.a = 0.0
	create_tween().tween_property(confirm, "modulate:a", 1.0, 0.12)
	MenuFx.focus_quietly(_no)
	hints.text = "Enter / A   select        Esc / B   back"


func _refocus() -> void:
	if confirm.visible:
		MenuFx.focus_quietly(_no)
	elif settings.visible:
		settings.focus_first()
	elif _skills_page.visible:
		_skills_page.focus_first()
	else:
		MenuFx.focus_quietly(items.get_child(0))


## Fade to black, end any story scene, unpause, and load the title screen.
func _return_to_title() -> void:
	_busy = true
	get_viewport().gui_release_focus()
	var out := create_tween()  # this node runs while paused, so its tweens do too
	out.tween_property(black, "color:a", 1.0, 0.4)
	await out.finished
	root_control.visible = false
	confirm.visible = false
	is_open = false
	var story := get_node_or_null("/root/Story")
	if story and story.has_method("stop"):
		story.stop()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE)
	await get_tree().process_frame
	await get_tree().process_frame
	black.color.a = 0.0  # the title screen fades itself in from black
	_set_mouse(Input.MOUSE_MODE_VISIBLE)
	_busy = false


func _set_mouse(mode: Input.MouseMode) -> void:
	mouse_wanted = mode
	Input.mouse_mode = mode


## "pause" lives in the Input Map (project.godot); this puts it back if it ever goes missing.
func _ensure_pause_action() -> void:
	if InputMap.has_action("pause"):
		return
	InputMap.add_action("pause")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("pause", key)
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	InputMap.action_add_event("pause", start)
