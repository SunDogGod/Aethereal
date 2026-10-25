@tool
extends VBoxContainer
## The "Aethereal" dock's buttons. It only shows them and says what was pressed; plugin.gd
## does the work. Each button is [label, what it makes, editor icon, tooltip].

signal add_requested(kind: String, label: String)
signal bake_requested
signal guide_requested
signal new_level_requested

const ACCENT := Color(1.0, 0.76, 0.4)  # the amber of the menus (scripts/ui/menu_fx.gd)
const Builders := preload("res://addons/aethereal_tools/builders.gd")

const SECTIONS := [
	["Story", [
		["Story trigger", "story_trigger", "Area3D", "A zone that plays a dialogue scene when Aeneas walks in.\nFill in Scene (the name between === marks) in the Inspector."],
		["Look-at spot", "look_spot", "Area3D", "Something Aeneas can look at (E / D-pad up).\nWrite its words in Text and its prompt in Label."],
		["Camera shot", "camera_shot", "Camera3D", "A story camera, placed exactly where the 3D view is looking.\nFrame the shot first, then press. Use it with [camera Name]."],
		["Checkpoint", "checkpoint", "Area3D", "A save spot: restarts (spotted, slain, fell) come back here.\nIts origin is where Aeneas reappears."],
	]],
	["Agents", [
		["Agency guard", "guard", "CharacterBody3D", "An Agency agent with a two-point patrol Route, facing away from you.\nWith a Fight selected, he joins the fight instead."],
		["Patrol point", "patrol_point", "Marker3D", "Adds the next point to the selected guard's Route,\nwhere you look (or 3 m past his last point)."],
		["Fight", "fight", "Node3D", "A story fight with one agent in it. A scene starts it with [fight Name].\nAdd more agents by selecting it and pressing Agency guard."],
	]],
	["Life signs", [
		["Flicker light", "flicker_light", "OmniLight3D", "A lamp that blinks and buzzes now and then (Personality in the Inspector)."],
		["Steam vent", "steam_vent", "GPUParticles3D", "Steam from a grille. Point at a wall for a wall vent, at the floor for a grate."],
		["Drip", "drip", "Node3D", "Water dripping from the ceiling (or 2.8 m up) to the floor."],
		["TV window", "tv_window", "StaticBody3D", "A window lit by a TV. Point at a building wall."],
	]],
	["Building", [
		["Block", "block", "StaticBody3D", "A 2 m box with collision. Change Size and Material in the Inspector.\nWith a Block selected, the new one goes next to it."],
		["Building", "building", "StaticBody3D", "A Block with Style = Building: doors, shopfronts, windows, roof.\nTurn Ground Floor off if it doesn't stand on a street."],
	]],
]

var place_mode: OptionButton
var _level_label: Label
var _status: Label
var _props_box: VBoxContainer
var _grids: Array[GridContainer] = []  # every button grid: two columns when the labels fit, else one
var _theme: Theme


func setup(editor_theme: Theme) -> void:
	_theme = editor_theme
	name = "Aethereal"
	add_theme_constant_override("separation", 6)
	_level_label = Label.new()
	_level_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_level_label)
	var row := HBoxContainer.new()
	var where := Label.new()
	where.text = "Place"
	row.add_child(where)
	place_mode = OptionButton.new()
	place_mode.add_item("In front of the view", 0)
	place_mode.add_item("At the selected node", 1)
	place_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_mode.tooltip_text = "In front of the view: on the floor where the 3D view's centre looks.\nAt the selected node: on top of a selected Block, or on the floor under the node."
	row.add_child(place_mode)
	add_child(row)
	for section: Array in SECTIONS:
		var grid := _section(section[0])
		for b: Array in section[1]:
			_button(grid, b[0], b[2], b[3], add_requested.emit.bind(b[1], b[0]))
	_header("Props")
	_props_box = VBoxContainer.new()
	add_child(_props_box)
	refresh_props()
	var level := _section("Level")
	_button(level, "Bake navigation", "NavigationRegion3D", "Rebakes the floor fighters path over (the level's Navigation node).\nDo it after moving walls, ramps or columns where fights happen.", bake_requested.emit)
	_button(level, "New level...", "PackedScene", "Makes a new level from the template, with its own dialogue file, and opens it.", new_level_requested.emit)
	_button(level, "Open the guide", "Help", "How to customize everything: docs/customizing.md.", guide_requested.emit)
	add_child(HSeparator.new())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 120
	_status.modulate = Color(1, 1, 1, 0.8)
	add_child(_status)
	say("Open a level, look at a spot in the 3D view, press a button.")


## Rebuilds the Props buttons from the scripts in scripts/props/ and scripts/props_*/ (new ones
## keep being written): the town's props first, then each level's own under a small heading.
func refresh_props() -> void:
	for child in _props_box.get_children():
		if child is GridContainer:
			_grids.erase(child)
		_props_box.remove_child(child)
		child.queue_free()
	var group := ""
	var grid := _grid(_props_box)
	for entry: Array in Builders.list_props():
		if entry[2] != group:  # a level's own props: a small heading and a grid of their own
			group = entry[2]
			var heading := Label.new()
			heading.text = group + ":"
			heading.modulate = Color(ACCENT, 0.8)
			_props_box.add_child(heading)
			grid = _grid(_props_box)
		var tip := "%s (%s). Kind and Variant in the Inspector pick what it is." % [entry[0], entry[1]]
		_button(grid, entry[0], "MeshInstance3D", tip, add_requested.emit.bind("prop:" + entry[1], entry[0]))
	_button(_grid(_props_box), "Refresh list", "Reload", "Look again for prop scripts in scripts/props/.", refresh_props)
	_relayout.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		_relayout()


## Two buttons a row when every label in that grid fits half the dock, otherwise one, so a
## label is never cut off however wide the dock is dragged.
func _relayout() -> void:
	if not is_inside_tree():
		return
	var half := (size.x - 4.0) * 0.5
	for grid in _grids:
		if not is_instance_valid(grid):
			continue
		var need := 0.0
		for child in grid.get_children():
			if child is Button:
				need = maxf(need, _natural_width(child))
		var columns := 2 if need <= half else 1
		if grid.columns != columns:
			grid.columns = columns


func _natural_width(b: Button) -> float:
	var font := b.get_theme_font("font")
	var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
	if b.icon:
		w += b.icon.get_width() + b.get_theme_constant("h_separation")
	return w + b.get_theme_stylebox("normal").get_minimum_size().x + 4.0


func show_level(root: Node) -> void:
	if _level_label == null:
		return
	if root == null:
		_level_label.text = "No scene open."
	else:
		var file := root.scene_file_path.get_file() if root.scene_file_path != "" else "(unsaved scene)"
		_level_label.text = "Adding to: " + file


func say(text: String) -> void:
	if _status:
		_status.text = text


func _section(title: String) -> GridContainer:
	_header(title)
	return _grid(self)


func _header(title: String) -> void:
	var header := Label.new()
	header.text = title.to_upper()
	header.add_theme_color_override("font_color", ACCENT)
	add_child(header)


func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	_grids.append(grid)
	return grid


func _button(parent: Control, text: String, icon: String, tip: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.custom_minimum_size.x = 60
	if _theme and _theme.has_icon(icon, "EditorIcons"):
		b.icon = _theme.get_icon(icon, "EditorIcons")
	b.pressed.connect(action)
	parent.add_child(b)
