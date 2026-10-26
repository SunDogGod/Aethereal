class_name BuildingFaces
extends RefCounted
## Builds a Block's faces in BUILDING style: real building fronts instead of one window texture
## projected over everything. Every side face is cut into a base course at street level (doors,
## shopfronts, plain plinth), window bays with a plain pier at both corners (no window ever
## touches a corner), a floor slab under every storey (painted into the window tile) and a
## parapet along the top. Roofs and undersides are plain concrete. Faces too small for bays are
## plain wall. Everything maps into textures/building_atlas.png with the mesh's own UVs.
##
## The faces look at what stands around them (building_context.gd), like a real building would:
## doors and shopfronts only where a floor runs right in front at their foot (never facing a
## drop, never hanging over a roof or under a slab); a face with no floor in front gets no ground
## floor at all; a courtyard or deck running along a face partway up puts the ground floor there;
## no window where something solid stands within 1.5 m in front of it.
## Set the Block's metadata "faces_context" to false to switch that off for one block.
##
## Megastructure scale (Blame!): storeys whose bottom is above the Block's metadata
## "faces_dense_above" (world metres) use the DENSE_COLS tiles instead: dark wall with rows of tiny
## slit windows, a few lit, so the upper floors read as a vast structure. Without it: unchanged.
##
## THE ATLAS (1280 x 128): 20 columns of 64 px, 2 rows of 64 px. One column is one 3 m bay.
## A window column holds two storeys (row 0 sits above row 1) and repeats vertically, so a whole
## stack of storeys is one quad whose v runs past 1. The painter (scratchpad
## paint_building_atlas.gd) reads these constants, so the mesh and the paint always agree.
const ATLAS_W := 1280
const ATLAS_H := 128
const TILE := 64
const COL_BLANK := 0  # plain wall in both rows: corner piers, margins, small faces
const WINDOW_COLS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 13, 14, 15]  # window bays, two looks each
const COL_BASE_BLANK := 8  # ground-floor wall: row 1 plain, row 0 with a vent box
const COL_DOOR := 9  # row 1 a metal door with a lamp, row 0 a wider second door
const COL_SHOP := 10  # row 1 shutter down, row 0 dark glass under a sign plate
const COL_ROOF := 11  # roof concrete in both rows (repeats vertically)
const COL_PARAPET := 12  # the top PARAPET_PX pixels of row 0 are the parapet strip
const PARAPET_PX := 13
const DENSE_COLS: Array[int] = [16, 17, 18, 19]  # megastructure bays: tiny slit windows, few lit
# Metres.
const BAY := 3.0
const STOREY := 3.0
const BASE_H := 3.2
const PARAPET_H := 0.6
const MARGIN_MIN := 1.0
const MIN_FACE_W := 5.0
const MIN_FACE_H := 4.0
const ROOF_SPLIT := 6.0
const Context := preload("res://scripts/building_context.gd")

## Set before build() to get a list of what went where (used by placement and audit scripts):
## {face, kind ("window"/"blank"/"door"/"shop"/"plinth"), u0, u1, y0, y1, col}, in face metres.
var record := false
var cells: Array = []

var _st: SurfaceTool
var _block  # the Block being built (untyped: block.gd calls this class, so no circular typing)
var _ctx: Context  # null when the block isn't in a scene yet (or faces_context is off)
var _face := ""
var _n: Vector3
var _u_axis: Vector3
var _v_axis: Vector3
var _origin: Vector3
var _seed: int


func _init(st: SurfaceTool, block) -> void:
	_st = st
	_block = block


func build() -> void:
	if _block.is_inside_tree() and _block.get_meta("faces_context", true):
		_ctx = Context.new(_block)
	var h: Vector3 = _block.size * 0.5
	_face = "front"
	_side(Vector3(0, 0, 1), Vector3(1, 0, 0), h)
	_face = "back"
	_side(Vector3(0, 0, -1), Vector3(-1, 0, 0), h)
	_face = "right"
	_side(Vector3(1, 0, 0), Vector3(0, 0, -1), h)
	_face = "left"
	_side(Vector3(-1, 0, 0), Vector3(0, 0, 1), h)
	_flat(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), h)  # roof
	_flat(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), h)  # underside


# ------------------------------------------------------------------ atlas lookups

