@tool
extends StaticBody3D
## The bonfire in the middle of the hall: a pyre where the Agency burns the villagers' bodies.
## A ring of broken concrete and scrap, an ember bed, a low crib of charred beams, and on and in it
## the bodies (hall_figure.gd: heads, limbs and trunks, wrapped in sheets, most of them charred
## black, one arm stiff up out of the flames), a soot stain on the floor, and the fire itself:
## layered flame tongues, sparks and smoke (hall_fire_fx.gd). The ring is solid: a cylinder of
## collision, so fights path round it (the navmesh is baked with it).
## While the game runs, the light named in `light` flickers with the flames. When the story hides
## one of the waiting bodies (a hall_body.gd under `bodies`), the fire flares and the Black Cube's
## aura (`aura`, hall_aura.gd) takes the soul and gives it to the captain.
## For scenes: flare(strength) for a flare-up, throw_in(node) to carry anything into the fire,
## bend(toward, seconds) to draw the flames toward a point (the cube taking Isabella's soul).

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const FireFx := preload("res://scripts/vfx/hall_fire_fx.gd")
const HallFigure := preload("res://scripts/vfx/hall_figure.gd")
const SOOT := preload("res://textures/decal_soot.png")
const PYRE_LAYERS := 3
const PYRE_TOP := 0.22 + (PYRE_LAYERS - 1) * 0.16 + 0.065  # metres: where the bodies lie
const M := {
	stone = preload("res://materials/concrete_dark_worn.tres"), concrete = preload("res://materials/concrete_worn.tres"),
	rust = preload("res://materials/pipe_rust.tres"), metal = preload("res://materials/metal_worn.tres"),
	embers = preload("res://materials/hall_embers.tres"), charcoal = preload("res://materials/hall_charcoal.tres"),
	charred = preload("res://materials/hall_charred.tres"),
	soiled = preload("res://materials/hall_shroud_soiled.tres"),
}
## The bodies on the pyre: [x, y, z, yaw, tilt (about the body's own length), soiled (only caught,
## not yet black), pose]. Laid crosswise and on top of each other, one slid half off the side.
const PYRE := [
	[-0.15, PYRE_TOP, 0.2, 0.35, 0.0, false, {}],
	[0.25, PYRE_TOP + 0.16, -0.25, 1.95, 0.12, false, {arm_l = 3, knee_r = 0.4}],
	[0.85, 0.36, 0.6, -0.85, -0.35, true, {arm_r = 1, head_turn = 0.4}],
	[-0.75, PYRE_TOP - 0.05, -0.45, -1.2, 0.25, false, {knee_l = 0.6, arm_r = 2}],
	[-0.25, PYRE_TOP + 0.3, -0.05, 2.9, -0.1, true, {}],
	# Two laid on from the edge, heads in the flames and legs out over the stones.
	[0.6, 0.4, 1.0, 0.52, 0.15, true, {knee_r = 0.3}],
	[-1.08, 0.38, 0.39, -1.22, -0.2, false, {arm_l = 1}],
]

## Metres from the centre to the middle of the ring of stones.
@export var radius := 1.55:
	set(value):
		radius = value
		_rebuild()
## Bodies burning on the pyre (0 to 7).
@export_range(0, 7) var burning_bodies := 7:
	set(value):
		burning_bodies = value
		_rebuild()
## The light the fire throws (an OmniLight3D); it flickers with the flames while the game runs.
@export var light: NodePath
## The Black Cube's aura (hall_aura.gd): it takes the soul when a body goes on the fire.
@export var aura: NodePath
## The node holding the waiting bodies (hall_body.gd): hiding one counts as throwing it on.
@export var bodies: NodePath
## 1 = burning steadily. Higher is a bigger fire (flare() adds to it for a moment).
@export var intensity := 1.0

