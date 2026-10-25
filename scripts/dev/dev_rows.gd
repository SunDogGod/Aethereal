extends RefCounted
## Builds the dev menu's lines in the style of the other menus (MenuFx colours, MenuItem
## lines, the Settings page's ON/OFF boxes).
##   Rows.action(text, width, on_press, detail)  a MenuItem with small amber text on the right
##   Rows.switch(parent, text, on_toggle)         a line with an ON/OFF box (Settings style)
##   Rows.choice(parent, text, on_step)           a line with a value box: press or left/right steps it

const FONT := 13            ## size of the menu lines
const DETAIL := &"dev_detail"
const STEP := &"dev_step"   ## a choice box keeps its stepping Callable in this meta


## A menu line that does something. Its right-hand text can change later: set_detail().
static func action(text: String, width: float, on_press: Callable, detail := "") -> MenuItem:
	var item := MenuItem.make(text, width, on_press, "", FONT)
	var label := Label.new()
	label.text = detail
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(MenuFx.ACCENT, 0.75))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_right = -8.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.set_meta(DETAIL, label)
	item.ready.connect(item.add_child.bind(label), CONNECT_ONE_SHOT)  # on top of its glow
	return item


static func set_detail(item: Control, text: String) -> void:
	if item.has_meta(DETAIL):
		(item.get_meta(DETAIL) as Label).text = text


## An ON/OFF line. Returns its box (a toggle Button); on_toggle gets true / false.
static func switch(parent: Control, text: String, on_toggle: Callable) -> Button:
	var button := _row(parent, text)
	button.toggle_mode = true
	button.text = "OFF"
	button.toggled.connect(func(on: bool) -> void:
		button.text = "ON" if on else "OFF"
		MenuFx.blip(button)
		on_toggle.call(on))
	return button


## A line with a value that steps (the time scale). on_step gets +1 or -1.
static func choice(parent: Control, text: String, on_step: Callable) -> Button:
	var button := _row(parent, text)
	button.set_meta(STEP, on_step)
	button.pressed.connect(func() -> void:
		MenuFx.blip(button)
		on_step.call(1))
	return button


## A small amber heading inside a list (the Teleport page's groups).
static func section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "HeaderLabel"
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(MenuFx.ACCENT, 0.8))
	return label


static func rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = MenuFx.LINE
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## The Settings page's row look: the name on the left, a box on the right, an amber edge
## and a faint glow while it has the focus. Left / right on the box flips or steps it.
static func _row(parent: Control, text: String) -> Button:
	var box := PanelContainer.new()
	var idle := StyleBoxEmpty.new()
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(MenuFx.ACCENT, 0.08)
	lit.border_color = MenuFx.ACCENT
	lit.border_width_left = 2
	for style: StyleBox in [idle, lit]:
		style.content_margin_left = 14
		style.content_margin_right = 8
		style.content_margin_top = 2
		style.content_margin_bottom = 2
	box.add_theme_stylebox_override("panel", idle)
	var line := HBoxContainer.new()
	box.add_child(line)
	var name_label := Label.new()
	name_label.text = text
	name_label.add_theme_font_size_override("font_size", FONT)
	name_label.add_theme_color_override("font_color", MenuFx.DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var button := Button.new()
	button.theme_type_variation = "ToggleBox"
	button.custom_minimum_size = Vector2(52, 18)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	line.add_child(button)
	button.gui_input.connect(func(event: InputEvent) -> void:
		var step := 0
		if event.is_action_pressed("ui_left"):
			step = -1
		elif event.is_action_pressed("ui_right"):
			step = 1
		if step == 0:
			return
		if button.toggle_mode:
			button.button_pressed = not button.button_pressed
		elif button.has_meta(STEP):
			MenuFx.blip(button)
			(button.get_meta(STEP) as Callable).call(step)
		button.accept_event())
	button.focus_entered.connect(func() -> void:
		box.add_theme_stylebox_override("panel", lit)
		name_label.add_theme_color_override("font_color", MenuFx.BRIGHT)
		MenuFx.blip(button))
	button.focus_exited.connect(func() -> void:
		box.add_theme_stylebox_override("panel", idle)
		name_label.add_theme_color_override("font_color", MenuFx.DIM))
	box.mouse_entered.connect(button.grab_focus)
	button.mouse_entered.connect(button.grab_focus)
	parent.add_child(box)
	return button
