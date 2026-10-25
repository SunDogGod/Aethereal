extends PanelContainer
## How the prompt line at the bottom of the screen looks ("F / X   Take down",
## "E / Up: The well"). The Prompt label in player.tscn still holds the text and decides
## whether it shows (other scripts and tests read it); this panel sits on top of it and
## draws the text as a key cap, the action, and an optional note in brackets, in the menus'
## style. The label's own letters are hidden (self_modulate), so only this panel is seen.

const WARNING := Color(1.0, 0.42, 0.32)   ## a note with "!" in it (another agent will see)

var _key: Label
var _cap: PanelContainer
var _action: Label
var _note: Label
var _text := ""


func _ready() -> void:
	name = "PromptView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.035, 0.06, 0.82)  # MenuFx.INK
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.5, 0.66, 0.45)  # MenuFx.LINE
	style.set_corner_radius_all(2)
	style.content_margin_left = 4
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_cap = PanelContainer.new()
	_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap_style := StyleBoxFlat.new()
	cap_style.bg_color = Color(MenuFx.ACCENT, 0.16)
	cap_style.set_border_width_all(1)
	cap_style.border_color = MenuFx.ACCENT
	cap_style.set_corner_radius_all(2)
	cap_style.content_margin_left = 5
	cap_style.content_margin_right = 5
	_cap.add_theme_stylebox_override("panel", cap_style)
	row.add_child(_cap)
	_key = _label(10, MenuFx.BRIGHT)
	_cap.add_child(_key)
	_action = _label(12, MenuFx.BRIGHT)
	row.add_child(_action)
	_note = _label(10, Color(MenuFx.ACCENT, 0.9))
	row.add_child(_note)


## Splits "KEYS   Action  (note)" or "KEYS: Action" into its parts and shows them.
func show_text(text: String) -> void:
	if text == _text:
		return
	_text = text
	var keys := ""
	var action := text
	var cut := text.find("   ")
	var colon := text.find(":")
	if colon > 0 and colon <= 12 and (cut < 0 or colon < cut):
		keys = text.substr(0, colon)
		action = text.substr(colon + 1)
	elif cut > 0 and cut <= 12:
		keys = text.substr(0, cut)
		action = text.substr(cut + 3)
	var note := ""
	var bracket := action.find("(")
	if bracket > 0 and action.ends_with(")"):
		note = action.substr(bracket)
		action = action.substr(0, bracket)
	_key.text = keys.strip_edges()
	_cap.visible = _key.text != ""
	_action.text = action.strip_edges()
	_note.text = note
	_note.visible = note != ""
	_note.add_theme_color_override("font_color", WARNING if note.contains("!") else Color(MenuFx.ACCENT, 0.9))
	reset_size()
	# Recentre on the Prompt label (the panel is its child, anchored to its middle).
	offset_left = -size.x * 0.5
	offset_right = size.x * 0.5
	offset_top = -size.y * 0.5
	offset_bottom = size.y * 0.5


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
