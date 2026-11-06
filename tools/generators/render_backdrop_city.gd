extends RefCounted
# The far city's geometry for render_backdrop.gd: towers of five kinds (set-back shafts,
# cylinders with collars and masts, tapering spires, buttressed masses, twins with a gantry),
# two hot sodium clusters, slabs floating in the haze, gantries and sagging cables between
# neighbours. Everything is a prism or a bar; the shader draws both sides, so winding is free.
# Vertex colour: r tone, g window density, b piece id, a kind (0 wall, 0.5 cool beacon, 1 lamp).

const BOTTOM := -2600.0

var rng := RandomNumberGenerator.new()
var st := SurfaceTool.new()
var pieces := 0
var towers: Array = []  # [centre (Vector2), half width, top y] for gantries and cables


## clusters: [[centre Vector3, radius], ...] for the hot sodium clusters.
func build(seed: int, clusters: Array) -> ArrayMesh:
	rng.seed = seed
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rings: [inner, outer, count]. Nearer rings get the widest masses.
	for ring in [[700.0, 1300.0, 18], [1300.0, 2400.0, 30], [2400.0, 4200.0, 44], [4200.0, 7500.0, 60]]:
		for k in int(ring[2]):
			var dist := rng.randf_range(ring[0], ring[1])
			var c := Vector2.from_angle(rng.randf() * TAU) * dist
			var hw := clampf(dist * rng.randf_range(0.03, 0.08), 35.0, 380.0)
			_tower(c, hw, rng.randf_range(-150.0, 1900.0), rng.randf_range(0.01, 0.045))
	for c in clusters:
		_cluster(c[0], c[1])
	for k in 5:
		_slab()
	for k in 30:
		_gantry()
	for k in 44:
		_cable()
	return st.commit()
## One tower of a random kind. hw = half width, top = its roof height.
func _tower(c: Vector2, hw: float, top: float, dens: float) -> void:
	var tone := rng.randf()
	var kind := rng.randf()
	var hd := hw * rng.randf_range(0.6, 1.4)
	towers.append([c, hw, top])
	if kind < 0.4:  # a shaft with 1-3 setbacks
		var steps := rng.randi_range(1, 3)
		var y := top - (top - BOTTOM) * rng.randf_range(0.0, 0.25) * steps
		_box(c, Vector2(hw, hd), BOTTOM, y, tone, dens)
		var w := Vector2(hw, hd)
		for s in steps:
			w *= rng.randf_range(0.45, 0.8)
			var off := Vector2(rng.randf_range(-0.3, 0.3) * hw, rng.randf_range(-0.3, 0.3) * hd)
			var y1 := y + (top - y) / (steps - s) + rng.randf_range(20.0, 120.0)
			_box(c + off, w, y, y1, tone, dens * 1.4)
			y = y1
		if rng.randf() < 0.5:
			_mast(c, top, hw)
	elif kind < 0.6:  # a cylinder, often with a collar, a mast on top
		var n := 10 + 2 * rng.randi_range(0, 3)
		_prism(_ngon(c, hw, n), _ngon(c, hw, n), BOTTOM, top, tone, dens)
		if rng.randf() < 0.6:
			var y := rng.randf_range(BOTTOM * 0.3, top - hw)
			_prism(_ngon(c, hw * 1.3, n), _ngon(c, hw * 1.3, n), y, y + hw * 0.4, tone, dens * 0.3)
		_mast(c, top, hw)
	elif kind < 0.76:  # a spire: wide plinth, then a tapering shaft lost in the haze
		var n: int = [4, 6, 8][rng.randi_range(0, 2)]
		var plinth := BOTTOM + (top - BOTTOM) * rng.randf_range(0.2, 0.5)
		_prism(_ngon(c, hw * 1.4, n), _ngon(c, hw * 1.2, n), BOTTOM, plinth, tone, dens * 0.7)
		_prism(_ngon(c, hw, n), _ngon(c, hw * 0.18, n), plinth, top + (top - BOTTOM) * 0.5 + 400.0, tone, dens)
	elif kind < 0.9:  # a mass braced by sloped buttresses
		_box(c, Vector2(hw, hd), BOTTOM, top, tone, dens)
		for i in rng.randi_range(2, 4):
			var dir := Vector2.from_angle(rng.randi_range(0, 3) * PI * 0.5)
			var side := Vector2(-dir.y, dir.x)
			var bw := hw * rng.randf_range(0.3, 0.55)
			var reach := hw * rng.randf_range(0.9, 1.6)
			var bot := _rect(c + dir * (hw + reach), dir * bw + side * bw * 0.6)
			var tp := _rect(c + dir * hw * 0.4, dir * bw * 0.3 + side * bw * 0.3)
			_prism(bot, tp, BOTTOM, BOTTOM + (top - BOTTOM) * rng.randf_range(0.5, 0.85), tone * 0.8, dens * 0.3)
	else:  # twins joined by a gantry
		var gap := hw * rng.randf_range(1.6, 2.4)
		var side := Vector2.from_angle(rng.randf() * TAU) * gap * 0.5
		_box(c + side, Vector2(hw * 0.6, hd * 0.6), BOTTOM, top, tone, dens)
		_box(c - side, Vector2(hw * 0.6, hd * 0.6), BOTTOM, top * rng.randf_range(0.5, 0.9), tone, dens)
		var y := rng.randf_range(BOTTOM * 0.5, top * 0.5)
		_bar(Vector3(c.x + side.x, y, c.y + side.y), Vector3(c.x - side.x, y, c.y - side.y), hw * 0.12, tone, 0.1, 0.0)


