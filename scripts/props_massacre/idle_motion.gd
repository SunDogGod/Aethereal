extends Node3D
## A little life for a still prop: put this on a Node3D and make the prop its child.
##   Peck: a bird dips forward now and then (pitch about the node, which sits at its feet).
##   Sway: a hanging lantern, chime or cloth swings slowly (the node sits at the hook).
##   Breathe: a sleeping cat rises and falls.
##   Look round: a sitting cat turns now and then (a small yaw about the node).
## Purely visual; the prop under it must not be solid (a moving body would push).

@export_enum("Peck", "Sway", "Breathe", "Look round") var motion := 1
## 1 = normal; bigger = more.
@export var amount := 1.0
@export var random_seed := 0

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _rest := Basis()
var _rest_scale := Vector3.ONE
var _next := 1.0
var _move := 0.0   # seconds left in a peck or a look
var _yaw_to := 0.0
var _yaw := 0.0


func _ready() -> void:
	_rest = transform.basis
	_rest_scale = scale
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_t = _rng.randf() * 10.0
	_next = _rng.randf_range(0.5, 3.0)


func _process(delta: float) -> void:
	_t += delta
	match motion:
		0: _peck(delta)
		1:
			var a := sin(_t * 1.3) * 0.05 + sin(_t * 0.47) * 0.03
			transform.basis = _rest * Basis(Vector3.FORWARD, a * amount) * Basis(Vector3.RIGHT, sin(_t * 0.9) * 0.03 * amount)
		2:
			scale = _rest_scale * Vector3(1.0, 1.0 + sin(_t * 1.6) * 0.04 * amount, 1.0)
		3: _look(delta)


func _peck(delta: float) -> void:
	_next -= delta
	if _next <= 0.0:
		_move = 0.35
		_next = _rng.randf_range(0.8, 4.0)
	var dip := 0.0
	if _move > 0.0:
		_move -= delta
		dip = sin((0.35 - _move) / 0.35 * PI) * 0.7 * amount
	transform.basis = _rest * Basis(Vector3.RIGHT, dip)


func _look(delta: float) -> void:
	_next -= delta
	if _next <= 0.0:
		_yaw_to = _rng.randf_range(-0.5, 0.5) * amount
		_next = _rng.randf_range(2.0, 6.0)
	_yaw = lerpf(_yaw, _yaw_to, minf(delta * 3.0, 1.0))
	transform.basis = _rest * Basis(Vector3.UP, _yaw)
