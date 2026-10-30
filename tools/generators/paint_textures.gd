extends SceneTree
# Paints the 128 px texture set for the Empty Town: painted concrete, apartment facades, pavement,
# a trim sheet (pipes, vents, cables, rails, stripes), a vending machine, sign glyphs, decals.
# "Painted" here means: soft colour variation, dark seams with a light edge above them,
# grime that pools at the bottom, and a little grain, all quantised a touch.

var noise := FastNoiseLite.new()
var grain := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02
	grain.noise_type = FastNoiseLite.TYPE_CELLULAR
	grain.frequency = 0.35
	rng.seed = 2026
	_concrete("concrete_painted.png", Color(0.6, 0.58, 0.55), 128, 1)
	_concrete("concrete_dark_painted.png", Color(0.36, 0.37, 0.42), 128, 2)
	_facade("facade_painted", [1, 0, 4, 3, 2, 1, 0, 1, 4, 3, 1, 0, 3, 1, 4, 2])
	_facade("facade_unlit", [0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0])
	_pavement()
	_trim_sheet()
	_vending()
	_sign()
	_decals()
	_grating()
	print("textures painted")
	quit()


# ------------------------------------------------------------------ helpers

func _img(w: int, h: int, alpha := false) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8 if alpha else Image.FORMAT_RGB8)


func _n(x: float, y: float, seed_offset := 0) -> float:  # -1..1 soft variation
	noise.seed = 100 + seed_offset
	return noise.get_noise_2d(x, y)


func _g(x: float, y: float) -> float:  # 0..1 grain
	return grain.get_noise_2d(x, y) * 0.5 + 0.5


func _q(c: Color) -> Color:  # quantise a little, like paint
	return Color(round(c.r * 40.0) / 40.0, round(c.g * 40.0) / 40.0, round(c.b * 40.0) / 40.0, c.a)


func _mul(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


func _save(img: Image, name: String) -> void:
	img.save_png("res://textures/" + name)


## Base paint: colour with two octaves of variation and grain.
func _paint(img: Image, base: Color, amount := 0.12, seed_offset := 0) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var v := _n(x, y, seed_offset) * amount
			img.set_pixel(x, y, _q(_mul(base, 1.0 + v)))


## Darken pixels inside a rect by f (0..1), with soft noise.
func _grime(img: Image, x0: int, y0: int, x1: int, y1: int, strength: float, seed_offset := 7) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			var t := float(y - y0) / maxf(1.0, y1 - y0)  # stronger toward the bottom
			var f := strength * t * (0.6 + 0.4 * (_n(x * 1.5, y * 1.5, seed_offset) * 0.5 + 0.5))
			img.set_pixel(x, y, _mul(img.get_pixel(x, y), 1.0 - f))


func _seam(img: Image, x0: int, y0: int, x1: int, y1: int, horizontal: bool) -> void:
	# a crisp dark line with a light edge on the lit side
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(x, y, _mul(img.get_pixel(x, y), 0.7))
	if horizontal:
		for x in range(x0, x1):
			if y0 - 1 >= 0:
				img.set_pixel(x, y0 - 1, _mul(img.get_pixel(x, y0 - 1), 1.08))
	else:
		for y in range(y0, y1):
			if x0 - 1 >= 0:
				img.set_pixel(x0 - 1, y, _mul(img.get_pixel(x0 - 1, y), 1.06))


func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(0, y0), mini(img.get_height(), y1)):
		for x in range(maxi(0, x0), mini(img.get_width(), x1)):
			img.set_pixel(x, y, c)


func _crack(img: Image, x: int, y: int, length: int, c: Color) -> void:
	var dx := rng.randi_range(-1, 1)
	for i in length:
		if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
			return
		img.set_pixel(x, y, c)
		y += 1
		if rng.randf() < 0.4:
			dx = rng.randi_range(-1, 1)
		x += dx


# ------------------------------------------------------------------ textures

