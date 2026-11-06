extends RefCounted
## Wear strokes for the texture painters (r4_paint_atlas_worn.gd): dirty streaks, rust tails,
## damp blotches, tide lines, chips and cracks, all painted straight into an Image. Every call
## works in image pixels and is clipped to a rectangle; "wrap" lets a streak run off the bottom
## of a tile and back in at its top, for tiles that repeat vertically.
## Kinds: "dark" (dirty water), "rust", "moss".

const TONES := {"dark": Color(0.1, 0.09, 0.1), "rust": Color(0.48, 0.25, 0.11), "moss": Color(0.28, 0.36, 0.18)}

var rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _init(seed_value: int) -> void:
	rng.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = seed_value
	_noise.frequency = 0.08


## Blends the pixel toward the kind's tone by f (0..1), inside the clip only.
func _tint(img: Image, clip: Rect2i, x: int, y: int, kind: String, f: float) -> void:
	if x < clip.position.x or y < clip.position.y or x >= clip.end.x or y >= clip.end.y:
		return
	var tone: Color = TONES[kind]
	img.set_pixel(x, y, img.get_pixel(x, y).lerp(tone, clampf(f, 0.0, 1.0)))


## One streak running down from (x, y): `width` px wide, `length` px long, fading out.
func streak(img: Image, clip: Rect2i, x: int, y: int, width: int, length: int, kind: String, strength: float, wrap := false) -> void:
	for j in length:
		var yy := y + j
		if wrap and yy >= clip.end.y:
			yy = clip.position.y + (yy - clip.end.y) % clip.size.y
		var fade := 1.0 - float(j) / float(length)
		for dx in width:
			var edge := 0.6 if (dx == 0 or dx == width - 1) and width > 2 else 1.0
			_tint(img, clip, x + dx, yy, kind, strength * fade * edge * (0.7 + 0.3 * _noise.get_noise_2d(x + dx, yy)))


## `count` streaks starting along y between x0 and x1, each its own length and width.
func streaks(img: Image, clip: Rect2i, x0: int, x1: int, y: int, count: int, len_min: int, len_max: int,
		w_min: int, w_max: int, kind: String, strength: float, wrap := false) -> void:
	for i in count:
		var wd := rng.randi_range(w_min, w_max)
		var x := rng.randi_range(x0, maxi(x0, x1 - wd))
		streak(img, clip, x, y, wd, rng.randi_range(len_min, len_max), kind, strength * rng.randf_range(0.7, 1.0), wrap)


## Soft blotches from noise over the rect: pixels whose noise (at `freq`) rises past the first
## threshold darken toward the tone, fully by the last. `bias` > 0 keeps them toward the bottom.
## `exclude` rects are left alone (the glass of a window).
func blotch(img: Image, rect: Rect2i, freq: float, thresholds: Array, kind: String, strength: float,
		seed_value: int, bias := 0.0, exclude: Array = [], _pad := 0) -> void:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.seed = seed_value
	n.frequency = freq * 2.5
	var t0: float = thresholds[0]
	var t1: float = thresholds[-1] + 0.3
	for y in range(rect.position.y, rect.end.y):
		var down := float(y - rect.position.y) / maxf(1.0, rect.size.y)
		for x in range(rect.position.x, rect.end.x):
			var skip := false
			for e in exclude:
				if (e as Rect2i).has_point(Vector2i(x, y)):
					skip = true
					break
			if skip:
				continue
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var a := smoothstep(t0, t1, v) * lerpf(1.0, down, bias)
			_tint(img, rect, x, y, kind, strength * a)


## Damp creeping up from the bottom of the rect in a stepped tide line, `height` px at most.
func tide(img: Image, rect: Rect2i, height: int, kind: String, strength: float) -> void:
	for x in range(rect.position.x, rect.end.x):
		var h := int(height * (0.55 + 0.45 * (_noise.get_noise_2d(x * 3.0, rect.position.y) * 0.5 + 0.5)))
		for j in h:
			var y := rect.end.y - 1 - j
			_tint(img, rect, x, y, kind, strength * (1.0 - float(j) / maxf(1.0, h)) * 0.9)


## Small chips: a pale nick with a dark lower edge, `count` of them in the rect.
func chips(img: Image, rect: Rect2i, count: int, size_min: int, size_max: int, strength: float) -> void:
	for i in count:
		var s := rng.randi_range(size_min, size_max)
		var x := rng.randi_range(rect.position.x, maxi(rect.position.x, rect.end.x - s))
		var y := rng.randi_range(rect.position.y, maxi(rect.position.y, rect.end.y - s - 1))
		for dy in s:
			for dx in s:
				var p := img.get_pixel(x + dx, y + dy)
				img.set_pixel(x + dx, y + dy, p.lightened(strength * 0.5))
		for dx in s:
			_tint(img, rect, x + dx, y + s, "dark", strength)


## A thin wandering crack from (x, y), `length` steps in `dir` (a unit Vector2i).
func crack(img: Image, rect: Rect2i, x: int, y: int, length: int, dir: Vector2i, strength: float) -> void:
	var p := Vector2i(x, y)
	for i in length:
		_tint(img, rect, p.x, p.y, "dark", strength)
		if dir.y != 0 and rng.randf() < 0.35:
			p.x += rng.randi_range(-1, 1)
		elif dir.x != 0 and rng.randf() < 0.35:
			p.y += rng.randi_range(-1, 1)
		p += dir


## Rounds every pixel to 32 levels a channel, like paint (and the 15-bit screen).
static func quantise(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(round(c.r * 32.0) / 32.0, round(c.g * 32.0) / 32.0, round(c.b * 32.0) / 32.0))
