class_name MenuItem
extends Button
## One line of a menu. Without focus it is quiet grey text; with focus the text slides a
## little to the right and lights up, an amber bar shows on its left and a soft glow fades
## out behind it. Hovering the mouse moves the focus here, so there is only ever one
## highlight, whether you use a mouse, the keyboard or a gamepad.
##   MenuItem.make("Settings", 220, on_settings)          a plain line
##   MenuItem.make("Continue", 220, go, "0.3  Black Sand") with small text on the right

const HEIGHT := 24.0
const TEXT_X := 14.0   ## where the text sits without focus
const SLIDE := 7.0     ## how far it slides right with focus
const ANIM := 0.12     ## seconds

var label_text := ""
var detail := ""

var _label: Label
var _detail: Label
var _glow: TextureRect
var _bar: ColorRect
var _tween: Tween


static func make(text_: String, width: float, on_press: Callable, detail_ := "", font_size := 15) -> MenuItem:
	var item := MenuItem.new()
	item.label_text = text_
	item.detail = detail_
	item.custom_minimum_size = Vector2(width, HEIGHT)
	item.add_theme_font_size_override("font_size", font_size)
	item.pressed.connect(on_press)
	return item


func _ready() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	name = label_text.replace(" ", "")
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_glow = TextureRect.new()
	_glow.texture = MenuFx.glow_texture()
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.modulate.a = 0.0
	_bar = ColorRect.new()
	_bar.color = MenuFx.ACCENT
	_bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_bar.offset_right = 2.0
	_bar.offset_top = 4.0
	_bar.offset_bottom = -4.0
	_bar.modulate.a = 0.0
	_label = _make_label(label_text, get_theme_font_size("font_size"), MenuFx.DIM)
	_label.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_label.position.x = TEXT_X
	_detail = _make_label(detail, 10, Color(MenuFx.ACCENT, 0.75))
	_detail.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail.offset_left = -160.0
	_detail.offset_right = -8.0
	for child: Control in [_glow, _bar, _label, _detail]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(child)
	focus_entered.connect(_on_focus.bind(true))
	focus_exited.connect(_on_focus.bind(false))
	mouse_entered.connect(func() -> void:
		if not disabled and not has_focus():
			grab_focus())
	pressed.connect(_on_pressed)


func _make_label(words: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_focus(on: bool) -> void:
	if on:
		MenuFx.blip(self)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_label, "position:x", TEXT_X + (SLIDE if on else 0.0), ANIM)
	_tween.tween_method(_set_text_color, _label.get_theme_color("font_color"),
			MenuFx.BRIGHT if on else MenuFx.DIM, ANIM)
	_tween.tween_property(_bar, "modulate:a", 1.0 if on else 0.0, ANIM)
	_tween.tween_property(_glow, "modulate:a", 1.0 if on else 0.0, ANIM * 1.5)


func _set_text_color(color: Color) -> void:
	_label.add_theme_color_override("font_color", color)


## A quick flash of the glow when chosen.
func _on_pressed() -> void:
	MenuFx.blip(self, true)
	_glow.self_modulate = Color(2.2, 2.2, 2.2)
	create_tween().tween_property(_glow, "self_modulate", Color.WHITE, 0.25)