func _concrete(name: String, base: Color, panel: int, seed_offset: int) -> void:
	var img := _img(128, 128)
	_paint(img, base, 0.08, seed_offset)
	for py in range(0, 128, panel):
		_seam(img, 0, py + panel - 3, 128, py + panel - 1, true)
		_grime(img, 0, py + panel - 30, 128, py + panel - 3, 0.14, seed_offset + 3)
	for px in range(0, 128, panel):
		_seam(img, px + panel - 2, 0, px + panel, 128, false)
	# A clean two-tone band near the top of each panel, like paint catching the light.
	for y in range(0, 8):
		for x in 128:
			img.set_pixel(x, y, _mul(img.get_pixel(x, y), 1.05))
	_save(img, name)


func _facade(name: String, state: Array) -> void:
	var img := _img(128, 128)
	var glow := _img(128, 128)
	glow.fill(Color.BLACK)
	_paint(img, Color(0.5, 0.49, 0.53), 0.06, 11)
	# lit states per bay, read row by row: 0 dark, 1 warm, 2 TV blue, 3 dim warm, 4 curtain
	var has_ac := [0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0]
	for by in 4:
		for bx in 4:
			var ox := bx * 32
			var oy := by * 32
			var cell: int = by * 4 + bx
			# floor slab: a dark line with a light lip
			_seam(img, ox, oy + 29, ox + 32, oy + 31, true)
			# window frame and glass
			var wx0 := ox + 7
			var wy0 := oy + 6
			var wx1 := ox + 25
			var wy1 := oy + 22
			_rect(img, wx0 - 1, wy0 - 1, wx1 + 1, wy1 + 1, Color(0.22, 0.21, 0.23))
			var glass: Color
			var light := Color.BLACK
			match state[cell]:
				1:
					glass = Color(0.9, 0.72, 0.42)
					light = Color(1.0, 0.75, 0.4)
				2:
					glass = Color(0.35, 0.75, 0.85)
					light = Color(0.3, 0.7, 0.85)
				3:
					glass = Color(0.58, 0.42, 0.27)
					light = Color(0.5, 0.32, 0.18)
				4:
					glass = Color(0.6, 0.55, 0.5)
					light = Color(0.35, 0.3, 0.25)
				_:
					glass = Color(0.2, 0.22, 0.3)  # dark, but still reads as glass
			for y in range(wy0, wy1):
				for x in range(wx0, wx1):
					var c := glass
					if state[cell] == 4 and (x - wx0) % 3 == 0:
						c = _mul(glass, 0.7)  # curtain folds
					if state[cell] == 0 and (x + y) % 9 == 0:
						c = _mul(glass, 1.6)  # a glint
					img.set_pixel(x, y, _q(c))
					if light != Color.BLACK:
						glow.set_pixel(x, y, _q(_mul(light, 1.0 if state[cell] != 4 else 0.5)))
			_rect(img, ox + 16, wy0, ox + 17, wy1, Color(0.22, 0.21, 0.23))  # mullion
			glow.fill_rect(Rect2i(ox + 16, wy0, 1, wy1 - wy0), Color.BLACK)
			_rect(img, wx0 - 2, wy1 + 1, wx1 + 2, wy1 + 2, Color(0.62, 0.6, 0.6))  # sill
			_grime(img, wx0 - 2, wy1 + 2, wx1 + 2, oy + 29, 0.18, 13 + cell)  # streaks under the sill
			if has_ac[cell] == 1:
				_rect(img, ox + 19, oy + 23, ox + 29, oy + 29, Color(0.58, 0.58, 0.56))
				for k in 3:
					_rect(img, ox + 20, oy + 24 + k * 2, ox + 28, oy + 25 + k * 2, Color(0.4, 0.4, 0.4))
				_rect(img, ox + 19, oy + 23, ox + 29, oy + 24, Color(0.7, 0.7, 0.68))
	_save(img, name + ".png")
	_save(glow, name + "_glow.png")


