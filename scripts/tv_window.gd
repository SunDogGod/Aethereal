@tool
extends Block
## A window with a television on behind it: the glow cuts between blues and whites every
## 0.4-3 s, goes black now and then, and no two screens are in step.
## Put it on a thin Block (the "screen") whose material is a ShaderMaterial with emission
## (e.g. materials/window_glow.tres). The material is duplicated here so each screen is
## independent of the others.

## 0 = a different programme every run; any other number repeats the same one.
@export var random_seed := 0
## How bright the screen glows at most.
@export var brightness := 1.4

# TV light: cold blues, washed whites, the odd warm cut.
const PALETTE: Array[Color] = [
	Color(0.35, 0.5, 1.0), Color(0.75, 0.85, 1.0), Color(0.2, 0.3, 0.8), Color(0.95, 0.95, 1.0),
	Color(0.5, 0.7, 1.0), Color(0.15, 0.2, 0.45), Color(0.6, 0.6, 0.7), Color(0.9, 0.7, 0.5),
]

var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _left := 0.0        # seconds until the next cut
var _flicker := 0.0     # fast brightness wobble, per shot


func _ready() -> void:
	if Engine.is_editor_hint():
		return  # in the editor it stays a plain Block: no flicker while you place it
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	if not material is ShaderMaterial:
		push_warning("TV window '%s' needs a ShaderMaterial with emission (e.g. window_glow.tres)" % name)
		return
	_mat = material.duplicate()
	set_runtime_material(_mat)  # its own copy, shown at runtime only (the scene keeps the shared file)
	_mat.set_shader_parameter("albedo_color", Color(0.12, 0.13, 0.16))
	_cut()


func _process(delta: float) -> void:
	if _mat == null or Engine.is_editor_hint():
		return
	_left -= delta
	if _left <= 0.0:
		_cut()
	# A little scanline shimmer so a long shot still looks alive.
	var e := brightness * (1.0 + _flicker * sin(Time.get_ticks_msec() * 0.03))
	_mat.set_shader_parameter("emission_energy", e)


## The next shot: a new colour (or black), a new length.
func _cut() -> void:
	_left = _rng.randf_range(0.4, 3.0)
	_flicker = _rng.randf_range(0.0, 0.08)
	if _rng.randf() < 0.1:
		_mat.set_shader_parameter("emission_color", Color.BLACK)
		_left = _rng.randf_range(0.3, 1.2)
		return
	var c: Color = PALETTE[_rng.randi_range(0, PALETTE.size() - 1)]
	c = c.lerp(Color.WHITE, _rng.randf_range(0.0, 0.25)) * _rng.randf_range(0.7, 1.0)
	_mat.set_shader_parameter("emission_color", c)