var _mesh := MeshInstance3D.new()
var _shape := CollisionShape3D.new()
var _decal := Decal.new()
var _flames: Array[MeshInstance3D] = []
var _flame_mat: ShaderMaterial
var _embers: GPUParticles3D
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)
var _light: OmniLight3D
var _light_base := 0.0
var _flare := 0.0
var _time := 0.0
var _bend_to := Vector3.ZERO
var _bend := 0.0        # 0..1 how far the flames lean toward _bend_to
var _bend_hold := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	add_child(_shape, false, INTERNAL_MODE_FRONT)
	add_child(_decal, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _ready() -> void:
	if not _flames.is_empty():
		return  # back in the tree after a move: already built
	_flame_mat = FireFx.FLAME.duplicate()  # this fire's own copy: flare() changes it
	_flames = FireFx.flames(self, radius - 0.35, 0.45, _flame_mat)
	_embers = FireFx.embers(self, radius - 0.4, 0.5)
	FireFx.smoke(self, radius - 0.4, 0.5, 8.0)
	if Engine.is_editor_hint():
		return
	_rng.randomize()
	_light = get_node_or_null(light) as OmniLight3D
	if _light:
		_light_base = _light.light_energy
	var holder := get_node_or_null(bodies)
	if holder:
		for b in holder.get_children():
			if b.has_signal("thrown"):
				b.thrown.connect(_on_body_thrown)


func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var pm := PropMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6151
	_ring(pm, rng)
	_heap(pm, rng)
	# The bodies: the lowest are black already; the newest have only caught (the sheet still pale).
	for i in mini(burning_bodies, PYRE.size()):
		var p: Array = PYRE[i]
		var xf := Transform3D(Basis(Vector3.UP, p[3]) * Basis(Vector3.FORWARD, p[4]), Vector3(p[0], p[1], p[2]))
		var cloth: Material = M.soiled if p[5] else M.charred
		HallFigure.add(pm, xf, 1.65, {cloth = cloth, rope = null}, p[6], rng)
	_mesh.mesh = pm.commit()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cyl := CylinderShape3D.new()
	cyl.radius = radius + 0.25
	cyl.height = 1.2
	_shape.shape = cyl
	_shape.position = Vector3(0, 0.6, 0)
	_decal.texture_albedo = SOOT
	_decal.size = Vector3(radius * 4.4, 1.0, radius * 4.4)
	_decal.position = Vector3(0, 0.1, 0)
	_decal.cull_mask = 1
	_decal.upper_fade = 0.0
	_decal.lower_fade = 0.0
	_decal.modulate = Color(1, 1, 1, 0.9)


## Broken concrete and scrap set in a ring, leaning in or out a little.
func _ring(pm: PropMesh, rng: RandomNumberGenerator) -> void:
	var n := 15
	for i in n:
		var a := TAU * (i + rng.randf_range(-0.15, 0.15)) / n
		var at := Vector3(cos(a), 0.0, sin(a)) * (radius + rng.randf_range(-0.05, 0.08))
		var face := Basis(Vector3.UP, -a + PI / 2)  # long side along the ring
		var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.2)) * Basis(Vector3.FORWARD, rng.randf_range(-0.15, 0.15))
		if i % 4 == 3:
			# A bent sheet of scrap standing on edge, and a pipe stub leaning on it.
			pm.box(M.rust, Vector3(0.62, 0.48, 0.04), Transform3D(face * tilt, at + Vector3(0, 0.22, 0)))
			pm.cyl(M.metal, 0.05, 0.05, 0.55, Transform3D(face * Basis(Vector3.FORWARD, 1.2), at + Vector3(0, 0.12, 0)), 6)
		else:
			var s := Vector3(rng.randf_range(0.5, 0.7), rng.randf_range(0.3, 0.45), rng.randf_range(0.3, 0.42))
			pm.box(M.stone if i % 3 else M.concrete, s, Transform3D(face * tilt, at + Vector3(0, s.y * 0.45, 0)))


