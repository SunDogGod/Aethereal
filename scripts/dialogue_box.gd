class_name DialogueBox
extends CanvasLayer
## The text box at the bottom of the screen: who's speaking, and what they say.
## Lines type out; press Space / Enter / F (A or X on a gamepad) to finish the
## typing, then again to go on. Black bars slide in during camera shots.

signal advanced

const CHARS_PER_SECOND := 45.0
const BAR_HEIGHT := 26.0

@onready var panel: Control = $Panel
@onready var speaker: Label = $Panel/Speaker
@onready var words: Label = $Panel/Words
@onready var next_mark: Label = $Panel/Next
@onready var bar_top: ColorRect = $BarTop
@onready var bar_bottom: ColorRect = $BarBottom

var _shown := 0.0
var _typing := false
var _started_frame := -1  # the frame a line appeared: the press that opened it must not skip it


func _ready() -> void:
	panel.visible = false


func _process(delta: float) -> void:
	if not panel.visible:
		return
	if _typing:
		_shown += CHARS_PER_SECOND * delta
		words.visible_characters = int(_shown)
		if _shown >= words.text.length():
			_finish_typing()
	else:
		next_mark.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	if _pressed() and Engine.get_process_frames() > _started_frame:
		if _typing:
			_finish_typing()
		else:
			SfxBus.play("ui_blip", Vector3.INF, -8.0)
			advanced.emit()


## Shows one line and waits until the player moves on.
func say(who: String, text: String) -> void:
	panel.visible = true
	speaker.text = who
	speaker.visible = who != ""
	words.text = text
	words.visible_characters = 0
	_shown = 0.0
	_typing = true
	_started_frame = Engine.get_process_frames()
	next_mark.visible = false
	await advanced


func close() -> void:
	panel.visible = false


## Cinema bars for camera shots.
func letterbox(on: bool) -> void:
	var height := BAR_HEIGHT if on else 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(bar_top, "offset_bottom", height, 0.25)
	tween.tween_property(bar_bottom, "offset_top", -height, 0.25)


func _finish_typing() -> void:
	_typing = false
	words.visible_characters = -1
	next_mark.visible = true


## Space, Enter, F, and E (the look key) all move a line on; A, X and D-pad up on a gamepad.
func _pressed() -> bool:
	return Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("attack") \
			or Input.is_action_just_pressed("jump") \
			or (InputMap.has_action("interact") and Input.is_action_just_pressed("interact"))