func _pavement() -> void:
	var img := _img(128, 128)
	_paint(img, Color(0.42, 0.42, 0.46), 0.07, 21)
	for ty in range(0, 128, 64):
		for tx in range(0, 128, 64):
			var tint := 1.0 + _n(tx * 3, ty * 3, 22) * 0.07  # each tile its own shade
			for y in range(ty, ty + 64):
				for x in range(tx, tx + 64):
					img.set_pixel(x, y, _mul(img.get_pixel(x, y), tint))
			_seam(img, tx, ty + 62, tx + 64, ty + 64, true)
			_seam(img, tx + 62, ty, tx + 64, ty + 64, false)
	for i in 2:  # dirt patches
		var cx := rng.randi_range(10, 117)
		var cy := rng.randi_range(10, 117)
		for y in range(cy - 12, cy + 12):
			for x in range(cx - 14, cx + 14):
				if x < 0 or y < 0 or x > 127 or y > 127:
					continue
				var d := Vector2(x - cx, y - cy).length() / 13.0
				if d < 1.0:
					img.set_pixel(x, y, _mul(img.get_pixel(x, y), 1.0 - 0.3 * (1.0 - d)))
	_save(img, "pavement.png")


## Eight 16 px strips: 0 pipe, 1 vent, 2 cables, 3 rail/panel edge, 4 warning stripes,
## 5 rust band, 6 wet lip, 7 neon tube (lit in the glow map).
func _trim_sheet() -> void:
	var img := _img(128, 128)
	var glow := _img(128, 128)
	glow.fill(Color.BLACK)
	for strip in 8:
		var y0 := strip * 16
		for y in range(y0, y0 + 16):
			for x in 128:
				var t := float(y - y0) / 15.0  # 0 top .. 1 bottom of the strip
				var c: Color
				match strip:
					0:  # pipe: a shaded cylinder, a band every 32 px
						var shade := 0.55 + 0.6 * sin(t * PI)
						c = _mul(Color(0.45, 0.47, 0.52), shade)
						if x % 32 < 3:
							c = _mul(c, 0.7)
					1:  # vent: slots
						c = Color(0.4, 0.41, 0.44)
						if (y - y0) % 4 == 1 or (y - y0) % 4 == 2:
							c = Color(0.12, 0.12, 0.14) if x % 16 > 1 else c
					2:  # cables: three dark cords with highlights
						c = Color(0.18, 0.17, 0.19)
						var k := (y - y0) % 5
						if k == 1:
							c = Color(0.3, 0.3, 0.34)
						elif k == 2:
							c = Color(0.08, 0.08, 0.1)
						if x % 24 < 2:
							c = Color(0.3, 0.28, 0.25)  # a tie
					3:  # rail / panel edge: light top, dark underside, rivets
						c = Color(0.38, 0.39, 0.43)
						if t < 0.15:
							c = Color(0.62, 0.63, 0.66)
						elif t > 0.85:
							c = Color(0.18, 0.18, 0.2)
						if x % 16 == 8 and abs(t - 0.5) < 0.15:
							c = Color(0.7, 0.7, 0.72)
					4:  # warning stripes
						var s := int(float(x + (y - y0)) / 8.0) % 2
						c = Color(0.85, 0.7, 0.15) if s == 0 else Color(0.12, 0.12, 0.12)
					5:  # rust band
						var r := _n(x * 2, y * 2, 31) * 0.5 + 0.5
						c = Color(0.45, 0.25, 0.14).lerp(Color(0.3, 0.3, 0.33), r)
					6:  # wet concrete lip
						c = _mul(Color(0.4, 0.4, 0.42), 0.6 + 0.4 * t)
					7:  # neon tube: white core, coloured halo
						var d := absf(t - 0.5) * 2.0
						c = Color(1.0, 1.0, 1.0) if d < 0.3 else Color(0.08, 0.08, 0.1)
						if d < 0.3:
							glow.set_pixel(x, y, Color(1.0, 0.35, 0.75))
				img.set_pixel(x, y, _q(c))
	_save(img, "trim_sheet.png")
	_save(glow, "trim_sheet_glow.png")


