@tool
extends Block
## A console screen that is still running in a dead station. Put it on a thin Block with a screen
## material (materials/vacuum_station_screen.tres). Scrolling: the glyph lines roll up one line at
## a time. Blinking: the readout blinks on and off. Faulty: mostly dark, it stutters on now and then.
## The material is duplicated at runtime only (set_runtime_material), so the scene keeps the shared
## file and no two screens are in step. In the editor it stays a plain Block.

@export_enum("Scrolling", "Blinking", "Faulty") var mode := 0
## Seconds between steps (a scrolled line, a blink).
@export var step_every := 0.7
## 0 = a different pattern every run; any other number repeats the same one.
@export var random_seed := 0

const LINE := 0.125  # one glyph line of the 8-line screen texture, in UV

var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _base_energy := 1.0
var _left := 0.0
var _scroll := 0.0
var _on := true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not material is ShaderMaterial:
		return
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_mat = material.duplicate()
	set_runtime_material(_mat)
	var e: Variant = _mat.get_shader_parameter("emission_energy")
	_base_energy = float(e) if e != null else 1.0
	_left = _rng.randf_range(0.0, step_every)
	_scroll = _rng.randi_range(0, 7) * LINE
	_mat.set_shader_parameter("uv_offset", Vector2(0, _scroll))
	if mode == 2:
		_set_on(false)


func _process(delta: float) -> void:
	if _mat == null or Engine.is_editor_hint():
		return
	_left -= delta
	if _left > 0.0:
		return
	match mode:
		0:
			_left = step_every * _rng.randf_range(0.6, 1.6)
			_scroll = fposmod(_scroll + LINE, 1.0)
			_mat.set_shader_parameter("uv_offset", Vector2(0, _scroll))
		1:
			_left = step_every
			_set_on(not _on)
		2:
			if _on:
				_set_on(false)
				_left = _rng.randf_range(1.5, 6.0)
			else:
				_set_on(true)
				_left = _rng.randf_range(0.05, 0.35)


func _set_on(on: bool) -> void:
	_on = on
	_mat.set_shader_parameter("emission_energy", _base_energy if on else 0.0)
	_mat.set_shader_parameter("albedo_color", Color(1, 1, 1) if on else Color(0.25, 0.3, 0.32))
