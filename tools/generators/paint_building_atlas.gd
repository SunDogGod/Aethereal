extends SceneTree
# Paints the building atlas (textures/building_atlas.png + _glow) and its mostly-dark skyline
# twin (building_atlas_unlit.png + _glow). Tile layout comes from scripts/building_faces.gd.
# Round 8: columns 16-19 are the megastructure bays (_dense): tiny slit windows, a few lit.
# Clean flat painting on purpose: broad tones, crisp 1 px lines, no noise.
# Run: godot --headless --path PROJ -s this.gd, then --import.

const BF := preload("res://scripts/building_faces.gd")
const T := BF.TILE

# Tones.
const WALL := Color(0.52, 0.51, 0.56)
const WALL_LIGHT := Color(0.6, 0.59, 0.62)
const SLAB := Color(0.6, 0.59, 0.62)
const SLAB_TOP := Color(0.68, 0.67, 0.7)
const LINE := Color(0.3, 0.3, 0.34)
const FRAME := Color(0.2, 0.2, 0.23)
const SILL := Color(0.66, 0.64, 0.65)
const BASE := Color(0.44, 0.43, 0.46)
const BASE_FOOT := Color(0.36, 0.35, 0.38)
const CORNICE := Color(0.62, 0.61, 0.64)
const METAL := Color(0.3, 0.32, 0.4)
const METAL_LIGHT := Color(0.42, 0.44, 0.52)
const ROOF := Color(0.41, 0.41, 0.44)
const ROOF_SEAM := Color(0.34, 0.34, 0.37)
const DENSE_WALL := Color(0.36, 0.36, 0.41)
const DENSE_GLASS := Color(0.25, 0.26, 0.32)
# Window states: 0 dark, 1 warm, 2 TV blue, 3 dim warm, 4 curtain.
const GLASS := [Color(0.15, 0.17, 0.24), Color(0.9, 0.72, 0.42), Color(0.35, 0.75, 0.85), Color(0.58, 0.42, 0.27), Color(0.6, 0.55, 0.5)]
const LIGHT := [Color.BLACK, Color(1.0, 0.75, 0.4), Color(0.3, 0.7, 0.85), Color(0.5, 0.32, 0.18), Color(0.3, 0.26, 0.22)]
# Per window column (in the order of BF.WINDOW_COLS: 1..7, then 13..15, added in round 5):
# [state in row 0 (upper storey), state in row 1 (lower storey)].
const STATES_LIT := [[1, 0], [0, 2], [4, 3], [0, 0], [2, 4], [0, 1], [1, 1], [1, 0], [0, 1], [4, 0]]
const STATES_UNLIT := [[0, 0], [0, 3], [0, 0], [0, 0], [0, 0], [3, 0], [0, 0], [0, 0], [0, 3], [0, 0]]

var img: Image
var glow: Image


func _initialize() -> void:
	_atlas("building_atlas", STATES_LIT, 0.0)  # batch 9: no tiny lights on the town's own towers
	_atlas("building_atlas_unlit", STATES_UNLIT, 0.03)
	print("building atlas painted")
	quit()


func _atlas(name: String, states: Array, dense_lit: float) -> void:
	img = Image.create(BF.ATLAS_W, BF.ATLAS_H, false, Image.FORMAT_RGB8)
	glow = Image.create(BF.ATLAS_W, BF.ATLAS_H, false, Image.FORMAT_RGB8)
	img.fill(WALL)
	glow.fill(Color.BLACK)
	for i in BF.WINDOW_COLS.size():
		var col: int = BF.WINDOW_COLS[i]
		var pair: Array = states[i]
		_window(col, 0, pair[0])
		_window(col, 1, pair[1])
	for i in BF.DENSE_COLS.size():
		_dense(BF.DENSE_COLS[i], 0, i, dense_lit)
		_dense(BF.DENSE_COLS[i], 1, i + 7, dense_lit)
	_base_blank(BF.COL_BASE_BLANK, 1, false)
	_base_blank(BF.COL_BASE_BLANK, 0, true)
	_door(BF.COL_DOOR, 1, false)
	_door(BF.COL_DOOR, 0, true)
	_shop(BF.COL_SHOP, 1, false)
	_shop(BF.COL_SHOP, 0, true)
	_roof(BF.COL_ROOF, 0)
	_roof(BF.COL_ROOF, 1)
	_parapet(BF.COL_PARAPET)
	img.save_png("res://textures/%s.png" % name)
	glow.save_png("res://textures/%s_glow.png" % name)


# ------------------------------------------------------------------ helpers (tile-local coords)

func _rect(ox: int, oy: int, x0: int, y0: int, x1: int, y1: int, c: Color, lit := Color.BLACK) -> void:
	img.fill_rect(Rect2i(ox + x0, oy + y0, x1 - x0, y1 - y0), c)
	if lit != Color.BLACK:
		glow.fill_rect(Rect2i(ox + x0, oy + y0, x1 - x0, y1 - y0), lit)


