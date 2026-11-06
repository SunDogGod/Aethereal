extends RefCounted
## The window storeys of one BUILDING face, split out of building_faces.gd (look round,
## 2026-11-05). Every third storey is unlit (which third varies per face, from the building's
## position), and each storey mixes in a few blank, cracked, boarded or dark bays, so no two
## floors match. It lays the quads through the BuildingFaces that owns the face.

var _f  # the BuildingFaces laying this face (untyped: it builds us, so no circular typing)


func _init(faces) -> void:
	_f = faces


## Window bays, storey by storey: each storey picks its own tile (see _col), and storeys that
## happen to pick the same one are merged into a single quad whose v runs on through the atlas's
## two rows. The corner piers are plain in runs of a few storeys.
func lay(bays: int, margin: float, w: float, y0: float, storeys: int, storey_h: float, dense: bool) -> void:
	var BAY: float = BuildingFaces.BAY
	var blank: int = BuildingFaces.COL_BLANK
	var seg := maxi(3, ceili(storeys / 12.0))
	var s := 0
	while s < storeys:
		var count := mini(seg, storeys - s)
		var ya := y0 + s * storey_h
		var yb := ya + count * storey_h
		# Plain piers at both corners (the blank tile has no features, so any v works).
		_f._quad(0.0, margin, ya, yb, _f._u(blank, 0.0), _f._u(blank, margin / BAY), _f._v(s), _f._v(s + count))
		_f._quad(w - margin, w, ya, yb, _f._u(blank, 0.0), _f._u(blank, margin / BAY), _f._v(s), _f._v(s + count))
		s += count
	var phase := int(_f._rnd(5, 11) * 3.0)  # which third of the storeys is unlit, per face
	for i in bays:
		var x := margin + i * BAY
		var blocked: Array[int] = []
		if _f._ctx:
			blocked = _f._ctx.blocked_run(x, BAY, y0, storeys, storey_h)
		var cols: Array[int] = []
		for k in storeys:
			cols.append(blank if blocked.has(k) else _col(i, k, phase, dense))
		var k := 0
		while k < storeys:
			var c: int = cols[k]
			var e := k + 1
			while e < storeys and cols[e] == c:
				e += 1
			_f._quad(x, x + BAY, y0 + k * storey_h, y0 + e * storey_h, _f._u(c, 0.0), _f._u(c, 1.0), _f._v(k), _f._v(e))
			for j in range(k, e):
				_f._note("blank" if c == blank else "window", x, x + BAY, y0 + j * storey_h, y0 + (j + 1) * storey_h, c)
			k = e


## The tile for bay `i`, storey `k` (0 = the lowest of this run). Every third storey is unlit:
## dark glass, with a boarded, cracked or blank bay here and there. A lit storey is mostly lit
## windows with a few blank, cracked, boarded or dark bays mixed in. Dense (megastructure)
## storeys keep their slit tiles. Storey k reads atlas row 1 when k is even and row 0 when odd,
## so the cracked column's dark row only lands on even storeys of an unlit floor.
func _col(i: int, k: int, phase: int, dense: bool) -> int:
	if dense:
		return BuildingFaces.DENSE_COLS[int(_f._rnd(i + 3, k + 5) * BuildingFaces.DENSE_COLS.size())]
	var r: float = _f._rnd(i + 7, k + 3)
	var dark: int = BuildingFaces.DARK_COLS[int(_f._rnd(i + 11, k + 13) * BuildingFaces.DARK_COLS.size())]
	if (k + phase) % 3 == 0:
		if r < 0.1:
			return BuildingFaces.COL_BLANK
		if r < 0.22:
			return BuildingFaces.COL_BOARDED
		if r < 0.32 and k % 2 == 0:
			return BuildingFaces.COL_CRACKED
		return dark
	if r < 0.06:
		return BuildingFaces.COL_BLANK
	if r < 0.13:
		return BuildingFaces.COL_CRACKED
	if r < 0.18:
		return BuildingFaces.COL_BOARDED
	if r < 0.26:
		return dark
	return BuildingFaces.WINDOW_COLS[int(_f._rnd(i + 17, k + 19) * BuildingFaces.WINDOW_COLS.size())]
