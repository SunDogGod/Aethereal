extends Node
## A life sign: makes something's glow breathe, blink or flicker, and an optional light with it.
## Put this node anywhere and point Target at the thing that glows:
##  - a Block: its material is copied and shown with set_runtime_material (the scene keeps the file);
##  - a MeshInstance3D: its material_override is copied;
##  - a prop built in code (sand_prop.gd, sand_arch.gd...): every surface that uses Material is
##    swapped for one copy.
## Breathe: a slow swell (the arch). Blink: on/off like a warning beacon. Fire: a restless flicker.

@export_enum("Breathe", "Blink", "Fire") var mode := 0
@export var target: NodePath
## For props built in code: which of their materials glows (e.g. precursor_light.tres).
@export var material: Material
@export var light: NodePath  ## optional OmniLight3D that brightens and dims along with it
@export var period := 4.0  ## seconds per breath or blink
@export_range(0.0, 1.0) var low := 0.35  ## the dimmest point, as a share of full glow
@export_range(0.05, 0.95) var duty := 0.2  ## Blink: share of the period the lamp is lit
@export var phase := 0.0  ## seconds, so neighbouring beacons don't blink together

var _mat: ShaderMaterial
var _base_glow := 0.0
var _light: Light3D
var _base_energy := 0.0
var _t := 0.0
var _fire := 1.0
var _cur := 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_t = phase
	var node := get_node_or_null(target)
	if node:
		_take_material(node)
	_light = get_node_or_null(light) as Light3D
	if _light:
		_base_energy = _light.light_energy


func _take_material(node: Node) -> void:
	if node.has_method("set_runtime_material") and node.get("material") is ShaderMaterial:
		_mat = node.material.duplicate()
		node.set_runtime_material(_mat)
	elif node is GeometryInstance3D and node.material_override is ShaderMaterial:
		_mat = node.material_override.duplicate()
		node.material_override = _mat
	elif material is ShaderMaterial:
		_mat = material.duplicate()
		for child in node.get_children(true):
			if child is MeshInstance3D and child.mesh:
				for i in child.mesh.get_surface_count():
					if child.mesh.surface_get_material(i) == material:
						child.set_surface_override_material(i, _mat)
	if _mat:
		_base_glow = float(_mat.get_shader_parameter("emission_energy"))


func _process(delta: float) -> void:
	_t += delta
	var k := 1.0
	match mode:
		0:
			k = lerpf(low, 1.0, 0.5 + 0.5 * sin(_t / period * TAU))
		1:
			k = 1.0 if fposmod(_t, period) < period * duty else low
		2:
			# Drift toward a new random brightness a few times a second: embers, not a strobe.
			if _rng.randf() < delta * 9.0:
				_fire = _rng.randf_range(low, 1.0)
			_cur = lerpf(_cur, _fire, minf(1.0, delta * 12.0))
			k = _cur
	if _mat:
		_mat.set_shader_parameter("emission_energy", _base_glow * k)
	if _light:
		_light.light_energy = _base_energy * k
