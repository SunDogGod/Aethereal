class_name SkipHint
extends Control
## "Hold TAB to skip": a small ring and a word in the top-right corner while a story scene plays.
## It never shows by itself: pressing the skip button (Tab, or the gamepad's Back / Select / View,
## the Stadia's three dots) brings it up, and holding the button for HOLD seconds fills the ring
## and skips the scene (story_skip.gd). Let go early and the ring drains, and the hint fades a
## moment later. A hold only counts if it started during the scene, so a button still held from
## the last skip can't skip the next scene too.

signal skip

const HOLD := 0.7     ## seconds to hold
const LINGER := 2.0   ## seconds the hint stays up after the button is let go
const RADIUS := 5.0
const ACTION := "skip_cutscene"

var can_skip := Callable()  ## Story's helper: true while a scene that may be skipped is playing

var _held := 0.0
var _holding := false  # the button went down during this scene and is still down
var _linger := 0.0
var _pad := false      # the last skip press came from a gamepad
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sees the pause menu open, and hides under it
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -170.0
	offset_right = -10.0
	offset_top = 6.0
	offset_bottom = 20.0
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_right = -RADIUS * 2.0 - 6.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", MenuFx.DIM)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 3)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	modulate.a = 0.0
	_ensure_action()


func _input(event: InputEvent) -> void:
	if event.is_action(ACTION) and event.is_pressed():
		_pad = event is InputEventJoypadButton


func _process(delta: float) -> void:
	var allowed: bool = not get_tree().paused and can_skip.is_valid() and can_skip.call()
	if not allowed:
		_held = 0.0
		_holding = false
		_linger = 0.0
	elif Input.is_action_just_pressed(ACTION):
		_holding = true
	if _holding and not Input.is_action_pressed(ACTION):
		_holding = false
	if _holding:
		_linger = LINGER
		_held += delta
		if _held >= HOLD:
			_held = 0.0
			_holding = false
			_linger = 0.0
			modulate.a = 0.0  # gone as the screen dips
			skip.emit()
	else:
		_held = maxf(0.0, _held - delta * 2.0)
		_linger = maxf(0.0, _linger - delta)
	modulate.a = move_toward(modulate.a, 1.0 if _linger > 0.0 else 0.0, delta * 6.0)
	if modulate.a > 0.0:
		_label.text = "Hold %s to skip" % ("SELECT" if _pad else "TAB")
		queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x - RADIUS - 1.0, size.y * 0.5)
	draw_arc(center, RADIUS, 0.0, TAU, 24, Color(MenuFx.DIM, 0.35), 1.5, true)
	if _held > 0.0:
		draw_arc(center, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * clampf(_held / HOLD, 0.0, 1.0), 24,
				MenuFx.ACCENT, 2.0, true)


## "skip_cutscene" lives in the Input Map (project.godot); this puts it back if it ever goes missing.
func _ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_TAB
	InputMap.action_add_event(ACTION, key)
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event(ACTION, back)