## u in the atlas for column `col` at fraction `f` (0..1) across its tile, a texel in from the
## sides so neighbouring tiles don't bleed in at a distance.
static func _u(col: int, f: float) -> float:
	return (col * TILE + 1.0 + f * (TILE - 2.0)) / ATLAS_W


## v in the atlas `storeys_up` storeys above the bottom of row 1 (the bottom row). Storey 0
## reads row 1, storey 1 reads row 0, storey 2 wraps around to row 1 again.
static func _v(storeys_up: float) -> float:
	return 1.0 - storeys_up * 0.5


## A repeatable 0..1 number for this face, bay `i` and storey `j`.
func _rnd(i: int, j: int) -> float:
	return fmod(absf(sin(float(_seed + i * 131 + j * 977)) * 43758.5453), 1.0)


func _window_col(i: int, j: int) -> int:
	return WINDOW_COLS[int(_rnd(i, j) * WINDOW_COLS.size())]


# ------------------------------------------------------------------ faces

## Sets up the frame of one face: its normal, the axis along it (u), the axis up it (v) and the
## bottom-left corner. Returns the face's (width, height). The seed makes each face of each
## block pick its own doors and lit windows.
func _start(n: Vector3, u_axis: Vector3, v_axis: Vector3, h: Vector3) -> Vector2:
	_n = n
	_u_axis = u_axis
	_v_axis = v_axis
	var w: float = (h * u_axis.abs()).length() * 2.0
	var ht: float = (h * v_axis.abs()).length() * 2.0
	_origin = n * (h * n.abs()).length() - u_axis * w * 0.5 - v_axis * ht * 0.5
	var p: Vector3 = _block.position
	_seed = int(absf(p.x * 3.7 + p.y * 11.3 + p.z * 5.1 + n.x * 17.0 + n.z * 29.0 + n.y * 41.0 + w * 1.3 + ht * 0.7) * 10.0)
	if _ctx and absf(n.y) < 0.5:
		_ctx.set_face(_origin, u_axis, n)
	return Vector2(w, ht)


func _side(n: Vector3, u_axis: Vector3, h: Vector3) -> void:
	var wh := _start(n, u_axis, Vector3.UP, h)
	var w := wh.x
	var ht := wh.y
	if w <= 0.0 or ht <= 0.0:
		return
	if w < MIN_FACE_W or ht < MIN_FACE_H:
		_blank(0.0, w, 0.0, ht)
		return
	var bays := floori((w - 2.0 * MARGIN_MIN) / BAY)
	var margin := (w - bays * BAY) * 0.5
	# Where the ground floor goes: at the bottom (ground_floor), at a street that runs along the
	# face partway up, or nowhere (no floor in front at all: windows from the bottom).
	var base := 0.0 if _block.ground_floor else -1.0
	if _ctx:
		if base == 0.0 and not _ctx.any_floor(bays, margin, BAY, 0.0):
			base = -1.0
		if base < 0.0:
			var s := _ctx.street(w, ht)
			if not is_nan(s):
				base = s
	var y := 0.0
	if base > 0.0:
		# Below a street: storeys on the same grid, going down. Those behind the street's own
		# floor (or a lower roof) come out plain; the rest still look out.
		var below := mini(floori(base / STOREY), 5)  # deeper than 15 m: out of sight, plain
		_blank(0.0, w, 0.0, base - below * STOREY)
		if below > 0:
			_storeys(bays, margin, w, base - below * STOREY, below, STOREY)
	if base >= 0.0:
		_base_course(bays, margin, w, base, base == 0.0)
		y = base + BASE_H
	var room := ht - y - PARAPET_H
	var storeys := floori(room / STOREY)
	var storey_h := STOREY
	var band := room - storeys * STOREY
	if storeys > 0 and band < 0.5:
		storey_h = room / storeys  # slightly taller storeys instead of a sliver of blank wall
		band = 0.0
	if band > 0.0:
		_blank(0.0, w, y, y + band)  # a plain service band above the shops
		y += band
	# Storeys above faces_dense_above (world height) switch to the megastructure tiles.
	var plain := storeys
	if _block.has_meta("faces_dense_above"):
		var bottom: float = (_block.global_position.y if _block.is_inside_tree() else _block.position.y) - ht * 0.5
		plain = clampi(ceili((float(_block.get_meta("faces_dense_above")) - bottom - y) / storey_h), 0, storeys)
	if plain > 0:
		_storeys(bays, margin, w, y, plain, storey_h)
	if storeys > plain:
		_storeys(bays, margin, w, y + plain * storey_h, storeys - plain, storey_h, true)
	y += storeys * storey_h
	_parapet(w, y, ht)


