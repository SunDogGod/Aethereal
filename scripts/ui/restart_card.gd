extends Label
## The restart card (SPOTTED / SLAIN / FELL) on the StealthDirector's Screen. The director
## only sets this label's text and shows or hides it; this script makes it a card: a dark
## band across the middle of the screen, thin lines above and below, and the word drawing
## its letters together as it fades in. The colours are in the Inspector.

@export var spotted_color := Color(1.0, 0.62, 0.3)   ## amber-orange: seen
@export var slain_color := Color(0.86, 0.16, 0.12)   ## deep red: killed in a fight
@export var fell_color := Color(0.72, 0.78, 0.95)    ## cold pale blue: a fatal drop
@export var subtitle := "back to the last checkpoint"  ## the small line under the word ("" for none)
@export var spacing_from := 26   ## letter spacing as the card appears...
@export var spacing_to := 14     ## ...and where it settles

var _font: FontVariation
var _band: TextureRect
var _top: TextureRect
var _bottom: TextureRect
var _sub: Label
var _tween: Tween


func _ready() -> void:
	_font = FontVariation.new()
	_font.base_font = get_theme_default_font()
	_font.spacing_glyph = spacing_to
	add_theme_font_override("font", _font)
	add_theme_font_size_override("font_size", 30)
	add_theme_constant_override("outline_size", 2)
	add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 1))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	add_theme_constant_override("shadow_offset_y", 3)
	add_theme_constant_override("shadow_offset_x", 0)
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The word sits a little above the middle of the band, leaving room for the subtitle.
	var pad := StyleBoxEmpty.new()
	pad.content_margin_bottom = 16.0
	add_theme_stylebox_override("normal", pad)
	_band = _strip("Band", Color(0.01, 0.01, 0.02, 0.86), 0.0, 1.0, 0.0, 0.0)
	_band.show_behind_parent = true
	_top = _strip("LineTop", Color.WHITE, 0.0, 0.0, -1.0, 0.0)
	_bottom = _strip("LineBottom", Color.WHITE, 1.0, 1.0, 0.0, 1.0)
	_sub = Label.new()
	_sub.name = "Subtitle"
	_sub.add_theme_font_size_override("font_size", 9)
	_sub.add_theme_color_override("font_color", Color(0.62, 0.66, 0.76, 0.9))  # MenuFx.DIM
	var sub_font := FontVariation.new()
	sub_font.base_font = get_theme_default_font()
	sub_font.spacing_glyph = 2
	_sub.add_theme_font_override("font", sub_font)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub.offset_left = -200.0
	_sub.offset_right = 200.0
	_sub.offset_top = -24.0
	_sub.offset_bottom = -10.0
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if not visible:
		return
	var color := spotted_color
	if text == "SLAIN":
		color = slain_color
	elif text == "FELL":
		color = fell_color
	add_theme_color_override("font_color", color)
	_top.modulate = Color(color, 0.0)
	_bottom.modulate = Color(color, 0.0)
	_sub.text = subtitle
	modulate.a = 0.0
	_font.spacing_glyph = spacing_from
	_top.scale.x = 0.2
	_bottom.scale.x = 0.2
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)
	_tween.tween_method(func(s: float) -> void: _font.spacing_glyph = roundi(s), float(spacing_from), float(spacing_to), 0.7)
	_tween.tween_property(_top, "scale:x", 1.0, 0.6)
	_tween.tween_property(_bottom, "scale:x", 1.0, 0.6)
	_tween.tween_property(_top, "modulate:a", 0.8, 0.4)
	_tween.tween_property(_bottom, "modulate:a", 0.8, 0.4)


## A full-width strip (anchored to the label from `a_top` to `a_bottom`, plus pixel offsets),
## fading out toward the screen's left and right edges.
func _strip(node_name: String, color: Color, a_top: float, a_bottom: float, top: float, bottom: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 64
	tex.height = 1
	var strip := TextureRect.new()
	strip.name = node_name
	strip.texture = tex
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	strip.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	strip.anchor_top = a_top
	strip.anchor_bottom = a_bottom
	strip.offset_top = top
	strip.offset_bottom = bottom
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	strip.resized.connect(func() -> void: strip.pivot_offset = strip.size * 0.5)
	return strip
