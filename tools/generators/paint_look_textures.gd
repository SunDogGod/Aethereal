extends SceneTree
# Look round (2026-11-05). Paints:
#  - textures/trim_glyphs.png (+ _glow): a trim sheet of eight 64 px strips, 128 px long, for
#    Blocks with `trim` on (u = metres along, v across): 0 vent louvres, 1 grate, 2 warning
#    stripes, 3 plaque A (ring, triangle, three dots), 4 plaque B (the eye in a ring), 5 cold
#    chevrons, 6 ribbed service panel, 7 cable tray. Fat strokes only: nothing thinner than 2 px.
#    The glow map lights the plaques' glyphs (white, tinted by the material).
#  - textures/pavement_wet.png: the worn pavement, darker and with a faint sheen and puddles.
# Materials: materials/tex_trim_glyphs_*.tres, materials/tex_pavement_wet.tres.
# Run: godot --headless --path PROJ -s this.gd, then --import.

const W := 128
const S := 64  # strip height
const IRON := Color(0.2, 0.2, 0.23)
const IRON_LIGHT := Color(0.34, 0.34, 0.38)
const HOLE := Color(0.05, 0.05, 0.06)
const OCHRE := Color(0.72, 0.6, 0.36)  # the glyph strokes
const AMBER := Color(0.7, 0.55, 0.18)

var noise := FastNoiseLite.new()
var img: Image
var glow: Image


func _initialize() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	noise.seed = 1105
	_trim_glyphs()
	_pavement_wet()
	print("look textures painted")
	quit()


# ------------------------------------------------------------------ helpers

func _rect(x0: int, y0: int, x1: int, y1: int, c: Color, lit := false) -> void:
	img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)
	if lit:
		glow.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), Color.WHITE)


## A fat ring: centre (cx, cy), outer radius r, stroke `wd`.
func _ring(cx: int, cy: int, r: int, wd: int, c: Color, lit := false) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var d := Vector2(x - cx, y - cy).length()
			if d <= r and d > r - wd:
				_rect(x, y, x + 1, y + 1, c, lit)


## A fat line from a to b.
func _line(a: Vector2i, b: Vector2i, wd: int, c: Color, lit := false) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxi(n, 1)
		var p := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		_rect(p.x, p.y, p.x + wd, p.y + wd, c, lit)


## Soft tone variation over a strip, so flat metal isn't one flat colour.
func _mottle(y0: int, amount: float, seed_offset: int) -> void:
	noise.seed = 1105 + seed_offset
	for y in range(y0, y0 + S):
		for x in W:
			var f := 1.0 + noise.get_noise_2d(x, y) * amount
			img.set_pixel(x, y, img.get_pixel(x, y) * f)


func _quantise() -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(round(c.r * 32.0) / 32.0, round(c.g * 32.0) / 32.0, round(c.b * 32.0) / 32.0))


# ------------------------------------------------------------------ the trim sheet

func _trim_glyphs() -> void:
	img = Image.create(W, S * 8, false, Image.FORMAT_RGB8)
	glow = Image.create(W, S * 8, false, Image.FORMAT_RGB8)
	glow.fill(Color.BLACK)
	img.fill(IRON)
	_vent(0)
	_grate(S)
	_stripes(S * 2)
	_plaque_a(S * 3)
	_plaque_b(S * 4)
	_chevrons(S * 5)
	_ribbed(S * 6)
	_tray(S * 7)
	for strip in 8:
		_mottle(strip * S, 0.08, strip)
	_quantise()
	img.save_png("res://textures/trim_glyphs.png")
	glow.save_png("res://textures/trim_glyphs_glow.png")


## Louvres: a frame, a dark recess, fat slats with a lit top edge.
func _vent(y0: int) -> void:
	_rect(0, y0, W, y0 + S, IRON_LIGHT)
	_rect(4, y0 + 4, W - 4, y0 + S - 4, HOLE)
	for k in range(y0 + 8, y0 + S - 8, 8):
		_rect(6, k, W - 6, k + 5, IRON)
		_rect(6, k, W - 6, k + 1, IRON_LIGHT)


## A grid of fat bars over dark holes.
func _grate(y0: int) -> void:
	_rect(0, y0, W, y0 + S, HOLE)
	for x in range(0, W, 16):
		_rect(x, y0, x + 5, y0 + S, IRON_LIGHT)
		_rect(x, y0, x + 1, y0 + S, IRON_LIGHT.lightened(0.2))
	for y in range(y0, y0 + S, 16):
		_rect(0, y, W, y + 5, IRON_LIGHT)
		_rect(0, y, W, y + 1, IRON_LIGHT.lightened(0.2))


## Amber and black diagonals, 12 px wide, with a dark band top and bottom.
func _stripes(y0: int) -> void:
	for y in range(y0, y0 + S):
		for x in W:
			var s := int(float(x + (y - y0)) / 12.0) % 2
			img.set_pixel(x, y, AMBER if s == 0 else Color(0.1, 0.1, 0.11))
	_rect(0, y0, W, y0 + 4, IRON)
	_rect(0, y0 + S - 4, W, y0 + S, IRON)


## A dark plaque with a bevel; two glyphs per 128 px.
func _plaque(y0: int) -> void:
	_rect(0, y0, W, y0 + S, Color(0.14, 0.13, 0.15))
	_rect(0, y0, W, y0 + 3, IRON_LIGHT)
	_rect(0, y0 + S - 3, W, y0 + S, HOLE)
	for p in [Vector2i(6, y0 + 7), Vector2i(W - 9, y0 + 7), Vector2i(6, y0 + S - 10), Vector2i(W - 9, y0 + S - 10)]:
		_rect(p.x, p.y, p.x + 3, p.y + 3, IRON_LIGHT)  # bolts


