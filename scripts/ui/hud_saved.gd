extends Control
## The small "saved" mark in the bottom-right corner: a diamond and the word, in the menus'
## amber and font. It fades in when the game has written its save (autosave.gd calls
## Hud.show_saved()), stays a moment and fades away. Turn it off with SHOW.

const SHOW := true          ## false: the game still saves, the mark never shows
const FADE_IN := 0.2
const HOLD := 1.2
const FADE_OUT := 0.5
const ALPHA := 0.8

var _tween: Tween
var _word: Label


func _ready() -> void:
	name = "Saved"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -64.0
	offset_top = -26.0
	offset_right = -12.0
	offset_bottom = -12.0
	modulate.a = 0.0
	var word := Label.new()
	word.text = "saved"
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.set_anchors_preset(Control.PRESET_FULL_RECT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.add_theme_font_size_override("font_size", 10)
	word.add_theme_color_override("font_color", MenuFx.BRIGHT)
	word.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
	word.add_theme_constant_override("outline_size", 3)
	add_child(word)
	_word = word


func show_saved() -> void:
	if not SHOW:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", ALPHA, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)


## The diamond, left of the word (MenuFx.ACCENT, like the lock-on mark).
func _draw() -> void:
	var font := _word.get_theme_font("font")
	var word_width := font.get_string_size(_word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var c := Vector2(size.x - word_width - 7.0, size.y * 0.5 + 0.5).round()
	var r := 3.5
	var points := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(points, Color(0.02, 0.02, 0.04, 0.9))
	var inner := PackedVector2Array()
	for p in points:
		inner.append(c + (p - c) * 0.62)
	draw_colored_polygon(inner, MenuFx.ACCENT)