func _origin(col: int, row: int) -> Vector2i:
	return Vector2i(col * T, row * T)


# ------------------------------------------------------------------ tiles

## One storey: wall, a two-by-two window with a sill, and the floor slab along the bottom.
func _window(col: int, row: int, state: int) -> void:
	var o := _origin(col, row)
	_rect(o.x, o.y, 0, 0, T, T, WALL)
	# The slab: lit top edge, body, shadow line underneath.
	_rect(o.x, o.y, 0, 56, T, 57, SLAB_TOP)
	_rect(o.x, o.y, 0, 57, T, 63, SLAB)
	_rect(o.x, o.y, 0, 63, T, 64, LINE)
	# Frame, glass, mullion and transom.
	_rect(o.x, o.y, 13, 9, 51, 43, FRAME)
	var glass: Color = GLASS[state]
	var light: Color = LIGHT[state]
	_rect(o.x, o.y, 14, 10, 50, 42, glass, light)
	if state == 0:
		_rect(o.x, o.y, 14, 10, 24, 18, Color(0.2, 0.23, 0.31))  # a glint in the top-left pane
	if state == 4:
		for k in range(16, 50, 4):  # curtain folds
			_rect(o.x, o.y, k, 10, k + 1, 42, glass * 0.8, light * 0.6)
	_rect(o.x, o.y, 31, 10, 33, 42, FRAME)
	_rect(o.x, o.y, 14, 25, 50, 26, FRAME)
	_rect(o.x, o.y, 12, 43, 52, 45, SILL)


## Ground-floor wall: a cornice along the top, a darker foot; optionally a vent box.
func _base_blank(col: int, row: int, vent: bool) -> void:
	var o := _origin(col, row)
	_rect(o.x, o.y, 0, 0, T, T, BASE)
	_rect(o.x, o.y, 0, 0, T, 2, CORNICE)
	_rect(o.x, o.y, 0, 2, T, 5, WALL_LIGHT)
	_rect(o.x, o.y, 0, 5, T, 6, LINE)
	_rect(o.x, o.y, 0, 60, T, 64, BASE_FOOT)
	if vent:
		_rect(o.x, o.y, 40, 30, 58, 44, Color(0.38, 0.39, 0.42))
		_rect(o.x, o.y, 40, 30, 58, 31, Color(0.5, 0.51, 0.54))
		for k in range(33, 43, 3):
			_rect(o.x, o.y, 42, k, 56, k + 1, Color(0.22, 0.22, 0.25))


## A metal door with a frame; row 1 narrow with a lamp above, row 0 a wider pair with a number plate.
func _door(col: int, row: int, wide: bool) -> void:
	_base_blank(col, row, false)
	var o := _origin(col, row)
	var x0 := 16 if wide else 22
	var x1 := 48 if wide else 42
	_rect(o.x, o.y, x0 - 1, 17, x1 + 1, 62, FRAME)
	var leaf := Color(0.36, 0.27, 0.26) if wide else METAL
	_rect(o.x, o.y, x0 + 1, 19, x1 - 1, 62, leaf)
	_rect(o.x, o.y, x0 + 1, 19, x0 + 2, 62, leaf.lightened(0.25))  # the lit edge
	_rect(o.x, o.y, x0 + 1, 40, x1 - 1, 41, leaf.darkened(0.35))  # a panel line
	if wide:
		_rect(o.x, o.y, 31, 19, 33, 62, FRAME)  # the meeting of the two leaves
		_rect(o.x, o.y, 28, 44, 30, 47, Color(0.7, 0.68, 0.6))
		_rect(o.x, o.y, 34, 44, 36, 47, Color(0.7, 0.68, 0.6))
		_rect(o.x, o.y, 50, 22, 57, 27, Color(0.75, 0.74, 0.7))  # the number plate
	else:
		_rect(o.x, o.y, 38, 42, 40, 44, Color(0.7, 0.68, 0.6))  # the handle
		_rect(o.x, o.y, 29, 14, 35, 15, Color(0.28, 0.28, 0.3))  # the bracket
		_rect(o.x, o.y, 29, 11, 35, 14, Color(0.95, 0.9, 0.75), Color(0.7, 0.6, 0.4))  # the lamp
	_rect(o.x, o.y, x0 - 2, 62, x1 + 2, 64, Color(0.5, 0.49, 0.51))  # the step


