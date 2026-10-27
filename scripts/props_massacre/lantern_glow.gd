extends OmniLight3D
## A paper lantern's light: a candle inside, so it breathes, never steady and never failing
## (flicker_light.gd is for broken lamps). Put it on an OmniLight3D. Only the energy changes.

## How much the flame wavers (0.1 = ±10 %).
@export var waver := 0.12
## 0 = a different pattern every run; any other number repeats the same pattern.
@export var random_seed := 0

var _base := 1.0
var _t := 0.0
var _phase := Vector3.ZERO
var _gust := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_base = light_energy
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_phase = Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * 50.0


func _process(delta: float) -> void:
	_t += delta
	# Three slow waves and now and then a small gust that dips the flame.
	var w := sin(_t * 1.7 + _phase.x) * 0.5 + sin(_t * 4.3 + _phase.y) * 0.3 + sin(_t * 9.1 + _phase.z) * 0.2
	if _gust <= 0.0 and _rng.randf() < delta * 0.08:
		_gust = 0.6
	_gust = maxf(_gust - delta, 0.0)
	var dip := sin(_gust / 0.6 * PI) * 0.25 if _gust > 0.0 else 0.0
	light_energy = _base * (1.0 + w * waver - dip)
