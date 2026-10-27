extends CanvasLayer
## Build Mode's screen: a crosshair, a small corner panel (what is selected, what just happened),
## one line of keys at the bottom, and the asset browser on the right (Tab): every placeable
## thing as a tile; click one to place it where the crosshair points. It only shows things and
## reports clicks; build_mode.gd does the work.

signal asset_chosen(entry: Dictionary)

const TILE := Vector2(92, 86)
const GROUP_TINT := {"Prefabs": Color(0.85, 0.62, 0.32), "Prop scenes": Color(0.45, 0.68, 0.85)}
const HINTS := "WASD fly  Space/C up/down  right-drag look  click select, drag move  arrows PgUp PgDn nudge  " \
		+ "Q E turn  G snap  Ctrl+D copy  Del delete  Ctrl+Z undo  Tab assets  F2 leave"

var browser: PanelContainer
var tiles := {}  ## key_of(entry) -> the tile Button shown now
var icons := {}  ## key_of(entry) -> its picture (build_thumbs.gd), kept while tiles are rebuilt by a search

var _title: Label
var _selection: Label
var _detail: Label
var _message: Label
var _search: LineEdit
var _list: VBoxContainer
var _entries: Array[Dictionary] = []


func _ready() -> void:
	layer = 46
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = preload("res://scenes/ui/menu_theme.tres")
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.add_child(_crosshair())
	root.add_child(_corner())
	var hints := Label.new()
	hints.theme_type_variation = "HintLabel"
	hints.text = HINTS
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hints.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hints.offset_left = 16.0
	hints.offset_right = -16.0
	hints.offset_top = -30.0
	hints.offset_bottom = -6.0
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hints)
	browser = _browser()
	root.add_child(browser)


## A full-screen drawing under the panels (the selection box and markers, build_gizmo.gd).
func add_overlay(c: Control) -> void:
	var root := get_child(0)
	root.add_child(c)
	root.move_child(c, 0)


## The corner panel's lines. `locked` paints the detail red (a story node).
func show_selection(title: String, detail: String, locked := false) -> void:
	_selection.text = title
	_detail.text = detail
	_detail.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if locked else MenuFx.DIM)


func say(text: String) -> void:
	_message.text = text


func set_status(snap: bool, undo_count: int, file: String) -> void:
	_title.text = "BUILD MODE   snap %s   undo %d%s" % ["on" if snap else "off", undo_count,
			("   " + file) if file != "" else ""]


## True when the mouse is over a panel (clicks there aren't picks in the level).
func mouse_over_panel() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


## True while the search box has the keyboard (the fly keys type letters instead).
func typing() -> bool:
	return _search.has_focus()


func stop_typing() -> void:
	_search.release_focus()


func toggle_browser() -> void:
	browser.visible = not browser.visible
	if not browser.visible:
		stop_typing()


## Fills the browser with catalog entries (build_catalog.gd), grouped.
func fill(entries: Array[Dictionary]) -> void:
	_entries = entries
	_refill()


func _refill() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	tiles.clear()
	var needle := _search.text.strip_edges().to_lower()
	var group := ""
	var grid: GridContainer
	for entry: Dictionary in _entries:
		var label: String = entry.label
		if needle != "" and not label.to_lower().contains(needle) and not str(entry.group).to_lower().contains(needle):
			continue
		if entry.group != group:
			group = entry.group
			var head := Label.new()
			head.text = group.to_upper()
			head.theme_type_variation = "HeaderLabel"
			_list.add_child(head)
			grid = GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 3)
			grid.add_theme_constant_override("v_separation", 3)
			_list.add_child(grid)
		grid.add_child(_tile(entry))


## A tile's name in `tiles` and `icons` (two groups can each have a "Balcony").
static func key_of(entry: Dictionary) -> String:
	return "%s/%s" % [entry.group, entry.label]


## A picture for a tile (build_thumbs.gd calls this as each one is ready).
func set_icon(key: String, tex: Texture2D) -> void:
	icons[key] = tex
	var tile: Button = tiles.get(key)
	if tile:
		tile.icon = tex


func _tile(entry: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.text = entry.label
	b.tooltip_text = "%s\n%s" % [entry.label, entry.get("scene", entry.get("script", ""))]
	b.clip_text = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = false
	b.add_theme_font_size_override("font_size", 8)
	b.focus_mode = Control.FOCUS_NONE
	b.icon = icons.get(key_of(entry), _placeholder(GROUP_TINT.get(entry.group, Color(0.6, 0.78, 0.5))))
	b.pressed.connect(func() -> void: asset_chosen.emit(entry))
	tiles[key_of(entry)] = b
	return b


static var _placeholders := {}


static func _placeholder(tint: Color) -> Texture2D:
	if _placeholders.has(tint):
		return _placeholders[tint]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(tint, 0.18))
	for i in 64:  # a thin frame
		for p: Vector2i in [Vector2i(i, 0), Vector2i(i, 63), Vector2i(0, i), Vector2i(63, i)]:
			img.set_pixelv(p, Color(tint, 0.8))
	var tex := ImageTexture.create_from_image(img)
	_placeholders[tint] = tex
	return tex


func _crosshair() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var col := Color(1, 0.9, 0.7, 0.85)
		c.draw_line(Vector2(-6, 0), Vector2(-2, 0), col)
		c.draw_line(Vector2(2, 0), Vector2(6, 0), col)
		c.draw_line(Vector2(0, -6), Vector2(0, -2), col)
		c.draw_line(Vector2(0, 2), Vector2(0, 6), col))
	return c


func _corner() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 12)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	_title = _line(box, "HeaderLabel")
	_selection = _line(box, "")
	_selection.add_theme_color_override("font_color", MenuFx.BRIGHT)
	_detail = _line(box, "HintLabel")
	_message = _line(box, "HintLabel")
	_message.add_theme_color_override("font_color", Color(MenuFx.ACCENT, 0.9))
	return panel


func _line(parent: Control, variation: String) -> Label:
	var l := Label.new()
	if variation != "":
		l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", 10 if variation == "" else 9)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 290
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _browser() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -312.0
	panel.offset_right = -10.0
	panel.offset_top = 12.0
	panel.offset_bottom = -38.0
	panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := Label.new()
	head.text = "ASSETS"
	head.theme_type_variation = "HeaderLabel"
	box.add_child(head)
	_search = LineEdit.new()
	_search.placeholder_text = "search"
	_search.add_theme_font_size_override("font_size", 10)
	_search.text_changed.connect(func(_t: String) -> void: _refill())
	box.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	return panel
