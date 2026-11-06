extends SceneTree
# Round 4 (worn town): paints the WORN building atlases from the clean ones. Reads
# textures/building_atlas(.png, _glow.png) and building_atlas_unlit(...), written by
# paint_building_atlas.gd, and writes building_atlas_worn* and building_atlas_unlit_worn*.
# Re-running is safe: it always starts from the clean files. Same tile layout (see
# scripts/building_faces.gd), so materials/building_worn.tres is a drop-in for building.tres.
# Wear: dirty water streaks under every sill and slab, long streaks down the plain piers, rust
# from the metal frames, doors and shutters, chipped slabs, damp at the foot of the base course,
# stains and a repair on the roof tile (the rim and deck floors), and broken or boarded windows
# mixed in with the lit ones (boards leak light where the room behind is lit).
# Look round (2026-11-05): the thin-line cracked overrides went (fine lines turn to noise at
# 960x540); the clean atlas now has fat-stroke cracked and boarded columns of its own, which
# get the same streaks as the window columns. The wear strokes live in r4_wear.gd.
# Run: godot --headless --path PROJ -s this.gd, then --import.

const Wear := preload("res://tools/generators/r4_wear.gd")
const BF := preload("res://scripts/building_faces.gd")
const T := 64
# [atlas column, row, kind, light leaking through the boards]
const OVERRIDES_LIT := [[4, 0, "broken", Color.BLACK], [4, 1, "boarded", Color.BLACK],
	[6, 0, "broken", Color.BLACK], [3, 1, "boarded", Color(0.55, 0.36, 0.2)]]
const OVERRIDES_UNLIT := [[1, 1, "boarded", Color.BLACK], [3, 0, "broken", Color.BLACK],
	[5, 0, "boarded", Color.BLACK], [5, 1, "broken", Color.BLACK], [7, 1, "broken", Color.BLACK], [6, 0, "boarded", Color(0.45, 0.3, 0.17)]]
const WOOD := Color(0.4, 0.35, 0.3)

var img: Image
var glow: Image
var w: Wear


func _initialize() -> void:
	_atlas("building_atlas", OVERRIDES_LIT, 11)
	_atlas("building_atlas_unlit", OVERRIDES_UNLIT, 23)
	print("worn atlases painted")
	quit()


func _load(name: String) -> Image:
	var i := Image.load_from_file(ProjectSettings.globalize_path("res://textures/%s.png" % name))
	i.convert(Image.FORMAT_RGB8)
	return i


func _atlas(name: String, overrides: Array, seed_value: int) -> void:
	img = _load(name)
	glow = _load(name + "_glow")
	w = Wear.new(seed_value)
	for o in overrides:
		if o[2] == "boarded":
			_boarded(o[0], o[1], o[3])
		else:
			_broken(o[0], o[1])
	var window_cols: Array[int] = BF.WINDOW_COLS.duplicate()
	window_cols.append_array(BF.DARK_COLS)
	window_cols.append_array([BF.COL_CRACKED, BF.COL_BOARDED])
	for i in window_cols.size():
		_wear_window_column(window_cols[i], seed_value * 7 + i)
	_wear_blank(seed_value)
	_wear_base(BF.COL_BASE_BLANK, seed_value)
	_wear_door(seed_value)
	_wear_shop(seed_value)
	_wear_roof(seed_value)
	_wear_parapet()
	Wear.quantise(img)
	img.save_png("res://textures/%s_worn.png" % name)
	glow.save_png("res://textures/%s_worn_glow.png" % name)


func _col(c: int) -> Rect2i:
	return Rect2i(c * T, 0, T, 2 * T)


func _tile(c: int, row: int) -> Rect2i:
	return Rect2i(c * T, row * T, T, T)


func _fill(r: Rect2i, x0: int, y0: int, x1: int, y1: int, c: Color, lit := Color.BLACK) -> void:
	img.fill_rect(Rect2i(r.position.x + x0, r.position.y + y0, x1 - x0, y1 - y0), c)
	glow.fill_rect(Rect2i(r.position.x + x0, r.position.y + y0, x1 - x0, y1 - y0), lit)


# ------------------------------------------------------------------ windows

