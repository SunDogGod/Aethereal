extends RefCounted
## Roofs for the Massacre's village props (houses, gates, stalls, the shrine), added to a PropMesh.
## The village's style (as at the family house in Black Sand): a gable of plaster under two
## terracotta slopes laid with rows of round tiles, a heavy ridge with raised end tiles, a dark
## timber fascia along the eaves with rafter ends under it.
## Everything is built along local X (the ridge) in the frame `xf`, from the wall top up.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")


## A gable roof over walls `length` (x) by `depth` (z), standing on `top` (the wall top, local y).
## eave: how far the slopes reach past the walls (front, back); gable_out: past the end walls.
## pitch in degrees. `mats` needs: roof, ridge, timber, gable. tile_rows = round tiles on the slopes.
static func gable(pm: PropMesh, mats: Dictionary, xf: Transform3D, length: float, depth: float, top: float,
		pitch := 26.0, eave := Vector2(0.9, 0.9), gable_out := 0.5, tile_rows := true) -> float:
	var a := deg_to_rad(pitch)
	var half := depth * 0.5
	var h := half * tan(a)
	if mats.get("gable") != null:
		var prism := PrismMesh.new()
		prism.size = Vector3(depth, h, length)
		pm._add(mats.gable, prism, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, top + h * 0.5, 0)))
	var ridge := Vector3(0, top + h, 0)
	var thick := 0.14
	var run_len := length + gable_out * 2.0
	for s: float in [1.0, -1.0]:
		var reach: float = eave.x if s > 0.0 else eave.y
		var slope := (half + reach) / cos(a) + 0.1
		var down := Vector3(0, -sin(a), s * cos(a))
		var out := Vector3(0, cos(a), s * sin(a))
		var basis := Basis(Vector3.RIGHT, s * a)
		var centre := ridge + down * (slope * 0.5 - 0.1) + out * (thick * 0.5 + 0.02)
		pm.box(mats.roof, Vector3(run_len, thick, slope), xf * Transform3D(basis, centre))
		if tile_rows:
			# Rows of round tiles down the slope, 0.32 m apart: the roof's texture is its shape.
			var n := int(run_len / 0.32)
			var lift := out * (thick + 0.045)
			for i in n:
				var x := -run_len * 0.5 + (i + 0.5) * run_len / n
				var c := ridge + down * (slope * 0.5 - 0.1) + lift + Vector3(x, 0, 0)
				pm.box(mats.roof, Vector3(0.13, 0.08, slope - 0.05), xf * Transform3D(basis, c))
		var edge := ridge + down * (slope - 0.1) + out * (thick * 0.5)
		# The fascia board along the eave, and rafter ends under it every 0.6 m.
		pm.box(mats.timber, Vector3(run_len + 0.04, 0.16, 0.09), xf * Transform3D(Basis(), Vector3(0, edge.y - 0.06, edge.z + s * 0.02)))
		var rafters := int(run_len / 0.6)
		for i in rafters + 1:
			var x := -run_len * 0.5 + i * run_len / rafters
			var under := edge - out * 0.16 - down * 0.35
			pm.box(mats.timber, Vector3(0.08, 0.1, 0.8), xf * Transform3D(basis, Vector3(x, under.y, under.z)))
		# Barge boards up the gable ends.
		for sx: float in [-1.0, 1.0]:
			var bc := ridge + down * (slope * 0.5 - 0.1) + Vector3(sx * (run_len * 0.5 + 0.03), 0, 0)
			pm.box(mats.timber, Vector3(0.07, 0.24, slope), xf * Transform3D(basis, bc))
	# The ridge: a heavy capping with raised end tiles (onigawara), a little proud of the ends.
	pm.box(mats.ridge, Vector3(run_len + 0.12, 0.26, 0.42), xf * Transform3D(Basis(), ridge + Vector3(0, 0.17, 0)))
	pm.box(mats.ridge, Vector3(run_len + 0.04, 0.1, 0.56), xf * Transform3D(Basis(), ridge + Vector3(0, 0.05, 0)))
	for sx: float in [-1.0, 1.0]:
		var end := ridge + Vector3(sx * (run_len * 0.5 + 0.12), 0.32, 0)
		pm.box(mats.ridge, Vector3(0.24, 0.5, 0.5), xf * Transform3D(Basis(), end))
		pm.box(mats.ridge, Vector3(0.18, 0.14, 0.3), xf * Transform3D(Basis(Vector3.FORWARD, sx * -0.5), end + Vector3(sx * 0.06, 0.3, 0)))
	return top + h


## A lean-to (pent) roof: one tiled slope from `high` (against the wall at z = 0) out to +z `reach`,
## `length` long, `drop` metres lower at its outer edge. For verandas and stalls.
static func pent(pm: PropMesh, mats: Dictionary, xf: Transform3D, length: float, reach: float, high: float, drop: float,
		tile_rows := true) -> void:
	var a := atan2(drop, reach)
	var slope := sqrt(reach * reach + drop * drop) + 0.1
	var basis := Basis(Vector3.RIGHT, a)
	var centre := Vector3(0, high - drop * 0.5 + 0.07, reach * 0.5)
	pm.box(mats.roof, Vector3(length, 0.12, slope), xf * Transform3D(basis, centre))
	if tile_rows:
		var out := Vector3(0, cos(a), sin(a))
		var n := int(length / 0.32)
		for i in n:
			var x := -length * 0.5 + (i + 0.5) * length / n
			pm.box(mats.roof, Vector3(0.12, 0.07, slope - 0.05), xf * Transform3D(basis, centre + out * 0.09 + Vector3(x, 0, 0)))
	pm.box(mats.timber, Vector3(length + 0.04, 0.14, 0.08), xf * Transform3D(Basis(), Vector3(0, high - drop - 0.02, reach + 0.04)))
	pm.box(mats.ridge, Vector3(length + 0.04, 0.12, 0.18), xf * Transform3D(Basis(), Vector3(0, high + 0.1, 0.06)))