func _vending() -> void:
	var img := _img(64, 128)
	var glow := _img(64, 128)
	glow.fill(Color.BLACK)
	_paint(img, Color(0.7, 0.2, 0.25), 0.08, 41)
	_rect(img, 4, 8, 60, 60, Color(0.1, 0.12, 0.18))  # the lit window
	for r in 3:
		for c in 4:
			var x := 7 + c * 13
			var y := 12 + r * 15
			var drink: Color = [Color(0.9, 0.6, 0.2), Color(0.3, 0.7, 0.9), Color(0.8, 0.3, 0.5), Color(0.5, 0.85, 0.4)][(r + c) % 4]
			_rect(img, x, y, x + 9, y + 12, drink)
			glow.fill_rect(Rect2i(x, y, 9, 12), _mul(drink, 0.6))
	_rect(img, 4, 64, 60, 72, Color(0.95, 0.9, 0.8))  # the light strip
	glow.fill_rect(Rect2i(4, 64, 56, 8), Color(1.0, 0.95, 0.85))
	for i in 8:  # buttons
		_rect(img, 6 + i * 7, 78, 10 + i * 7, 84, Color(0.2, 0.2, 0.22))
	_rect(img, 8, 96, 56, 112, Color(0.12, 0.1, 0.1))  # the flap
	_grime(img, 0, 100, 64, 128, 0.4, 43)
	_save(img, "vending.png")
	_save(glow, "vending_glow.png")


## A sign plate with painted glyph strokes; the glow map lights only the strokes.
func _sign() -> void:
	var img := _img(128, 64)
	var glow := _img(128, 64)
	glow.fill(Color.BLACK)
	_paint(img, Color(0.12, 0.12, 0.15), 0.1, 51)
	_rect(img, 0, 0, 128, 2, Color(0.4, 0.4, 0.44))
	_rect(img, 0, 62, 128, 64, Color(0.4, 0.4, 0.44))
	var strokes := [
		[10, 12, 34, 16], [12, 20, 32, 24], [20, 10, 24, 52], [8, 44, 36, 48],
		[48, 10, 52, 54], [54, 14, 76, 18], [56, 30, 74, 34], [72, 18, 76, 52],
		[88, 12, 118, 16], [100, 16, 104, 54], [86, 36, 120, 40], [90, 48, 116, 52],
	]
	for s in strokes:
		_rect(img, s[0], s[1], s[2], s[3], Color(1.0, 0.95, 0.9))
		glow.fill_rect(Rect2i(s[0], s[1], s[2] - s[0], s[3] - s[1]), Color(1.0, 1.0, 1.0))
	_save(img, "sign_glyphs.png")
	_save(glow, "sign_glyphs_glow.png")


func _decals() -> void:
	# puddle: dark, slightly blue, soft edge, alpha
	var puddle := _img(64, 64, true)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32, y - 32).length() / 30.0
			var edge := _n(x * 3, y * 3, 61) * 0.25
			var a := clampf(1.0 - (d + edge), 0.0, 1.0)
			puddle.set_pixel(x, y, Color(0.05, 0.06, 0.1, a * 0.75))
	_save(puddle, "decal_puddle.png")
	# grime: soft dark stain
	var stain := _img(64, 64, true)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32, y - 32).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0) * (0.5 + 0.5 * (_n(x * 2, y * 2, 62) * 0.5 + 0.5))
			stain.set_pixel(x, y, Color(0.05, 0.04, 0.04, a * 0.6))
	_save(stain, "decal_grime.png")
	# poster: a torn paper with a block of colour and lines of "text"
	var poster := _img(48, 64, true)
	poster.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in 64:
		for x in 48:
			var torn := y > 56 and _n(x * 4, y * 4, 63) > 0.1
			if torn:
				continue
			var c := Color(0.85, 0.8, 0.7)
			if y < 26:
				c = Color(0.75, 0.2, 0.3) if (x + y) % 11 != 0 else Color(0.9, 0.6, 0.65)
			elif y % 6 == 2 and x > 4 and x < 44 and (x % 9) != 0:
				c = Color(0.2, 0.18, 0.2)
			poster.set_pixel(x, y, Color(c.r, c.g, c.b, 0.95))
	_save(poster, "decal_poster.png")


func _grating() -> void:
	var img := _img(64, 64)
	for y in 64:
		for x in 64:
			var bar := (x % 8 < 2) or (y % 8 < 2)
			var c := Color(0.5, 0.52, 0.56) if bar else Color(0.08, 0.09, 0.12)
			if bar and (x % 8 == 0 or y % 8 == 0):
				c = Color(0.66, 0.68, 0.72)
			img.set_pixel(x, y, _q(_mul(c, 1.0 + (_g(x, y) - 0.5) * 0.1)))
	_save(img, "grating.png")