## Planks nailed over the frame. The gaps show the dark room, or its light if `leak` is set.
func _boarded(c: int, row: int, leak: Color) -> void:
	var r := _tile(c, row)
	_fill(r, 14, 10, 50, 42, Color(0.07, 0.065, 0.07) if leak == Color.BLACK else leak * 0.9, leak)
	var ys := [11, 19, 28, 36]
	for k in ys.size():
		var y0: int = ys[k] + w.rng.randi_range(-1, 1)
		var tone := WOOD * w.rng.randf_range(0.82, 1.08)
		var x0 := 11 + w.rng.randi_range(0, 3)
		var x1 := 53 - w.rng.randi_range(0, 3)
		_fill(r, x0, y0, x1, y0 + 6, tone)
		_fill(r, x0, y0 + 5, x1, y0 + 6, tone * 0.7)  # shadowed lower edge
		_fill(r, x0, y0, x1, y0 + 1, tone.lightened(0.12))
		for nx in [x0 + 2, x1 - 3]:
			_fill(r, nx, y0 + 2, nx + 1, y0 + 3, Color(0.62, 0.6, 0.55))  # nails
	# One plank across them all, stepped diagonally.
	var tone2 := WOOD * 0.9
	for i in 36:
		var x := 15 + i
		var y := 39 - int(i * 0.8)
		_fill(r, x, y, x + 2, y + 4, tone2)


## Glass gone dark with a jagged hole punched in it and cracks running to the frame.
func _broken(c: int, row: int) -> void:
	var r := _tile(c, row)
	_fill(r, 14, 10, 50, 42, Color(0.11, 0.12, 0.16))
	_fill(r, 31, 10, 33, 42, Color(0.2, 0.2, 0.23))  # mullion stays
	_fill(r, 14, 25, 50, 26, Color(0.2, 0.2, 0.23))
	var centre := Vector2(22 + w.rng.randi_range(0, 18), 16 + w.rng.randi_range(0, 12))
	var radii: Array[float] = []
	for k in 9:
		radii.append(w.rng.randf_range(3.0, 9.0))
	for y in range(10, 42):
		for x in range(14, 50):
			var d := Vector2(x, y) - centre
			var a := fposmod(d.angle(), TAU) / TAU * 9.0
			var k0 := int(a) % 9
			var rad := lerpf(radii[k0], radii[(k0 + 1) % 9], a - floorf(a))
			if d.length() < rad:
				img.set_pixel(r.position.x + x, r.position.y + y, Color(0.03, 0.03, 0.04))
	for k in 4:  # glinting cracks out to the frame
		var ang := w.rng.randf() * TAU
		var p := centre
		for i in 30:
			p += Vector2(cos(ang), sin(ang))
			var q := Vector2i(int(p.x), int(p.y))
			if q.x < 14 or q.x >= 50 or q.y < 10 or q.y >= 42:
				break
			img.set_pixel(r.position.x + q.x, r.position.y + q.y, Color(0.3, 0.32, 0.38))


## Streaks under the sill and the slab (they wrap from the bottom storey into the top one),
## rust from the frame's lower corners, damp patches, chips along the slab.
func _wear_window_column(c: int, seed_value: int) -> void:
	var col := _col(c)
	for row in 2:
		var oy := row * T
		w.streaks(img, col, col.position.x + 13, col.position.x + 51, oy + 45, 4, 4, 11, 2, 4, "dark", 0.3)
		w.streaks(img, col, col.position.x + 2, col.position.x + 60, oy + 64, 3, 6, 22, 2, 5, "dark", 0.26, true)
		for fx in [13, 49]:
			if w.rng.randf() < 0.6:
				w.streak(img, col, col.position.x + fx, oy + 45, 2, w.rng.randi_range(5, 10), "rust", 0.45)
		w.chips(img, Rect2i(col.position.x, oy + 56, T, 7), 1, 2, 4, 0.4)
	var glass := [Rect2i(col.position.x + 13, 9, 38, 34), Rect2i(col.position.x + 13, 73, 38, 34)]
	w.blotch(img, col, 0.035, [0.35], "dark", 0.14, seed_value, 0.0, glass, 4)


# ------------------------------------------------------------------ plain and base tiles

## The plain wall (corner piers, margins, small faces): long streaks, one of rust, a damp
## stain, chips and one crack. Wraps vertically, as the piers repeat every two storeys.
func _wear_blank(seed_value: int) -> void:
	var col := _col(BF.COL_BLANK)
	w.streaks(img, col, 2, 60, 0, 5, 30, 90, 2, 6, "dark", 0.28, true)
	w.streak(img, col, 40, 70, 3, 40, "rust", 0.4, true)
	w.blotch(img, col, 0.035, [0.25], "dark", 0.15, seed_value + 1, 0.0, [], 4)
	w.chips(img, col, 2, 2, 4, 0.35)
	w.crack(img, col, 20, 10, 26, Vector2i(0, 1), 0.4)


