extends SceneTree
# Look round (2026-11-05): the Horus arc's texture set, a warm desert under amber haze.
# 128 px, low contrast, fat marks. Writes textures/horus_*.png:
#   sand       warm grey-ochre with soft ripples
#   voidstone  matte black with a faint cold seam pattern (the Obelisk, the relics)
#   iron       dark oiled iron: sheen stains, rust at the seams and feet, fat rivets
#   lake       dark oily water with faint sheen bands
#   plaster    Temek's sun-bleached plaster, cracked, with the mud brick showing through
# Materials: materials/tex_horus_*.tres (world-mapped, so any Block takes them).
# Run: godot --headless --path PROJ -s this.gd, then --import.

const N := 128

var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var img: Image


func _initialize() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	rng.seed = 1105
	_sand()
	_voidstone()
	_iron()
	_lake()
	_plaster()
	print("horus textures painted")
	quit()


# ------------------------------------------------------------------ helpers

func _n(x: float, y: float, freq: float, seed_value: int) -> float:  # -1..1, tiles across the edges
	noise.seed = seed_value
	noise.frequency = freq
	# Blend four samples so the texture wraps (the same trick on both axes).
	var a := noise.get_noise_2d(x, y)
	var b := noise.get_noise_2d(x - N, y)
	var c := noise.get_noise_2d(x, y - N)
	var d := noise.get_noise_2d(x - N, y - N)
	var fx := x / N
	var fy := y / N
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


func _fill(base: Color, amount: float, freq: float, seed_value: int) -> void:
	img = Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in N:
		for x in N:
			img.set_pixel(x, y, base * (1.0 + _n(x, y, freq, seed_value) * amount))


func _rect(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(posmod(x, N), posmod(y, N), c)


func _tint(x: int, y: int, c: Color, f: float) -> void:
	var p := Vector2i(posmod(x, N), posmod(y, N))
	img.set_pixel(p.x, p.y, img.get_pixel(p.x, p.y).lerp(c, clampf(f, 0.0, 1.0)))


## A fat wandering crack: `wd` px wide, stepping down (or along) with small sideways wobbles.
func _crack(x: int, y: int, length: int, wd: int, c: Color, down := true) -> void:
	for i in length:
		for k in wd:
			_tint(x + (k if down else 0), y + (0 if down else k), c, 0.8)
		if rng.randf() < 0.4:
			if down:
				x += rng.randi_range(-1, 1)
			else:
				y += rng.randi_range(-1, 1)
		if down:
			y += 1
		else:
			x += 1


func _save(name: String) -> void:
	for y in N:
		for x in N:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(round(c.r * 32.0) / 32.0, round(c.g * 32.0) / 32.0, round(c.b * 32.0) / 32.0))
	img.save_png("res://textures/horus_%s.png" % name)


# ------------------------------------------------------------------ textures

## Ripples: bands that drift with noise, a shade lighter on the lit side; a few dark grains.
func _sand() -> void:
	_fill(Color(0.56, 0.49, 0.38), 0.05, 0.03, 1)
	for y in N:
		for x in N:
			var warp := _n(x, y, 0.025, 2) * 14.0
			var band := sin((y + warp) * TAU / 16.0)
			var f := 1.0 + band * 0.05 + (0.03 if band > 0.6 else 0.0)
			img.set_pixel(x, y, img.get_pixel(x, y) * f)
	for i in 40:
		var x := rng.randi_range(0, N - 1)
		var y := rng.randi_range(0, N - 1)
		_tint(x, y, Color(0.35, 0.3, 0.24), 0.5)
	_save("sand")


## Matte black slabs, 64 px, each seam a dark 2 px line with a faint cold lip beside it, and
## one cold mark (a short fat bar) per slab, so the surface reads as worked, not painted.
func _voidstone() -> void:
	_fill(Color(0.075, 0.075, 0.09), 0.1, 0.04, 3)
	var cold := Color(0.16, 0.2, 0.27)
	for s in range(0, N, 64):
		_rect(0, s + 62, N, s + 64, Color(0.03, 0.03, 0.04))
		_rect(s + 62, 0, s + 64, N, Color(0.03, 0.03, 0.04))
		for y in N:
			_tint(s, y, cold, 0.5)
			_tint(s + 1, y, cold, 0.25)
		for x in N:
			_tint(x, s, cold, 0.5)
			_tint(x, s + 1, cold, 0.25)
	for p in [Vector2i(20, 28), Vector2i(90, 40), Vector2i(36, 100), Vector2i(100, 84)]:
		_rect(p.x, p.y, p.x + 14, p.y + 3, cold * 0.8)
		_rect(p.x + 5, p.y - 5, p.x + 8, p.y + 8, cold * 0.8)
	_save("voidstone")


## Plates of dark iron with an oil sheen (mauve-blue blotches), rust creeping from the seams
## and the foot of each plate, and fat rivets along the seams.
func _iron() -> void:
	_fill(Color(0.2, 0.2, 0.22), 0.08, 0.05, 4)
	for y in N:
		for x in N:
			var sheen := _n(x, y, 0.02, 5)
			if sheen > 0.15:
				_tint(x, y, Color(0.3, 0.26, 0.36), (sheen - 0.15) * 1.2)
			var rust := _n(x, y, 0.06, 6) * 0.5 + 0.5
			var foot := float(y % 64) / 64.0
			var r := clampf(rust * 0.6 + foot * 0.5 - 0.55, 0.0, 1.0)
			_tint(x, y, Color(0.42, 0.22, 0.1), r)
	for s in range(0, N, 64):
		_rect(0, s + 61, N, s + 64, Color(0.08, 0.08, 0.09))
		_rect(s + 61, 0, s + 64, N, Color(0.08, 0.08, 0.09))
		for k in range(8, N, 32):
			_rect(k, s + 54, k + 4, s + 58, Color(0.36, 0.35, 0.37))
			_rect(s + 54, k, s + 58, k + 4, Color(0.36, 0.35, 0.37))
	_save("iron")


## Near-black water with long faint sheen bands and the odd oily lighter swirl.
func _lake() -> void:
	_fill(Color(0.07, 0.08, 0.09), 0.15, 0.03, 7)
	for y in N:
		for x in N:
			var band := _n(x * 0.4, y * 2.0, 0.03, 8)
			if band > 0.15:
				_tint(x, y, Color(0.16, 0.16, 0.18), (band - 0.15) * 1.5)
			var oil := _n(x, y, 0.05, 9)
			if oil > 0.45:
				_tint(x, y, Color(0.18, 0.14, 0.2), (oil - 0.45) * 2.0)
	_save("lake")


## Sun-bleached plaster: pale, blotchy, with fat cracks and patches of bare mud brick where it
## fell away, darker and dustier toward the foot.
func _plaster() -> void:
	_fill(Color(0.72, 0.66, 0.55), 0.07, 0.04, 10)
	var brick := Color(0.5, 0.4, 0.3)
	for y in N:
		for x in N:
			var gone := _n(x, y, 0.045, 11)
			if gone > 0.42:
				_tint(x, y, brick, 1.0)
				if (y % 10) < 2:
					_tint(x, y, brick * 0.7, 0.8)  # the brick courses
			var foot := clampf((y - 96.0) / 32.0, 0.0, 1.0)
			_tint(x, y, Color(0.5, 0.45, 0.38), foot * 0.4)
	for i in 5:
		_crack(rng.randi_range(0, N - 1), rng.randi_range(0, N - 1), rng.randi_range(18, 40), 2, Color(0.4, 0.35, 0.28), i % 3 != 2)
	_save("plaster")
