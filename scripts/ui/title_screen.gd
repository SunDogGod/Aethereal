extends Control
## The title screen, the game's main scene: Continue, New Game, Chapters, Settings, Quit.
## The background is a still of the Empty Town (scenes/ui/title_town.png) drifting slowly
## (its look: Background > Material in the Inspector). Retake the still with
## scripts/ui/capture_title_background.gd. The level list lives in scripts/ui/chapters.gd.
## Keyboard (arrows / WASD, Enter, Esc), mouse and gamepad (stick / D-pad, A, B) all work.
## Continue returns to the last save (the game saves by itself: scripts/autosave.gd). New Game and
## the chapters ask first when that would replace a save (save_game.gd keeps one spare copy).

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
var _confirm: PanelContainer  # "Start a new game?", asked before a save would be replaced
var _question: Label
var _note: Label
var _no: MenuItem
var _replace_path := ""       # the level Yes starts
var _asked_from_chapters := false


func _ready() -> void:
	add_to_group("title_screen")  # the pause menu never opens while this is up
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SaveGame.recording = true
	var save := SaveGame.load_save()
	if not save.is_empty():
		main_list.add_child(MenuItem.make("Continue", ITEM_WIDTH, _continue.bind(save), SaveGame.describe(save)))
	main_list.add_child(MenuItem.make("New Game", ITEM_WIDTH, _ask_replace.bind(Chapters.FIRST_LEVEL, "Start a new game?")))
	main_list.add_child(MenuItem.make("Chapters", ITEM_WIDTH, _open_chapters))
	main_list.add_child(MenuItem.make("Settings", ITEM_WIDTH, _open_settings))
	main_list.add_child(MenuItem.make("Quit", ITEM_WIDTH, func() -> void: get_tree().quit()))
	_build_chapters()
	_build_confirm()
	settings.closed.connect(_show_main)
	_show_main()
	_intro()
	MusicBus.play("title", 2.0)  # fades in with the picture
	# Where New Game and Continue lead starts loading on a background thread while the menu is up
	# (scene_loader.gd), so pressing them doesn't wait for the files.
	SceneLoader.fetch(World.SCENE)
	if not save.is_empty() and not World.has_level(save.level):
		SceneLoader.fetch(save.level)


func _build_chapters() -> void:
	var header := Label.new()
	header.text = "CHAPTERS"
	header.theme_type_variation = "HeaderLabel"
	chapter_list.add_child(header)
	chapter_list.add_child(_rule())
	for entry: Array in Chapters.LIST:
		var number: String = entry[0] if entry[0] != "" else "test"
		chapter_list.add_child(MenuItem.make(entry[1], CHAPTER_WIDTH, _ask_replace.bind(entry[2], "Play this chapter?"), number))
	chapter_list.add_child(_rule())
	chapter_list.add_child(MenuItem.make("Back", CHAPTER_WIDTH, _show_main))


## The yes/no box shown before a save would be replaced (same look as the pause menu's).
func _build_confirm() -> void:
	_confirm = PanelContainer.new()
	_confirm.name = "Confirm"
	_confirm.visible = false
	_confirm.custom_minimum_size = Vector2(300, 0)
	_confirm.set_anchors_preset(Control.PRESET_CENTER)
	_confirm.offset_left = -150.0
	_confirm.offset_right = 150.0
	_confirm.offset_top = -50.0
	_confirm.offset_bottom = 50.0
	_confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_confirm.add_child(box)
	_question = Label.new()
	_question.theme_type_variation = "BodyLabel"
	_question.add_theme_font_size_override("font_size", 14)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_question)
	_note = Label.new()
	_note.theme_type_variation = "HintLabel"
	_note.add_theme_font_size_override("font_size", 10)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_note)
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 12)
	answers.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(answers)
	_no = MenuItem.make("No", 96.0, _back_from_confirm)
	answers.add_child(_no)
	answers.add_child(MenuItem.make("Yes", 96.0, func() -> void: _start(_replace_path)))
	add_child(_confirm)
	move_child(_confirm, fade.get_index())  # under the fade


## New Game or a chapter: straight in when there is nothing to lose, otherwise it asks first
## ("No" has the focus, so a stray press never throws a save away).
func _ask_replace(path: String, question: String) -> void:
	var save := SaveGame.load_save()
	if save.is_empty() or (save.fresh and save.level == path) or not Chapters.is_story_level(path):
		_start(path)  # no save, just the start of this same level, or a test space (never saved)
		return
	_replace_path = path
	_asked_from_chapters = chapters.visible
	_return_to = get_viewport().gui_get_focus_owner()
	_question.text = question
	_note.text = "This replaces your saved game (%s)." % SaveGame.describe(save)
	main_list.visible = false
	chapters.visible = false
	_confirm.visible = true
	_confirm.modulate.a = 0.0
	create_tween().tween_property(_confirm, "modulate:a", 1.0, 0.12)
	MenuFx.focus_quietly(_no)
	hints.text = "Enter / A   select        Esc / B   back"


## "No" or Esc on the question: back to the page that asked.
func _back_from_confirm() -> void:
	if not _asked_from_chapters:
		_show_main()
		return
	_confirm.visible = false
	chapters.visible = true
	MenuFx.focus_quietly(_return_to if is_instance_valid(_return_to) else chapter_list.get_child(2))
	hints.text = "Enter / A   select        Esc / B   back"
	_return_to = main_list.find_child("Chapters", false, false)  # Esc on the page goes back to Chapters


## Continue: the level loads with the save put back as it starts (save_restore.gd). A save from
## the very start of a level just starts that level.
func _continue(save: Dictionary) -> void:
	if _starting:
		return
	SaveGame.pending = {} if save.fresh else save
	_start(save.level, false)


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
	_confirm.visible = false
	main_list.visible = true
	var target: Control = _return_to if is_instance_valid(_return_to) and main_list.is_ancestor_of(_return_to) \
			else main_list.get_child(0)
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


## Starts a level with the usual fade (Story's go_to_level). `fresh` saves the start of that level,
## so Continue starts there until the game saves again; Continue itself passes false.
func _start(path: String, fresh := true) -> void:
	if _starting:
		return
	_starting = true
	get_viewport().gui_release_focus()
	var story := get_node_or_null("/root/Story")
	if story:
		story.go_to_level(path, fresh)
	else:
		get_tree().change_scene_to_file(path)


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if event.is_action_pressed("ui_cancel"):
		if settings.visible:
			settings.close()  # its closed signal brings the main list back
		elif _confirm.visible:
			_back_from_confirm()
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
	elif _confirm.visible:
		MenuFx.focus_quietly(_no)
	elif chapters.visible:
		MenuFx.focus_quietly(chapter_list.get_child(2))
	else:
		MenuFx.focus_quietly(main_list.get_child(0))


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = MenuFx.LINE
	rule.custom_minimum_size.y = 1
	return rule