## Glyph A: a ring with a triangle inside, then a ring with a bar and three dots.
func _plaque_a(y0: int) -> void:
	_plaque(y0)
	var c := y0 + 32
	_ring(32, c, 22, 4, OCHRE, true)
	_line(Vector2i(32, c - 12), Vector2i(20, c + 9), 3, OCHRE, true)
	_line(Vector2i(32, c - 12), Vector2i(44, c + 9), 3, OCHRE, true)
	_line(Vector2i(20, c + 9), Vector2i(44, c + 9), 3, OCHRE, true)
	_ring(96, c, 22, 4, OCHRE, true)
	_rect(94, c - 14, 99, c + 2, OCHRE, true)
	for k in 3:
		_rect(86 + k * 8, c + 8, 90 + k * 8, c + 12, OCHRE, true)


## Glyph B: the eye in a ring (the captors' mark), then the earth sign (a barred triangle).
func _plaque_b(y0: int) -> void:
	_plaque(y0)
	var c := y0 + 32
	_ring(32, c, 24, 3, OCHRE, true)
	for x in range(14, 51):  # the lens: two arcs meeting at the corners
		var t := absf(float(x - 32) / 18.0)
		var h := int((1.0 - t * t) * 10.0)
		if h > 0:
			_rect(x, c - h - 1, x + 1, c - h + 2, OCHRE, true)
			_rect(x, c + h - 1, x + 1, c + h + 2, OCHRE, true)
	_ring(32, c, 5, 5, OCHRE, true)  # the pupil
	# The earth sign: a triangle on its point with a bar through it, and a dot above.
	_line(Vector2i(76, c - 10), Vector2i(116, c - 10), 3, OCHRE, true)
	_line(Vector2i(76, c - 10), Vector2i(96, c + 18), 3, OCHRE, true)
	_line(Vector2i(116, c - 10), Vector2i(96, c + 18), 3, OCHRE, true)
	_line(Vector2i(82, c + 2), Vector2i(112, c + 2), 3, OCHRE, true)
	_rect(94, c - 22, 100, c - 16, OCHRE, true)


## Cold chevrons: pale grey on black, pointing along the strip.
func _chevrons(y0: int) -> void:
	_rect(0, y0, W, y0 + S, Color(0.1, 0.1, 0.12))
	for x in range(-32, W, 32):
		_line(Vector2i(x, y0 + 4), Vector2i(x + 20, y0 + 32), 8, Color(0.62, 0.64, 0.68))
		_line(Vector2i(x + 20, y0 + 32), Vector2i(x, y0 + 60), 8, Color(0.62, 0.64, 0.68))
	_rect(0, y0, W, y0 + 3, IRON)
	_rect(0, y0 + S - 3, W, y0 + S, IRON)


## Vertical ribs, a lit edge and a shadow each.
func _ribbed(y0: int) -> void:
	for x in range(0, W, 16):
		_rect(x, y0, x + 10, y0 + S, IRON_LIGHT)
		_rect(x, y0, x + 2, y0 + S, IRON_LIGHT.lightened(0.18))
		_rect(x + 10, y0, x + 16, y0 + S, HOLE)


## A channel holding three fat cables, clamped every 32 px.
func _tray(y0: int) -> void:
	_rect(0, y0, W, y0 + S, HOLE)
	_rect(0, y0, W, y0 + 5, IRON_LIGHT)
	_rect(0, y0 + S - 5, W, y0 + S, IRON_LIGHT)
	for k in 3:
		var y := y0 + 10 + k * 16
		var c: Color = [Color(0.16, 0.15, 0.17), Color(0.3, 0.16, 0.12), Color(0.14, 0.17, 0.2)][k]
		_rect(0, y, W, y + 11, c)
		_rect(0, y, W, y + 3, c.lightened(0.25))
	for x in range(12, W, 32):
		_rect(x, y0 + 6, x + 6, y0 + S - 6, IRON_LIGHT)


# ------------------------------------------------------------------ wet pavement

## The worn pavement, two thirds as bright, with a cool cast, soft sheen bands and three
## puddles: darker, bluer, a pale rim on the far side.
func _pavement_wet() -> void:
	img = Image.load_from_file(ProjectSettings.globalize_path("res://textures/pavement_worn.png"))
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var h := img.get_height()
	noise.seed = 2210
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y) * Color(0.6, 0.62, 0.7)
			var sheen := noise.get_noise_2d(x * 0.6, y * 2.5) * 0.08  # long faint bands
			img.set_pixel(x, y, c * (1.0 + sheen))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 3:
		var cx := rng.randi_range(16, w - 16)
		var cy := rng.randi_range(16, h - 16)
		var rx := rng.randi_range(10, 18)
		var ry := rng.randi_range(6, 12)
		for y in range(cy - ry - 2, cy + ry + 3):
			for x in range(cx - rx - 2, cx + rx + 3):
				var d := Vector2(float(x - cx) / rx, float(y - cy) / ry).length() + noise.get_noise_2d(x * 4, y * 4) * 0.2
				var px := Vector2i(posmod(x, w), posmod(y, h))
				if d < 1.0:
					img.set_pixel(px.x, px.y, img.get_pixel(px.x, px.y) * Color(0.55, 0.6, 0.75))
				elif d < 1.15 and y < cy:
					img.set_pixel(px.x, px.y, img.get_pixel(px.x, px.y).lightened(0.12))
	_quantise()
	img.save_png("res://textures/pavement_wet.png")
