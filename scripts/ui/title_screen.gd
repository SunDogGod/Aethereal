extends Control
## The title screen, the game's main scene: Continue, New Game, Chapters, Settings, Quit.
## The background is a still of the Empty Town (scenes/ui/title_town.png) drifting slowly
## (its look: Background > Material in the Inspector). Retake the still with
## scripts/ui/capture_title_background.gd. The level list lives in scripts/ui/chapters.gd.
## Keyboard (arrows / WASD, Enter, Esc), mouse and gamepad (stick / D-pad, A, B) all work.

const ITEM_WIDTH := 240.0
const CHAPTER_WIDTH := 300.0

@onready var main_list: VBoxContainer = $Main
@onready var chapters: PanelContainer = $Chapters
@onready var chapter_list: VBoxContainer = $Chapters/List
@onready var settings: PanelContainer = $Settings
@onready var hints: Label = $Hints
@onready var logo: Control = $Logo
@onready var fade: ColorRect = $Fade

var _starting := false
var _return_to: Control  # the line that opened a page; it gets the focus back when the page closes


func _ready() -> void:
	add_to_group("title_screen")  # the pause menu never opens while this is up
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SaveGame.recording = true
	var last := SaveGame.last_level()
	if last != "":
		main_list.add_child(MenuItem.make("Continue", ITEM_WIDTH, _start.bind(last), Chapters.label_of(last)))
	main_list.add_child(MenuItem.make("New Game", ITEM_WIDTH, _start.bind(Chapters.FIRST_LEVEL)))
	main_list.add_child(MenuItem.make("Chapters", ITEM_WIDTH, _open_chapters))
	main_list.add_child(MenuItem.make("Settings", ITEM_WIDTH, _open_settings))
	main_list.add_child(MenuItem.make("Quit", ITEM_WIDTH, func() -> void: get_tree().quit()))
	_build_chapters()
	settings.closed.connect(_show_main)
	_show_main()
	_intro()
	MusicBus.play("title", 2.0)  # fades in with the picture


func _build_chapters() -> void:
	var header := Label.new()
	header.text = "CHAPTERS"
	header.theme_type_variation = "HeaderLabel"
	chapter_list.add_child(header)
	chapter_list.add_child(_rule())
	for entry: Array in Chapters.LIST:
		var number: String = entry[0] if entry[0] != "" else "test"
		chapter_list.add_child(MenuItem.make(entry[1], CHAPTER_WIDTH, _start.bind(entry[2]), number))
	chapter_list.add_child(_rule())
	chapter_list.add_child(MenuItem.make("Back", CHAPTER_WIDTH, _show_main))


## Fades in from black: the picture first, then the name, then the menu, one line at a time.
func _intro() -> void:
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	logo.modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(logo, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	for i in main_list.get_child_count():
		var item: Control = main_list.get_child(i)
		item.modulate.a = 0.0
		var ti := create_tween()
		ti.tween_interval(0.9 + 0.08 * i)
		ti.tween_property(item, "modulate:a", 1.0, 0.35)
	hints.modulate.a = 0.0
	var th := create_tween()
	th.tween_interval(1.4)
	th.tween_property(hints, "modulate:a", 1.0, 0.6)


func _show_main() -> void:
	chapters.visible = false
	settings.visible = false
	main_list.visible = true
	var target: Control = _return_to if is_instance_valid(_return_to) else main_list.get_child(0)
	MenuFx.focus_quietly(target)
	hints.text = "Enter / A   select"


func _open_chapters() -> void:
	_return_to = get_viewport().gui_get_focus_owner()
	main_list.visible = false
	chapters.visible = true
	chapters.modulate.a = 0.0
	create_tween().tween_property(chapters, "modulate:a", 1.0, 0.15)
	MenuFx.focus_quietly(chapter_list.get_child(2))  # the first chapter (after header and rule)
	hints.text = "Enter / A   select        Esc / B   back"


func _open_settings() -> void:
	_return_to = get_viewport().gui_get_focus_owner()
	main_list.visible = false
	settings.open()
	hints.text = "Left / Right   change        Esc / B   back"


## Starts a level with the usual fade (Story's go_to_level, which also records it for Continue).
func _start(path: String) -> void:
	if _starting:
		return
	_starting = true
	get_viewport().gui_release_focus()
	var story := get_node_or_null("/root/Story")
	if story:
		story.go_to_level(path)
	else:
		get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if event.is_action_pressed("ui_cancel"):
		if settings.visible:
			settings.close()  # its closed signal brings the main list back
		elif chapters.visible:
			_show_main()
		get_viewport().set_input_as_handled()
	elif MenuFx.extra_nav(event, get_viewport()):
		get_viewport().set_input_as_handled()
	elif get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_down") \
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept")):
		_refocus()  # the mouse clicked the focus away: a key or the pad brings it back
		get_viewport().set_input_as_handled()


func _refocus() -> void:
	if settings.visible:
		settings.focus_first()
	elif chapters.visible:
		MenuFx.focus_quietly(chapter_list.get_child(2))
	else:
		MenuFx.focus_quietly(main_list.get_child(0))


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = MenuFx.LINE
	rule.custom_minimum_size.y = 1
	return rule