## A thin mast with a cool beacon on top.
func _mast(c: Vector2, top: float, hw: float) -> void:
	var h := hw * rng.randf_range(1.0, 2.5)
	_bar(Vector3(c.x, top, c.y), Vector3(c.x, top + h, c.y), maxf(hw * 0.05, 4.0), 0.5, 0.0, 0.0)
	_box(c, Vector2(5.0, 5.0), top + h, top + h + 5.0, 0.5, 0.0, 0.5)


## A hot sodium cluster: a low industrial deck with squat blocks and a scatter of lamps.
func _cluster(at: Vector3, r: float) -> void:
	var c := Vector2(at.x, at.z)
	_box(c, Vector2(r * 0.8, r * 0.6), at.y - 200.0, at.y - 120.0, 0.6, 0.02)
	var deck2 := _rect(c + Vector2(r * 0.3, -r * 0.2), Vector2.from_angle(0.6) * r * 0.55)
	_prism(deck2, deck2, at.y - 230.0, at.y - 150.0, 0.5, 0.02)
	for i in 7:
		var p := c + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.5, 0.5)) * r
		_box(p, Vector2(rng.randf_range(20.0, 60.0), rng.randf_range(20.0, 60.0)), at.y - 120.0, at.y + rng.randf_range(0.0, 160.0), rng.randf(), 0.3)
	for i in 14:
		var p := c + Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.6, 0.6)) * r
		var y := at.y - 115.0 + rng.randf_range(0.0, 120.0)
		_box(p, Vector2(4.0, 4.0), y, y + 4.0, 0.5, 0.0, 1.0)


## A slab hanging in the haze, cables trailing below it, a mast on top.
func _slab() -> void:
	var c := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(900.0, 3000.0)
	var hw := rng.randf_range(200.0, 600.0)
	var y := rng.randf_range(450.0, 1400.0)
	var pts := _rect(c, Vector2.from_angle(rng.randf() * TAU) * hw)
	_prism(pts, pts, y, y + rng.randf_range(50.0, 140.0), rng.randf(), 0.06)
	for i in rng.randi_range(2, 4):
		var p := c + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)) * hw
		var q := p + Vector2(rng.randf_range(-80.0, 80.0), rng.randf_range(-80.0, 80.0))
		_bar(Vector3(p.x, y, p.y), Vector3(q.x, y - rng.randf_range(600.0, 1400.0), q.y), rng.randf_range(5.0, 9.0), 0.4, 0.0, 0.0)
	_mast(c, y + 100.0, hw * 0.4)


## A bridge or conduit between two neighbouring towers, sometimes sloped.
func _gantry() -> void:
	var pair := _neighbours()
	if pair.is_empty():
		return
	var a: Array = pair[0]
	var b: Array = pair[1]
	var y := rng.randf_range(-600.0, minf(a[2], b[2]) - 40.0)
	var y2 := y + (rng.randf_range(-200.0, 200.0) if rng.randf() < 0.3 else 0.0)
	_bar(Vector3(a[0].x, y, a[0].y), Vector3(b[0].x, y2, b[0].y), rng.randf_range(10.0, 40.0), rng.randf(), 0.08, 0.0)


