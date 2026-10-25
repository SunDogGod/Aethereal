extends CanvasLayer
## The dev overlay (DevTools/Overlay), switched on from the dev menu: FPS, where Aeneas is,
## the last checkpoint, the switches that are on, and every agent's state, nearest first.
## It keeps updating while the game is paused, so you can read it behind the menu.

const THEME := preload("res://scenes/ui/menu_theme.tres")
const MAX_GUARDS := 14   ## more than this and the list is cut short
const EVERY := 0.1       ## seconds between refreshes (real time, whatever the time scale)

var cheats: Node
var places: Node

var _panel: PanelContainer
var _text: RichTextLabel
var _next := 0


func _ready() -> void:
	layer = 44  # over the HUD and the pause menu (40), under the dev menu (45)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_panel = PanelContainer.new()
	_panel.theme = THEME
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MenuFx.INK, 0.72)
	style.border_color = MenuFx.LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(6)
	style.content_margin_left = 8
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -10.0
	_panel.offset_top = 40.0
	add_child(_panel)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.scroll_active = false
	_text.custom_minimum_size.x = 236
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 9)
	_text.add_theme_font_size_override("bold_font_size", 9)
	_text.add_theme_color_override("default_color", MenuFx.DIM)
	_text.add_theme_constant_override("table_h_separation", 6)
	_panel.add_child(_text)


func _process(_delta: float) -> void:
	if not visible or Time.get_ticks_msec() < _next:
		return
	_next = Time.get_ticks_msec() + int(EVERY * 1000.0)
	refresh()


## Rewrites the text now (the menu calls it when the overlay is switched on).
func refresh() -> void:
	_text.text = compose()


## The overlay's text (BBCode), also handy for tests.
func compose() -> String:
	var lines: PackedStringArray = []
	var flags: PackedStringArray = []
	if cheats.god:
		flags.append("GOD")
	if cheats.noclip.on:
		flags.append("NOCLIP")
	if cheats.blind:
		flags.append("BLIND")
	if cheats.time_scale != 1.0:
		flags.append("%sx" % _num(cheats.time_scale))
	if cheats.skipping:
		flags.append("SKIPPING")
	lines.append("%s   %s" % [_amber("DEV"), _bright("  ".join(flags))])
	lines.append("FPS  %s" % _bright(str(roundi(Engine.get_frames_per_second()))))
	var p = cheats.player()
	if p:
		var at: Vector3 = p.global_position
		lines.append("Aeneas  %s  %s" % [_bright("%.1f  %.1f  %.1f" % [at.x, at.y, at.z]),
				"flying" if cheats.noclip.on else ("floor" if p.is_on_floor() else "air")])
	else:
		lines.append("Aeneas  -")
	var cp: Vector3 = places.checkpoint_at
	lines.append("Checkpoint  %s  (%.0f, %.0f, %.0f)" % [_bright(places.checkpoint_name), cp.x, cp.y, cp.z])
	lines.append("Story  %s" % (_amber("scene playing") if cheats.story_playing() else "-"))
	lines.append(_guard_table(p))
	return "\n".join(lines)


func _guard_table(p) -> String:
	var list: Array = get_tree().get_nodes_in_group("guards")
	if list.is_empty():
		return "Guards  none"
	var origin: Vector3 = p.global_position if p else Vector3.ZERO
	list.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(origin) < b.global_position.distance_to(origin))
	var cells := "[table=4]"
	for guard: Node3D in list.slice(0, MAX_GUARDS):
		var state := _state_name(guard)
		var sus := float(guard.get("suspicion")) if "suspicion" in guard else 0.0
		var colour := MenuFx.DIM
		if state in ["SPOTTED", "FIGHTING"]:
			colour = Color(1.0, 0.35, 0.3)
		elif state in ["SUSPICIOUS", "STAGGERED"]:
			colour = MenuFx.ACCENT
		elif state == "DOWN":
			colour = Color(MenuFx.DIM, 0.45)
		elif guard.get("dormant") == true:
			state = "WAITING"
		cells += "[cell]%s[/cell][cell][color=#%s]%s[/color][/cell][cell]%s[/cell][cell]%.0f m[/cell]" % [
				guard.name, colour.to_html(false), state,
				("%d%%" % roundi(sus * 100.0)) if sus > 0.0 else "", guard.global_position.distance_to(origin)]
	cells += "[/table]"
	var more := list.size() - MAX_GUARDS
	return "Guards (%d)\n%s%s" % [list.size(), cells, ("\n+%d more" % more) if more > 0 else ""]


## "PATROL" for a guard's state number, read from his script's State enum.
func _state_name(guard: Node) -> String:
	var value: Variant = guard.get("state")
	if value == null:
		return "?"
	var script: Script = guard.get_script()
	var states: Variant = script.get_script_constant_map().get("State") if script else null
	if states is Dictionary:
		for key: String in states:
			if states[key] == value:
				return key
	return str(value)


func _num(value: float) -> String:
	return str(value).trim_suffix(".0")


func _bright(words: String) -> String:
	return "[color=#%s]%s[/color]" % [MenuFx.BRIGHT.to_html(false), words]


func _amber(words: String) -> String:
	return "[color=#%s]%s[/color]" % [MenuFx.ACCENT.to_html(false), words]
