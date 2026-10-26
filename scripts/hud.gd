extends CanvasLayer
## Aeneas's HUD. From player.tscn: the prompt line at the bottom (takedowns, look-at
## prompts), the health and stamina bars (top left) and the lock-on mark. Built here in code,
## from the files in scripts/ui/ named hud_*:
##   hud_bar.gd        the bars' frame, damage trail and smooth refill
##   hud_screen_fx.gd  the red flash when he is hit, the pulsing low-health vignette
##   hud_target.gd     the locked-on enemy's name and bar, the boss bar at the bottom
##   hud_hints.gd      one-time control hints
##   hud_prompt.gd     how the prompt line looks
## Everything fades out while a story scene plays.

const HudBar := preload("res://scripts/ui/hud_bar.gd")
const HudScreenFx := preload("res://scripts/ui/hud_screen_fx.gd")
const HudTarget := preload("res://scripts/ui/hud_target.gd")
const HudHints := preload("res://scripts/ui/hud_hints.gd")
## Off: the author asked for no floating tutorial text (2026-10-25). Turn on to bring the hints back.
const SHOW_HINTS := false
const HudPrompt := preload("res://scripts/ui/hud_prompt.gd")

const HEALTH_RED := Color(0.8, 0.2, 0.17)
const STAMINA_GREEN := Color(0.44, 0.72, 0.38)
const TRAIL := Color(1.0, 0.76, 0.4)            ## MenuFx.ACCENT: what a hit just took
const HEALTH_SIZE := Vector2(156, 4)            ## the fill at full, in pixels
const STAMINA_SIZE := Vector2(116, 3)
const LOW_STAMINA := 15.0  ## below this a swing or roll can fail (the hardest swing needs 15)

@onready var prompt: Label = $Prompt
@onready var health_bar: ColorRect = $Bars/Health/Fill
@onready var stamina_bar: ColorRect = $Bars/Stamina/Fill
@onready var bars: Control = $Bars
@onready var lock_mark: Label = $LockMark

var health: Node              ## the health bar's HudBar
var stamina: Node             ## the stamina bar's HudBar
var screen_fx: Control
var targets: Control
var hints: Control
var prompt_view: PanelContainer
var stamina_denials := 0      ## how often he tried to act without the stamina (tests read it)

var _lock_target: Node3D
var _takedown_showing := false  ## the takedown prompt owns the line while it shows
var _player: Node
var _combat: Node
var _last_health := -1.0
var _attempt := 0               # physics frames left to see whether a press spent stamina
var _attempt_stamina := 0.0
var _clock := 0.0


func _ready() -> void:
	_player = get_parent()
	_combat = _player.get_node_or_null("Combat")
	screen_fx = HudScreenFx.new()
	add_child(screen_fx)
	move_child(screen_fx, 0)  # under everything else
	bars.position = Vector2(14, 14)
	health = HudBar.dress($Bars/Health, health_bar, HEALTH_SIZE, HEALTH_RED, TRAIL)
	stamina = HudBar.dress($Bars/Stamina, stamina_bar, STAMINA_SIZE, STAMINA_GREEN, Color(0.9, 0.95, 0.75))
	stamina.set_home(Vector2(0, 10))
	targets = HudTarget.new()
	add_child(targets)
	if SHOW_HINTS:
		hints = HudHints.new()
		hints.player = _player
		hints.combat = _combat
		hints.prompt = prompt
		add_child(hints)
	prompt_view = HudPrompt.new()
	prompt.add_child(prompt_view)
	prompt.self_modulate.a = 0.0  # the label keeps the text; PromptView draws it
	lock_mark.add_theme_color_override("font_color", MenuFx.ACCENT)
	lock_mark.add_theme_font_size_override("font_size", 14)
	lock_mark.visible = false
	if _combat:
		_combat.health_changed.connect(_on_health)
		_combat.stamina_changed.connect(_on_stamina)
		_combat.lock_changed.connect(_on_lock)
		_last_health = _combat.health
		health.set_share(_combat.health / _combat.max_health, true)
		stamina.set_share(_combat.stamina / _combat.max_stamina, true)


