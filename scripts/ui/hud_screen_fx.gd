extends Control
## Full-screen feedback for Aeneas: a red flash at the screen's edges when he is hit, and a
## dark red vignette that pulses while his health is low (faster the lower it gets).
## Built by hud.gd; it never takes mouse clicks.

@export var low_health_share := 0.35   ## the vignette starts below this share of health
@export var vignette_color := Color(0.45, 0.02, 0.03)
@export var hit_color := Color(0.95, 0.12, 0.08)

var low := 0.0           ## 0 = healthy, 1 = nearly dead (how strong the vignette is)
var hit_alpha := 0.0     ## the hit flash right now (tests read it)

var _vignette: TextureRect
var _hit: TextureRect
var _tint: ColorRect
var _clock := 0.0


func _ready() -> void:
	name = "ScreenFx"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = _edge_rect("Vignette", vignette_color, 0.4, 0.95)
	_hit = _edge_rect("HitFlash", hit_color, 0.5, 0.7)
	_tint = ColorRect.new()
	_tint.name = "HitTint"
	_tint.color = Color(hit_color, 0.0)
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	_vignette.modulate.a = 0.0
	_hit.modulate.a = 0.0


## Aeneas lost `share` of his health in one hit (0..1): a bigger hit flashes harder.
func hit(share: float) -> void:
	hit_alpha = clampf(0.5 + share * 1.5, 0.5, 0.9)


## How much health he has (0..1). Below low_health_share the vignette fades in.
func set_health(share: float) -> void:
	low = clampf(1.0 - share / low_health_share, 0.0, 1.0) if share > 0.0 else 1.0


func _process(delta: float) -> void:
	_clock += delta
	hit_alpha = maxf(0.0, hit_alpha - delta * 2.6)  # gone in about a third of a second
	_hit.modulate.a = hit_alpha
	_tint.color.a = hit_alpha * 0.05
	if low > 0.0:
		var beat := 0.5 + 0.5 * sin(_clock * lerpf(3.5, 7.5, low))  # a heartbeat that speeds up
		_vignette.modulate.a = lerpf(0.35, 0.8, low) * lerpf(0.65, 1.0, beat)
	else:
		_vignette.modulate.a = move_toward(_vignette.modulate.a, 0.0, delta * 2.0)


## A full-screen rect, clear in the middle and `color` (up to `strength` opaque) in the corners.
## `clear` is how far out (0..1, centre to corner) the middle stays untouched.
func _edge_rect(node_name: String, color: Color, clear: float, strength: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.0))
	gradient.set_offset(0, clear)
	gradient.set_color(1, Color(color, strength))
	gradient.set_offset(1, 1.0)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.25, 0.5)  # the corners are the far end: sides get about half
	tex.width = 128
	tex.height = 128
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
