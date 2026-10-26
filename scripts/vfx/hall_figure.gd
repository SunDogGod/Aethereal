extends RefCounted
## A dead villager's shape, built from simple pieces into a PropMesh (for hall_body.gd, and for the
## bodies already burning on the bonfire, hall_bonfire.gd). Shown restrained: no faces, no wounds.
## The figure lies along its local Z axis, head toward -Z, origin on the floor, about 1.7 m long:
## a head, a neck, chest, belly and hips, two arms (upper arm, forearm, hand) and two legs (thigh,
## shin, foot), so it reads as a person even wrapped in a sheet or charred black.
##   add(pm, xf, length, look, pose, rng)
## look: {skin, cloth, tunic, trousers, hair, rope} materials. A shrouded body uses `cloth` for all
##       of it (rope ties at the neck, chest, knees and ankles; no rope when it is burnt through).
##       A clothed villager (`tunic` set) lies face down: tunic, trousers, bare forearms, hair.
## pose: {arm_l, arm_r: 0 = at the side, 1 = flung out, 2 = bent up by the head, 3 = raised up
##        (stiff, out of the fire); knee_l, knee_r: 0..1 how far the knee is drawn up;
##        head_turn: radians}.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")


static func add(pm: PropMesh, xf: Transform3D, length: float, look: Dictionary, pose: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var k := length / 1.7
	var at := xf * Transform3D(Basis.from_scale(Vector3(k, k, k)), Vector3.ZERO)
	var clothed: bool = look.get("tunic") != null
	var body: Material = look.tunic if clothed else look.cloth
	var limb_top: Material = body
	var limb_end: Material = look.skin if clothed else look.cloth
	var legs: Material = look.trousers if clothed else look.cloth
	var j := func(v: float) -> float: return v + rng.randf_range(-0.02, 0.02)
	var h := 0.12  # half the body's thickness: how high the trunk's middle sits
	# The trunk: chest, belly, hips, each a squashed ball.
	pm.sphere(body, 0.5, 1.0, at * Transform3D(Basis.from_scale(Vector3(0.42, 0.23, 0.44)), Vector3(0, h + 0.01, -0.38)), 10, 5)
	pm.sphere(body, 0.5, 1.0, at * Transform3D(Basis.from_scale(Vector3(0.34, 0.2, 0.34)), Vector3(0, h - 0.01, -0.18)), 10, 5)
	pm.sphere(legs if clothed else body, 0.5, 1.0, at * Transform3D(Basis.from_scale(Vector3(0.37, 0.21, 0.3)), Vector3(0, h, -0.02)), 10, 5)
	# Neck and head, turned a little.
	var turn := Basis(Vector3.FORWARD, float(pose.get("head_turn", 0.0)))
	_limb(pm, look.skin if clothed else body, at * Vector3(0, h, -0.56), at * Vector3(0, 0.11, -0.66), 0.055, 0.05)
	var head := at * Transform3D(turn * Basis.from_scale(Vector3(0.2, 0.2, 0.24)), Vector3(0, 0.11, -0.76))
	pm.sphere(look.skin if clothed else body, 0.5, 1.0, head, 10, 6)
	if clothed:  # face down: the back of the head, the hair
		pm.sphere(look.hair, 0.5, 1.0, head * Transform3D(Basis.from_scale(Vector3(1.08, 0.9, 1.06)), Vector3(0, 0.08, 0.05)), 10, 6)
	# Arms: shoulder, elbow, wrist.
	for side in [-1.0, 1.0]:
		var shoulder := Vector3(0.2 * side, h + 0.01, -0.5)
		var kind := int(pose.get("arm_l" if side < 0 else "arm_r", 0))
		var elbow: Vector3
		var wrist: Vector3
		match kind:
			1:  # flung out from the body
				elbow = shoulder + Vector3(0.24 * side, -0.05, 0.12)
				wrist = elbow + Vector3(0.24 * side, -0.02, 0.06)
			2:  # bent up beside the head
				elbow = shoulder + Vector3(0.2 * side, -0.04, -0.12)
				wrist = elbow + Vector3(-0.08 * side, -0.02, -0.24)
			3:  # raised, stiff, a little bent
				elbow = shoulder + Vector3(0.06 * side, 0.27, 0.05)
				wrist = elbow + Vector3(0.05 * side, 0.22, -0.1)
			_:  # along the side
				elbow = shoulder + Vector3(0.04 * side, -0.04, j.call(0.28))
				wrist = elbow + Vector3(0.0, 0.0, 0.26)
		_limb(pm, limb_top, at * shoulder, at * elbow, 0.06, 0.05)
		_limb(pm, limb_end, at * elbow, at * wrist, 0.05, 0.04)
		var hand_dir := (wrist - elbow).normalized()
		pm.sphere(limb_end, 0.5, 1.0, at * Transform3D(PropMesh.along(wrist, wrist + hand_dir).basis * Basis.from_scale(Vector3(0.08, 0.15, 0.05)), wrist + hand_dir * 0.07), 6, 3)
	# Legs: hip, knee, ankle, foot.
	for side in [-1.0, 1.0]:
		var hip := Vector3(0.095 * side, h - 0.02, 0.02)
		var bend := clampf(float(pose.get("knee_l" if side < 0 else "knee_r", 0.0)), 0.0, 1.0) * 1.0
		var knee := hip + Vector3(0.02 * side, 0.42 * sin(bend), 0.42 * cos(bend))
		var ankle := knee + Vector3(0.0, -0.4 * sin(bend), 0.4 * cos(bend))
		ankle.y = maxf(ankle.y, 0.06)
		_limb(pm, legs, at * hip, at * knee, 0.085, 0.065)
		_limb(pm, legs, at * knee, at * ankle, 0.062, 0.048)
		# The foot: toes up on his back, heel up face down (it rests on the toes).
		var foot := Vector3(ankle.x, 0.1, ankle.z + 0.05)
		var shoe: Material = look.hair if clothed else look.cloth
		pm.box(shoe, Vector3(0.09, 0.2, 0.1), at * Transform3D(Basis(Vector3.RIGHT, -0.25 if clothed else 0.2), foot))
	var rope: Material = look.get("rope")
	if rope == null or clothed:
		return
	# A shroud's ties: neck, chest (over the arms), knees, ankles.
	for t: Array in [[-0.6, 0.11, 0.075], [-0.36, 0.3, 0.17], [0.45, 0.18, 0.09], [0.8, 0.15, 0.08]]:
		var band := Basis.from_scale(Vector3(t[1], t[2], 1.0)) * Basis(Vector3.RIGHT, PI / 2)
		pm.ring(rope, 0.97, 1.04, at * Transform3D(band, Vector3(0, h if t[0] < 0.4 else 0.08, j.call(t[0]))), 10, 4)


## A tapered round limb from a to b.
static func _limb(pm: PropMesh, mat: Material, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var xf := PropMesh.along(a, b)
	pm.cyl(mat, snappedf(r1, 0.005), snappedf(r0, 0.005), snappedf(a.distance_to(b), 0.01), xf, 7)
	pm.sphere(mat, r1, r1 * 2.0, Transform3D(Basis.IDENTITY, b), 6, 3)