## Ground floor: a door every third bay, shopfronts and plain plinth between, plain at the
## corners. Doors and shops only with floor to step onto in front (a shop not onto another
## building's roof, unless this is the block's own ground floor); a bay with nothing in front
## at all gets a window instead. Split at grime_height so the vertex grime fades like a Block's.
func _base_course(bays: int, margin: float, w: float, y0: float, own_ground: bool) -> void:
	var split: float = clampf(_block.grime_height, 0.4, BASE_H - 0.4)
	_base_tile(COL_BASE_BLANK, 1, 0.0, margin, y0, 0.0, margin / BAY, split)
	_base_tile(COL_BASE_BLANK, 1, w - margin, w, y0, 0.0, margin / BAY, split)
	var offset := int(_rnd(0, 0) * 3.0)
	for i in bays:
		var x := margin + i * BAY
		var col := COL_BASE_BLANK
		var row := 1
		var r := _rnd(i + 1, 1)
		if bays == 1:
			col = COL_DOOR if r < 0.5 else COL_SHOP
		elif (i + offset) % 3 == 1:
			col = COL_DOOR
			row = 1 if r < 0.6 else 0
		elif r < 0.55:
			col = COL_SHOP
			row = 1 if r < 0.3 else 0
		elif r < 0.75:
			row = 0  # plinth with a vent box
		if _ctx:
			var fl := _ctx.can_enter(x + BAY * 0.5, y0)
			if fl == Context.NO_FLOOR and _ctx.blocked_run(x, BAY, y0, 1, BASE_H).is_empty():
				var wc := _window_col(i + 7, 2)  # open air in front: a window, not a door
				_quad(x, x + BAY, y0, y0 + BASE_H, _u(wc, 0.0), _u(wc, 1.0), _v(0), _v(1))
				_note("window", x, x + BAY, y0, y0 + BASE_H, wc)
				continue
			if fl == Context.NO_FLOOR or fl == Context.BLOCKED or (col == COL_SHOP and fl == Context.ROOF and not own_ground):
				col = COL_BASE_BLANK
		_base_tile(col, row, x, x + BAY, y0, 0.0, 1.0, split)
		_note({COL_DOOR: "door", COL_SHOP: "shop"}.get(col, "plinth"), x, x + BAY, y0, y0 + BASE_H, col)


func _base_tile(col: int, row: int, u0: float, u1: float, y0: float, f0: float, f1: float, split: float) -> void:
	var vb := 1.0 if row == 1 else 0.5
	var vs := vb - 0.5 * split / BASE_H
	_quad(u0, u1, y0, y0 + split, _u(col, f0), _u(col, f1), vb, vs)
	_quad(u0, u1, y0 + split, y0 + BASE_H, _u(col, f0), _u(col, f1), vs, vb - 0.5)


## Window bays in vertical runs of a few storeys each; every run picks its own lit pattern.
## A run with a blocked window in it is laid storey by storey, with plain wall where blocked.
func _storeys(bays: int, margin: float, w: float, y0: float, storeys: int, storey_h: float, dense := false) -> void:
	var seg := maxi(3, ceili(storeys / 12.0))
	var s := 0
	while s < storeys:
		var count := mini(seg, storeys - s)
		var ya := y0 + s * storey_h
		var yb := ya + count * storey_h
		var vb := _v(s)
		var vt := _v(s + count)
		# Plain piers at both corners (the blank tile has no features, so any v works).
		_quad(0.0, margin, ya, yb, _u(COL_BLANK, 0.0), _u(COL_BLANK, margin / BAY), vb, vt)
		_quad(w - margin, w, ya, yb, _u(COL_BLANK, 0.0), _u(COL_BLANK, margin / BAY), vb, vt)
		for i in bays:
			var col := _window_col(i + 7, s + 3)
			if dense:
				col = DENSE_COLS[int(_rnd(i + 3, s + 5) * DENSE_COLS.size())]
			var x := margin + i * BAY
			var blocked: Array[int] = []
			if _ctx:
				blocked = _ctx.blocked_run(x, BAY, ya, count, storey_h)
			if blocked.is_empty():
				_quad(x, x + BAY, ya, yb, _u(col, 0.0), _u(col, 1.0), vb, vt)
				for k in count:
					_note("window", x, x + BAY, ya + k * storey_h, ya + (k + 1) * storey_h, col)
				continue
			for k in count:
				var c := COL_BLANK if blocked.has(k) else col
				var y := ya + k * storey_h
				_quad(x, x + BAY, y, y + storey_h, _u(c, 0.0), _u(c, 1.0), _v(s + k), _v(s + k + 1))
				_note("blank" if c == COL_BLANK else "window", x, x + BAY, y, y + storey_h, c)
		s += count