## A shopfront: shutter down (row 1) or dark glass under a sign plate (row 0).
func _shop(col: int, row: int, glass: bool) -> void:
	_base_blank(col, row, false)
	var o := _origin(col, row)
	if glass:
		_rect(o.x, o.y, 4, 8, 60, 19, Color(0.16, 0.3, 0.34), Color(0.1, 0.22, 0.26))  # the sign plate
		_rect(o.x, o.y, 4, 8, 60, 9, Color(0.3, 0.5, 0.55))
		_rect(o.x, o.y, 4, 18, 60, 19, Color(0.1, 0.18, 0.2))
		for s in [[10, 12, 22, 14], [12, 15, 20, 16], [28, 11, 31, 16], [36, 12, 52, 14], [40, 15, 48, 16]]:
			_rect(o.x, o.y, s[0], s[1], s[2], s[3], Color(0.55, 0.85, 0.9), Color(0.35, 0.6, 0.65))
		_rect(o.x, o.y, 4, 20, 60, 62, FRAME)
		_rect(o.x, o.y, 5, 21, 59, 61, Color(0.1, 0.12, 0.18))
		_rect(o.x, o.y, 31, 21, 33, 61, FRAME)  # the mullion
		_rect(o.x, o.y, 5, 21, 17, 32, Color(0.14, 0.17, 0.24))  # a glint
	else:
		_rect(o.x, o.y, 4, 8, 60, 13, Color(0.34, 0.35, 0.38))  # the shutter housing
		_rect(o.x, o.y, 4, 8, 60, 9, Color(0.46, 0.47, 0.5))
		_rect(o.x, o.y, 5, 13, 59, 62, Color(0.46, 0.47, 0.52))
		for k in range(16, 62, 4):
			_rect(o.x, o.y, 5, k, 59, k + 1, Color(0.36, 0.37, 0.41))
		_rect(o.x, o.y, 4, 13, 5, 62, FRAME)
		_rect(o.x, o.y, 59, 13, 60, 62, FRAME)
	_rect(o.x, o.y, 2, 62, 62, 64, Color(0.5, 0.49, 0.51))  # the step


## Roof concrete: flat with one seam each way (the same in both rows, so it repeats).
func _roof(col: int, row: int) -> void:
	var o := _origin(col, row)
	_rect(o.x, o.y, 0, 0, T, T, ROOF)
	_rect(o.x, o.y, 0, 31, T, 32, ROOF_SEAM)
	_rect(o.x, o.y, 32, 0, 33, T, ROOF_SEAM)
	_rect(o.x, o.y, 0, 32, T, 33, ROOF.lightened(0.06))
	_rect(o.x, o.y, 33, 0, 34, T, ROOF.lightened(0.06))


## The parapet strip: the top PARAPET_PX rows of row 0 (a lit cap, the body, a shadow line).
func _parapet(col: int) -> void:
	var o := _origin(col, 0)
	_rect(o.x, o.y, 0, 0, T, 1, Color(0.68, 0.67, 0.7))
	_rect(o.x, o.y, 0, 1, T, 3, CORNICE)
	_rect(o.x, o.y, 0, 3, T, 11, Color(0.5, 0.49, 0.53))
	_rect(o.x, o.y, 0, 11, T, 12, LINE)
	_rect(o.x, o.y, 0, 12, T, BF.PARAPET_PX, Color(0.45, 0.44, 0.48))


## Round 8, megastructure scale (Blame!): one storey cut into three 1 m micro-floors, each with a
## row of eight tiny slits (3 x 6 px, about 0.15 x 0.3 m), dark glass barely darker than the wall
## so it reads as texture, and a few lit (`lit` = the chance per slit). Variant 3 swaps the middle
## micro-floor for a louvred service band. Seeded, so re-running paints the same tiles.
func _dense(col: int, row: int, variant: int, lit: float) -> void:
	var o := _origin(col, row)
	var r := RandomNumberGenerator.new()
	r.seed = 8000 + col * 31 + row * 7 + int(lit * 1000.0)
	_rect(o.x, o.y, 0, 0, T, T, DENSE_WALL)
	for f in 3:
		var y0: int = f * 21
		_rect(o.x, o.y, 0, y0 + 20, T, y0 + 21, LINE)  # the micro-floor's slab line
		_rect(o.x, o.y, 0, y0 + 19, T, y0 + 20, DENSE_WALL.lightened(0.08))
		if variant == 3 and f == 1:
			for k in range(y0 + 6, y0 + 16, 3):
				_rect(o.x, o.y, 2, k, T - 2, k + 1, DENSE_WALL.darkened(0.25))
			continue
		for k in 8:
			var x: int = 2 + k * 8
			if r.randf() < lit:
				var warm := r.randf() < 0.6
				var c := Color(1.0, 0.82, 0.55) if warm else Color(0.72, 0.86, 1.0)
				_rect(o.x, o.y, x, y0 + 7, x + 3, y0 + 13, c, c * 0.9)
			else:
				_rect(o.x, o.y, x, y0 + 7, x + 3, y0 + 13, DENSE_GLASS)
