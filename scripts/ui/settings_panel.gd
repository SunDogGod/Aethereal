extends PanelContainer
## The Settings page, shared by the title screen and the pause menu. Every change takes
## effect at once and is saved to user://settings.cfg (GameSettings holds the values).
## To add a setting: add it to GameSettings (a static var plus get_value/set_value), then a
## line to ROWS. Up/down picks a row; left/right (or A/D, or the stick) changes it.

signal closed

const ROWS := [
	# [GameSettings name, what the row says, min, max, step]. No numbers = an ON/OFF switch.
	["master_volume", "Master volume", 0.0, 1.0, 0.05],
	["music_volume", "Music volume", 0.0, 1.0, 0.05],
	["effects_volume", "Effects volume", 0.0, 1.0, 0.05],
	["mouse_sensitivity", "Mouse sensitivity", 0.25, 3.0, 0.05],
	["stick_sensitivity", "Gamepad look speed", 0.25, 3.0, 0.05],
	["invert_y", "Invert camera up / down"],
	["fullscreen", "Fullscreen"],
]
const WIDTH := 420.0

@onready var list: VBoxContainer = $List

var _controls := {}  # setting name -> its HSlider or toggle Button
var _values := {}    # setting name -> the Label showing a slider's value
var _first: Control


func _ready() -> void:
	custom_minimum_size.x = WIDTH
	var header := Label.new()
	header.text = "SETTINGS"
	header.theme_type_variation = "HeaderLabel"
	list.add_child(header)
	list.add_child(_rule())
	for row: Array in ROWS:
		list.add_child(_make_row(row))
	list.add_child(_rule())
	list.add_child(MenuItem.make("Back", WIDTH - 32.0, close))


## Shows the page with the current values and the first row highlighted.
func open() -> void:
	for key: String in _controls:
		var control: Control = _controls[key]
		if control is HSlider:
			control.set_value_no_signal(float(GameSettings.get_value(key)))
			_show_value(key)
		else:
			control.set_pressed_no_signal(bool(GameSettings.get_value(key)))
			control.text = "ON" if control.button_pressed else "OFF"
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	focus_first()


func focus_first() -> void:
	MenuFx.focus_quietly(_first)


func close() -> void:
	visible = false
	closed.emit()


func _make_row(row: Array) -> Control:
	var key: String = row[0]
	var box := PanelContainer.new()
	var idle := StyleBoxEmpty.new()
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(MenuFx.ACCENT, 0.08)
	lit.border_color = MenuFx.ACCENT
	lit.border_width_left = 2
	for style: StyleBox in [idle, lit]:
		style.content_margin_left = 10
		style.content_margin_right = 6
		style.content_margin_top = 3
		style.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", idle)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	box.add_child(line)
	var name_label := Label.new()
	name_label.text = row[1]
	name_label.custom_minimum_size.x = 170
	name_label.add_theme_color_override("font_color", MenuFx.DIM)
	line.add_child(name_label)
	var control: Control
	var value_slot := Control.new()  # the right-hand column: a value or an ON/OFF box
	value_slot.custom_minimum_size = Vector2(52, 18)
	if row.size() > 2:
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = row[4]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.custom_minimum_size.y = 16
		slider.value_changed.connect(func(v: float) -> void: _changed(key, v))
		line.add_child(slider)
		var value := Label.new()
		value.theme_type_variation = "ValueLabel"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.set_anchors_preset(Control.PRESET_FULL_RECT)
		value_slot.add_child(value)
		_values[key] = value
		control = slider
	else:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(gap)
		var toggle := Button.new()
		toggle.toggle_mode = true
		toggle.theme_type_variation = "ToggleBox"
		toggle.set_anchors_preset(Control.PRESET_FULL_RECT)
		toggle.toggled.connect(func(on: bool) -> void: _changed(key, on))
		# Left/right flips the switch too, like a slider with two stops.
		toggle.gui_input.connect(func(event: InputEvent) -> void:
			if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
				toggle.button_pressed = not toggle.button_pressed
				toggle.accept_event())
		value_slot.add_child(toggle)
		control = toggle
	line.add_child(value_slot)
	control.focus_mode = Control.FOCUS_ALL
	control.focus_entered.connect(func() -> void:
		box.add_theme_stylebox_override("panel", lit)
		name_label.add_theme_color_override("font_color", MenuFx.BRIGHT)
		MenuFx.blip(control))
	control.focus_exited.connect(func() -> void:
		box.add_theme_stylebox_override("panel", idle)
		name_label.add_theme_color_override("font_color", MenuFx.DIM))
	box.mouse_entered.connect(control.grab_focus)
	control.mouse_entered.connect(control.grab_focus)
	_controls[key] = control
	if _first == null:
		_first = control
	return box


func _changed(key: String, value: Variant) -> void:
	GameSettings.set_value(key, value)
	GameSettings.apply()
	GameSettings.save_file()
	if _values.has(key):
		_show_value(key)
	else:
		_controls[key].text = "ON" if value else "OFF"
	MenuFx.blip(self)


func _show_value(key: String) -> void:
	var v := float(GameSettings.get_value(key))
	_values[key].text = ("%d%%" % roundi(v * 100.0)) if key.ends_with("_volume") else ("%.2fx" % v)


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = MenuFx.LINE
	rule.custom_minimum_size.y = 1
	return rule