## Ground-floor wall: damp creeping up in a stepped tide line, streaks from the cornice, rust
## under the vent box (row 0), chips.
func _wear_base(c: int, seed_value: int) -> void:
	for row in 2:
		var r := _tile(c, row)
		w.tide(img, r, 16, "dark", 0.3)
		w.blotch(img, Rect2i(r.position.x, r.position.y + 40, T, 24), 0.09, [0.2], "moss", 0.22, seed_value + row)
		w.streaks(img, r, r.position.x + 2, r.position.x + 60, r.position.y + 6, 3, 8, 20, 2, 4, "dark", 0.22)
		w.chips(img, Rect2i(r.position.x, r.position.y, T, 6), 2, 2, 3, 0.45)
	var vent := _tile(c, 0)
	w.streak(img, vent, vent.position.x + 43, vent.position.y + 44, 3, 14, "rust", 0.55)
	w.streak(img, vent, vent.position.x + 52, vent.position.y + 44, 2, 10, "rust", 0.45)
	w.blotch(img, Rect2i(vent.position.x + 40, vent.position.y + 30, 18, 14), 0.2, [0.1], "rust", 0.5, seed_value + 5)


func _wear_door(seed_value: int) -> void:
	_wear_base(BF.COL_DOOR, seed_value + 30)
	for row in 2:
		var r := _tile(BF.COL_DOOR, row)
		var x0 := 17 if row == 0 else 23
		var x1 := 47 if row == 0 else 41
		var leaf := Rect2i(r.position.x + x0, r.position.y + 19, x1 - x0, 43)
		w.blotch(img, leaf, 0.12, [0.15, 0.5], "rust", 0.5, seed_value + 40 + row, 0.6)
		w.tide(img, leaf, 6, "rust", 0.5)
		w.streak(img, r, r.position.x + (38 if row == 1 else 29), r.position.y + 44, 2, 12, "rust", 0.5)


## Shutters rusted from the bottom up, streaks from the housing, a dented slat; the glass
## shop gets a crack across one pane and a dead letter in its sign.
func _wear_shop(seed_value: int) -> void:
	_wear_base(BF.COL_SHOP, seed_value + 50)
	var s := _tile(BF.COL_SHOP, 1)
	var body := Rect2i(s.position.x + 5, s.position.y + 13, 54, 49)
	w.blotch(img, body, 0.09, [0.0, 0.45], "rust", 0.55, seed_value + 51, 0.7)
	w.streaks(img, s, s.position.x + 6, s.position.x + 58, s.position.y + 13, 4, 8, 26, 2, 4, "rust", 0.4)
	for k in range(36, 44):
		for x in range(20, 40):
			var px := s.position + Vector2i(x, k)
			img.set_pixel(px.x, px.y, img.get_pixel(px.x, px.y) * (0.82 if (k % 4) < 2 else 1.08))
	var g := _tile(BF.COL_SHOP, 0)
	var p := Vector2i(8, 24)
	for i in 26:  # a glinting crack across the left pane
		img.set_pixel(g.position.x + p.x, g.position.y + p.y, Color(0.32, 0.36, 0.42))
		p += Vector2i(1, 1 if i % 3 != 2 else 0)
		if p.x >= 31:
			break
	for y in range(15, 17):
		for x in range(40, 48):
			glow.set_pixel(g.position.x + x, g.position.y + y, Color.BLACK)
			img.set_pixel(g.position.x + x, g.position.y + y, Color(0.2, 0.3, 0.32))


## The roof tile is also the floor of the rim and the decks: flat stains in two tones and
## chipped seams. Seamless both ways. No cracks or repairs here: they would repeat every bay
## and read as a pattern; the town places those as decals instead.
func _wear_roof(seed_value: int) -> void:
	var col := _col(BF.COL_ROOF)
	w.blotch(img, col, 0.03, [0.15, 0.5], "dark", 0.18, seed_value + 60)
	w.chips(img, Rect2i(col.position.x, 28, T, 8), 2, 2, 3, 0.35)
	w.chips(img, Rect2i(col.position.x, 92, T, 8), 2, 2, 3, 0.35)


## The parapet strip is only 13 px tall: short drips under the cap.
func _wear_parapet() -> void:
	var r := Rect2i(BF.COL_PARAPET * T, 0, T, BF.PARAPET_PX)
	w.streaks(img, r, r.position.x, r.end.x - 3, 3, 5, 4, 9, 2, 3, "dark", 0.3)