func _process(delta: float) -> void:
	_clock += delta
	# Story scenes get the whole screen: the HUD fades out and comes back after.
	var in_scene: bool = _player.get("in_cutscene") == true
	var alpha := move_toward(bars.modulate.a, 0.0 if in_scene else 1.0, delta * 4.0)
	bars.modulate.a = alpha
	targets.modulate.a = alpha
	screen_fx.modulate.a = alpha
	prompt_view.modulate.a = move_toward(prompt_view.modulate.a, 1.0, delta * 8.0) if prompt.visible else 0.0
	if is_instance_valid(_lock_target):
		var camera := get_viewport().get_camera_3d()
		var point: Vector3 = _lock_target.global_position + Vector3.UP * 1.3
		lock_mark.visible = camera != null and not camera.is_position_behind(point) and not in_scene
		if lock_mark.visible:
			lock_mark.pivot_offset = lock_mark.size * 0.5
			lock_mark.scale = Vector2.ONE * (1.0 + 0.12 * sin(_clock * 6.0))  # a slow throb
			lock_mark.position = (camera.unproject_position(point) - lock_mark.size * 0.5).round()
	else:
		lock_mark.visible = false


## Watches for a swing, heavy swing or roll that failed for want of stamina: the press came,
## nothing was spent, and he was low. Then the stamina bar flashes.
func _physics_process(_delta: float) -> void:
	if _combat == null or _player.get("controls_enabled") == false:
		_attempt = 0
		return
	if _attempt > 0:
		_attempt -= 1
		if _combat.stamina < _attempt_stamina - 0.5 or _combat.move != PlayerCombat.Move.NONE:
			_attempt = 0  # it went through
		elif _attempt == 0:
			stamina_denied()
		return
	if _combat.stamina >= LOW_STAMINA or _combat.erupting or _player.get("is_crouched") == true:
		return
	var tried := Input.is_action_just_released("attack") or Input.is_action_just_pressed("heavy_attack") \
			or (_combat.lock_target != null and Input.is_action_just_pressed("jump"))
	if tried and _combat.move == PlayerCombat.Move.NONE:
		_attempt = 3
		_attempt_stamina = _combat.stamina


## The stamina bar flashes red and jolts: not enough stamina for that.
func stamina_denied() -> void:
	stamina_denials += 1
	stamina.flash(Color(1.0, 0.35, 0.3), 0.5, 2.0)


## The takedown prompt (Takedown's prompt_changed signal). It wins over hints.
func show_prompt(text: String) -> void:
	_takedown_showing = text != ""
	prompt.text = text
	prompt.visible = text != ""
	prompt_view.show_text(text)


## A softer prompt from an Interactable ("E / Up: Look at the well"), on the same line
## but never over a takedown prompt, so the two can't fight. "" hides it.
func show_hint(text: String) -> void:
	if _takedown_showing:
		return
	prompt.text = text
	prompt.visible = text != ""
	prompt_view.show_text(text)
	if text != "":
		if hints:
			hints.trigger("look")


func _on_health(value: float, max_value: float) -> void:
	var share := value / max_value
	if _last_health >= 0.0 and value < _last_health - 0.01:
		screen_fx.hit((_last_health - value) / max_value)
		health.flash(Color(1.0, 0.55, 0.45), 0.3, 2.0)
	_last_health = value
	health.set_share(share)
	screen_fx.set_health(share)
	health.pulse = screen_fx.low


func _on_stamina(value: float, max_value: float) -> void:
	stamina.set_share(value / max_value)
	if value <= max_value * 0.05:
		if hints:
			hints.trigger("stamina")  # ran dry: once, ever, explain the refill


func _on_lock(target: Node3D) -> void:
	_lock_target = target
	targets.lock_target = target