func _parapet(w: float, y0: float, y1: float) -> void:
	var vb := float(PARAPET_PX) / ATLAS_H
	var x := 0.0
	while x < w - 0.01:
		var x1 := minf(x + BAY, w)
		_quad(x, x1, y0, y1, _u(COL_PARAPET, 0.0), _u(COL_PARAPET, (x1 - x) / BAY), vb, 0.0)
		x = x1


## Plain wall in bay-wide quads (a few metres tall, so the warping stays tame).
func _blank(x0: float, x1: float, y0: float, y1: float) -> void:
	var step := maxf(STOREY, (y1 - y0) / 8.0)
	var x := x0
	while x < x1 - 0.01:
		var xa := minf(x + BAY, x1)
		var y := y0
		while y < y1 - 0.01:
			var ya := minf(y + step, y1)
			_quad(x, xa, y, ya, _u(COL_BLANK, 0.0), _u(COL_BLANK, (xa - x) / BAY), 1.0, _v((ya - y) / STOREY))
			y = ya
		x = xa


## Roof or underside: plain concrete in 3 m strips, the roof tile repeating along each strip.
func _flat(n: Vector3, u_axis: Vector3, v_axis: Vector3, h: Vector3) -> void:
	var wd := _start(n, u_axis, v_axis, h)
	if wd.x <= 0.0 or wd.y <= 0.0:
		return
	var step := maxf(ROOF_SPLIT, wd.y / 16.0)
	var x := 0.0
	while x < wd.x - 0.01:
		var xa := minf(x + BAY, wd.x)
		var y := 0.0
		while y < wd.y - 0.01:
			var ya := minf(y + step, wd.y)
			_quad(x, xa, y, ya, _u(COL_ROOF, 0.0), _u(COL_ROOF, (xa - x) / BAY), _v(y / BAY), _v(ya / BAY))
			y = ya
		x = xa


# ------------------------------------------------------------------ geometry

func _note(kind: String, u0: float, u1: float, y0: float, y1: float, col: int) -> void:
	if record:
		cells.append({face = _face, kind = kind, u0 = u0, u1 = u1, y0 = y0, y1 = y1, col = col})


func _pos(u: float, y: float) -> Vector3:
	return _origin + _u_axis * u + _v_axis * y


## One quad on the current face: u0..u1 along it, y0..y1 up it (metres from its bottom-left
## corner), mapped to atlas u au0..au1 and atlas v av_bottom (at y0) .. av_top (at y1).
func _quad(u0: float, u1: float, y0: float, y1: float, au0: float, au1: float, av_bottom: float, av_top: float) -> void:
	var p: Array[Vector3] = [_pos(u0, y0), _pos(u1, y0), _pos(u1, y1), _pos(u0, y1)]
	var uv: Array[Vector2] = [Vector2(au0, av_bottom), Vector2(au1, av_bottom), Vector2(au1, av_top), Vector2(au0, av_top)]
	var side: bool = absf(_n.y) < 0.5
	# Same winding rule as the plain Block: Godot's front faces are CLOCKWISE seen from outside.
	var tri_normal: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	var order: Array = [0, 2, 1, 0, 3, 2] if tri_normal.dot(_n) > 0.0 else [0, 1, 2, 0, 2, 3]
	for k in order:
		_st.set_normal(_n)
		_st.set_uv(uv[k])
		_st.set_color(_block._shade(p[k], side, _n))
		_st.add_vertex(p[k])
