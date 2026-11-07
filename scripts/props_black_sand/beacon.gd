@tool
extends Node3D
## A warning beacon: a small glowing lamp that blinks slowly, with a dull light that blinks with
## it. For the tops of posts, masts and rigs, so the dark reads as a working place. Put the node
## where the lamp sits. Every beacon starts at its own point of the blink (from its position),
## so a row of them doesn't flash together.

@export var color := Color(1.0, 0.12, 0.08)  ## dull red
@export var period := 2.4                    ## seconds per blink
@export_range(0.0, 1.0) var on_share := 0.35 ## how much of the period it is lit
@export var size := 0.18                     ## metres across the lamp
@export var light_energy := 0.9
@export var light_range := 7.0

var _lamp := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _mat: ShaderMaterial
var _phase := 0.0


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = size * 0.5
	sphere.height = size
	sphere.radial_segments = 8
	sphere.rings = 4
	_lamp.mesh = sphere
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/ps1_surface.gdshader")
	_mat.set_shader_parameter("albedo_color", color)
	_mat.set_shader_parameter("emission_color", color)
	_mat.set_shader_parameter("emission_energy", 2.0)
	_lamp.material_override = _mat
	_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lamp, false, INTERNAL_MODE_FRONT)
	_light.light_color = color
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.shadow_enabled = false
	add_child(_light, false, INTERNAL_MODE_FRONT)
	var p := global_position if is_inside_tree() else position
	_phase = fposmod(p.x * 0.37 + p.z * 0.61, period)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_phase = fposmod(_phase + delta, period)
	var lit := _phase < period * on_share
	_light.visible = lit
	_mat.set_shader_parameter("emission_energy", 2.0 if lit else 0.15)