## A cable sagging between two tower tops.
func _cable() -> void:
	var pair := _neighbours()
	if pair.is_empty():
		return
	var a: Array = pair[0]
	var b: Array = pair[1]
	var p0 := Vector3(a[0].x, a[2] - rng.randf_range(0.0, 150.0), a[0].y)
	var p1 := Vector3(b[0].x, b[2] - rng.randf_range(0.0, 150.0), b[0].y)
	var span := Vector2(p0.x - p1.x, p0.z - p1.z).length()
	var sag := span * rng.randf_range(0.1, 0.25)
	var r := rng.randf_range(4.0, 8.0) + span * 0.003
	var prev := p0
	for i in range(1, 9):
		var s := i / 8.0
		var p := p0.lerp(p1, s) - Vector3(0, sag * 4.0 * s * (1.0 - s), 0)
		_bar(prev, p, r, 0.3, 0.0, 0.0)
		prev = p


## A random tower and its nearest neighbour that is not too close.
func _neighbours() -> Array:
	var a: Array = towers[rng.randi() % towers.size()]
	var best: Array = []
	var best_d := INF
	for b in towers:
		var dd: float = a[0].distance_to(b[0])
		if dd > a[1] * 2.5 and dd < best_d and rng.randf() < 0.5:
			best_d = dd
			best = b
	return [] if best.is_empty() or best_d > 1500.0 else [a, best]


# ------------------------------------------------------------------ primitives

func _ngon(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2.from_angle(TAU * i / n) * r)
	return pts


## A rectangle footprint: centre, half extent along `a` (its length and direction), square-ish.
func _rect(c: Vector2, a: Vector2) -> PackedVector2Array:
	var b := Vector2(-a.y, a.x)
	return PackedVector2Array([c + a + b, c - a + b, c - a - b, c + a - b])


func _box(c: Vector2, half: Vector2, y0: float, y1: float, tone: float, dens: float, kind := 0.0) -> void:
	var pts := PackedVector2Array([c + Vector2(-half.x, -half.y), c + Vector2(half.x, -half.y), c + half, c + Vector2(-half.x, half.y)])
	_prism(pts, pts, y0, y1, tone, dens, kind)


## A prism from footprint `bot` at y0 to footprint `top` at y1 (same point count): boxes,
## cylinders, tapering spires and leaning buttresses. The shader draws both sides.
func _prism(bot: PackedVector2Array, top: PackedVector2Array, y0: float, y1: float, tone: float, dens: float, kind := 0.0) -> void:
	pieces += 1
	var col := Color(tone, dens, float(pieces % 256) / 255.0, kind)
	var mid := Vector2.ZERO
	for p in bot:
		mid += p
	mid /= bot.size()
	var n := bot.size()
	for i in n:
		var p: Vector2 = bot[i]
		var q: Vector2 = bot[(i + 1) % n]
		var e := (q - p).normalized()
		var out := Vector2(-e.y, e.x)
		if out.dot((p + q) * 0.5 - mid) < 0.0:
			out = -out
		var nrm := Vector3(out.x, 0.0, out.y)
		var pt: Vector2 = top[i]
		var qt: Vector2 = top[(i + 1) % n]
		_tri(Vector3(p.x, y0, p.y), Vector3(q.x, y0, q.y), Vector3(qt.x, y1, qt.y), col, nrm)
		_tri(Vector3(p.x, y0, p.y), Vector3(qt.x, y1, qt.y), Vector3(pt.x, y1, pt.y), col, nrm)
	for i in range(1, n - 1):
		_tri(Vector3(top[0].x, y1, top[0].y), Vector3(top[i + 1].x, y1, top[i + 1].y), Vector3(top[i].x, y1, top[i].y), col, Vector3.UP)
		_tri(Vector3(bot[0].x, y0, bot[0].y), Vector3(bot[i].x, y0, bot[i].y), Vector3(bot[i + 1].x, y0, bot[i + 1].y), col, Vector3.DOWN)


## A square tube of half width r from a to b, any slope: masts, gantries, cable segments.
func _bar(a: Vector3, b: Vector3, r: float, tone: float, dens: float, kind: float) -> void:
	pieces += 1
	var col := Color(tone, dens, float(pieces % 256) / 255.0, kind)
	var axis := (b - a).normalized()
	var s := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized() * r
	var t := axis.cross(s).normalized() * r
	var corners := [s + t, s - t, -s - t, -s + t]
	for i in 4:
		var c0: Vector3 = corners[i]
		var c1: Vector3 = corners[(i + 1) % 4]
		var nrm := (c0 + c1).normalized()
		_tri(a + c0, a + c1, b + c1, col, nrm)
		_tri(a + c0, b + c1, b + c0, col, nrm)


func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color, n: Vector3) -> void:
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)