## The ember bed, and a low crib stacked crosswise from the town's beams and broken furniture,
## so the bodies laid on it show against the flames.
func _heap(pm: PropMesh, rng: RandomNumberGenerator) -> void:
	var bed := radius - 0.2
	pm.cyl(M.embers, bed, bed + 0.05, 0.16, Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)), 14)
	var half := bed * 0.78
	for layer in PYRE_LAYERS:
		var y := 0.22 + layer * 0.16
		var across := layer % 2 == 0
		for k in 4:
			var off := lerpf(-half * 0.8, half * 0.8, k / 3.0) + rng.randf_range(-0.06, 0.06)
			var span := half * 2.0 * rng.randf_range(0.85, 1.05) * (1.0 - layer * 0.07)
			var c := Vector3(0, y, off) if across else Vector3(off, y, 0)
			var turn := Basis(Vector3.UP, rng.randf_range(-0.14, 0.14) + (0.0 if across else PI / 2))
			pm.box(M.charred if (k + layer) % 3 == 0 else M.charcoal, Vector3(span, 0.13, 0.15), Transform3D(turn, c))
	# Things thrown on: a door slab leaning in, beams poking out at angles.
	pm.box(M.charcoal, Vector3(0.75, 1.5, 0.06), Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, 0.75), Vector3(-0.85, 0.5, -0.75)))
	for i in 4:
		var a := TAU * (i + rng.randf_range(-0.2, 0.2)) / 4.0
		var foot := Vector3(cos(a), 0, sin(a)) * bed * 0.85 + Vector3(0, 0.2, 0)
		var tip := Vector3(cos(a + 0.4), 0, sin(a + 0.4)) * bed * 0.3 + Vector3(0, rng.randf_range(1.1, 1.5), 0)
		pm.stick(M.charcoal, foot, tip, rng.randf_range(0.08, 0.12))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_flare = maxf(_flare - delta * 0.6, 0.0)
	if _bend_hold > 0.0:
		_bend_hold -= delta
		_bend = minf(_bend + delta * 1.2, 1.0)
	else:
		_bend = maxf(_bend - delta * 0.5, 0.0)
	var level := intensity + _flare
	# Fire light: two slow swells and a fast flutter, never steady, never strobing.
	var flicker := 0.84 + 0.08 * sin(_time * 7.3) * sin(_time * 2.9 + 1.0) + 0.06 * sin(_time * 17.0 + sin(_time * 3.1) * 2.0)
	flicker += _rng.randf_range(-0.03, 0.03)
	if _light:
		_light.light_energy = _light_base * flicker * (0.4 + 0.6 * level) * (1.0 + 0.5 * _flare)
	_flame_mat.set_shader_parameter("intensity", level)
	var lean := Vector2.ZERO
	if _bend > 0.0:
		var to := _bend_to - global_position
		var flat := Vector2(to.x, to.z).normalized() if Vector2(to.x, to.z).length() > 0.1 else Vector2.ZERO
		lean = flat * _bend * (2.2 + 0.4 * sin(_time * 5.0))
	_flame_mat.set_shader_parameter("lean", lean)
	for q in _flames:
		q.scale.y = float(q.get_meta("base_height")) * (0.8 + 0.2 * level)
	if _embers:
		_embers.amount_ratio = clampf(0.55 + 0.45 * _flare, 0.0, 1.0)


## The fire leaps up for a couple of seconds (a body thrown on, a story beat). 1 = a body.
func flare(strength := 1.0) -> void:
	_flare = maxf(_flare, strength)


## The flames lean toward `toward` (a world point) for `seconds`, then straighten.
func bend(toward: Vector3, seconds := 4.0) -> void:
	_bend_to = toward
	_bend_hold = maxf(_bend_hold, seconds)
	flare(2.0)


## Carries any node in an arc onto the fire, hides it, then flares; the cube takes the soul.
func throw_in(node: Node3D, seconds := 0.9) -> void:
	if node == null:
		return
	var from := node.global_position
	var to := global_position + Vector3(0, 0.6, 0)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		node.global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 1.4, 0), 0.0, 1.0, seconds)
	tw.tween_callback(func() -> void:
		node.visible = false
		if not node.has_signal("thrown"):  # a hall_body reports its own throw
			_taken())


func _on_body_thrown(_body: Node3D) -> void:
	_taken()


## A body is on the fire: it flares, and the cube takes the soul and gives it to the captain.
func _taken() -> void:
	flare(1.0)
	var a := get_node_or_null(aura)
	if a and a.has_method("take"):
		a.take(self, 1.0, a.receiver_node())
