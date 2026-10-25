extends Node
## One HUD bar (Aeneas's health and stamina, a locked-on enemy, a boss). It dresses a pair of
## ColorRects, a frame and a fill inside it, and adds a dark back and a pale "damage trail":
## when the bar drops, the fill snaps down at once and the trail lingers where it was for a
## moment, then drains down to it, so you can see how much a hit took. Healing and stamina
## coming back fill up smoothly instead of jumping.
##   var bar := HudBar.dress(frame, fill, Vector2(156, 4), red, amber)
##   bar.set_share(health / max_health)
## (hud.gd preloads this file as HudBar.)

const TRAIL_HOLD := 0.45   ## seconds the trail waits before draining
const TRAIL_SPEED := 0.8   ## how fast the trail drains (bar widths per second)
const REFILL_SPEED := 1.4  ## how fast a heal fills (bar widths per second)
const BORDER := Color(0.45, 0.5, 0.66, 0.55)   ## the frame line (MenuFx.LINE, a touch stronger)
const BACK := Color(0.03, 0.035, 0.06, 0.85)   ## behind the fill (MenuFx.INK)

var frame: ColorRect
var fill: ColorRect
var trail: ColorRect
var back: ColorRect
var inner := Vector2(120, 4)   ## the fill's full size in pixels
var fill_color := Color.WHITE
var pulse := 0.0               ## 0..1: the fill throbs brighter (low health)
var shown := 1.0               ## the share the fill shows right now (0..1)
var target := 1.0              ## the share it is heading for
var trail_share := 1.0

var _hold := 0.0
var _flash := 0.0
var _flash_time := 0.3
var _flash_color := Color.WHITE
var _shake := 0.0
var _home := Vector2.ZERO
var _clock := 0.0


## Builds the extra parts around an existing frame and fill. The frame's own colour becomes
## the border line; the fill keeps its node and name (other scripts may read it).
static func dress(frame_: ColorRect, fill_: ColorRect, inner_: Vector2, fill_color_: Color, trail_color: Color) -> Node:
	var bar: Node = (load("res://scripts/ui/hud_bar.gd") as GDScript).new()
	bar.name = "BarFx"
	bar.frame = frame_
	bar.fill = fill_
	bar.inner = inner_
	bar.fill_color = fill_color_
	frame_.add_child(bar)
	frame_.color = BORDER
	frame_.size = inner_ + Vector2(4, 4)  # 1 px line + 1 px gap on every side
	frame_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.back = ColorRect.new()
	bar.back.name = "Back"
	bar.back.color = BACK
	bar.back.position = Vector2(1, 1)
	bar.back.size = inner_ + Vector2(2, 2)
	bar.back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_.add_child(bar.back)
	frame_.move_child(bar.back, 0)
	bar.trail = ColorRect.new()
	bar.trail.name = "Trail"
	bar.trail.color = trail_color
	bar.trail.position = Vector2(2, 2)
	bar.trail.size = inner_
	bar.trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_.add_child(bar.trail)
	frame_.move_child(bar.trail, 1)
	fill_.position = Vector2(2, 2)
	fill_.size = inner_
	fill_.color = fill_color_
	fill_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_.move_child(fill_, 2)
	# A one-pixel highlight along the top of the fill, so it reads as a lit tube, not a stripe.
	var shine := ColorRect.new()
	shine.name = "Shine"
	shine.color = Color(1, 1, 1, 0.28)
	shine.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shine.offset_bottom = 1.0
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_.add_child(shine)
	bar._home = frame_.position
	return bar


## Where the bar should be (0..1). Drops show at once with a trail; rises fill smoothly.
## `instant` jumps straight there (a new target, a fresh bar).
func set_share(share: float, instant := false) -> void:
	share = clampf(share, 0.0, 1.0)
	if instant:
		shown = share
		target = share
		trail_share = share
		_hold = 0.0
	elif share < shown:
		trail_share = maxf(trail_share, shown)
		shown = share
		target = share
		_hold = TRAIL_HOLD
	else:
		target = share
	_layout()


## The frame lights up in `color` and fades back over `seconds`. With `shake`, it jolts too.
func flash(color: Color, seconds := 0.35, shake := 0.0) -> void:
	_flash_color = color
	_flash_time = seconds
	_flash = seconds
	_shake = maxf(_shake, shake)


## Where the frame rests when it isn't shaking (call after moving the frame).
func set_home(at: Vector2) -> void:
	_home = at
	frame.position = at


func _process(delta: float) -> void:
	_clock += delta
	if shown < target:
		shown = minf(target, shown + REFILL_SPEED * delta)
	if _hold > 0.0:
		_hold -= delta
	elif trail_share > shown:
		trail_share = maxf(shown, trail_share - TRAIL_SPEED * delta)
	trail_share = maxf(trail_share, shown)
	# The frame flash and the shake.
	var t := 0.0 if _flash <= 0.0 else _flash / _flash_time
	_flash = maxf(0.0, _flash - delta)
	frame.color = BORDER.lerp(_flash_color, t)
	back.color = BACK.lerp(Color(_flash_color, 0.9), t * 0.45)  # the empty part blushes too
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 12.0)
		frame.position = _home + Vector2(roundf(sin(_clock * 70.0) * _shake), 0.0)
	else:
		frame.position = _home
	# Low health: the fill throbs brighter, faster the lower it is.
	var glow := 0.0
	if pulse > 0.0:
		glow = pulse * (0.5 + 0.5 * sin(_clock * lerpf(5.0, 10.0, pulse)))
	fill.color = fill_color.lerp(Color(1, 0.85, 0.75), glow * 0.45 + t * 0.35)
	_layout()


func _layout() -> void:
	fill.size = Vector2(roundf(inner.x * shown), inner.y)
	trail.size = Vector2(roundf(inner.x * trail_share), inner.y)
	trail.visible = trail.size.x > fill.size.x
