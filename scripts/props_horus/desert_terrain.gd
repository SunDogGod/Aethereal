@tool
extends StaticBody3D
## The Horus desert: a field of dunes from noise, under the megastructure's amber haze. The sand
## lies between this node's height and `amplitude` metres above it, in long ridges along
## `ridge_direction`. A road (a line of points) is pressed flat into it so he can walk the route:
## level across, following the points' heights along (keep those under 25 degrees; a steeper leg
## is warned about). Pads are level discs for buildings. The rim raises the border into a wall of
## dunes so he can't walk off; where the road leaves the desert, the rim gives way.
## Road, pads and height_at() are in WORLD metres, like everything else in a level, so you can
## read a building's position in the Inspector and type it in. Move the desert; don't turn it.
## Built once it is in a scene (mesh_build.gd), in 64 m chunks so the far ones are culled. The
## collision (one concave shape on layer 1) is made while the game runs and is never saved.

const CHUNK := 64.0  ## metres per mesh chunk
const UV_METRES := 4.0  ## the mesh's own UVs repeat every this many metres (world-mapped materials ignore them)

@export var size := Vector2(300.0, 300.0):  ## metres across (x) and deep (z), centred on this node
	set(value):
		size = value
		_rebuild()
@export var cell := 2.0:  ## metres between vertices
	set(value):
		cell = maxf(0.5, value)
		_rebuild()
@export var seed := 1:
	set(value):
		seed = value
		_rebuild()
@export var amplitude := 8.0:  ## metres from a hollow to a crest
	set(value):
		amplitude = value
		_rebuild()
@export var wavelength := 60.0:  ## metres from one dune to the next
	set(value):
		wavelength = value
		_rebuild()
@export var ridge_direction := 20.0:  ## degrees; the crests run along this heading
	set(value):
		ridge_direction = value
		_rebuild()
@export_group("Road and pads")
@export var road := PackedVector3Array():  ## world points; the sand is pressed to their heights
	set(value):
		road = value
		_rebuild()
@export var road_width := 12.0:  ## metres of level ground across the road (it eases back into dunes over as much again)
	set(value):
		road_width = value
		_rebuild()
@export var pads := PackedVector3Array():  ## world points: a level disc at each one's height
	set(value):
		pads = value
		_rebuild()
@export var pad_radius := 12.0:
	set(value):
		pad_radius = value
		_rebuild()
@export_group("Border")
@export var rim := 12.0:  ## metres the border rises into a wall of dunes (0 = none)
	set(value):
		rim = value
		_rebuild()
@export var rim_width := 30.0:  ## metres in from the edge over which the wall climbs
	set(value):
		rim_width = value
		_rebuild()
@export_group("Look")
@export_range(0.0, 1.0) var hollow_shade := 0.45:  ## how much darker the hollows are than the crests
	set(value):
		hollow_shade = value
		_rebuild()
@export var material: Material:
	set(value):
		material = value
		for c in _chunks:
			c.material_override = material

var _heights := PackedFloat32Array()  # (nx + 1) x (nz + 1) vertex heights, local, row by row along x
var _nx := 1
var _nz := 1
var _half := Vector2.ZERO  # the built field's half size in metres
var _chunks: Array[MeshInstance3D] = []
var _collision := CollisionShape3D.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	collision_layer = 1
	collision_mask = 0
	add_child(_collision, false, INTERNAL_MODE_FRONT)
	_rebuild()


## Every setting calls this: the field is built once, when it is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	_nx = maxi(1, ceili(size.x / cell))
	_nz = maxi(1, ceili(size.y / cell))
	_half = Vector2(_nx, _nz) * cell * 0.5
	_fill_heights()
	for c in _chunks:
		remove_child(c)
		c.queue_free()
	_chunks.clear()
	var per := maxi(1, int(CHUNK / cell))
	for cz in ceili(float(_nz) / per):
		for cx in ceili(float(_nx) / per):
			_chunk(cx * per, cz * per, mini((cx + 1) * per, _nx), mini((cz + 1) * per, _nz))
	_collision.shape = null if Engine.is_editor_hint() else _collision_shape()


## The sand's height (world y) under world x, z. Exact on the collision's own triangles, so a
## prop placed here stands on the surface. Past the edge: the height at the edge.
func height_at(x: float, z: float) -> float:
	var origin := _to_world().origin
	if _heights.is_empty():
		return origin.y
	var fx := clampf((x - origin.x + _half.x) / cell, 0.0, float(_nx))
	var fz := clampf((z - origin.z + _half.y) / cell, 0.0, float(_nz))
	var i := clampi(floori(fx), 0, _nx - 1)
	var j := clampi(floori(fz), 0, _nz - 1)
	var u := fx - i
	var v := fz - j
	var ha := _h(i, j)
	var hc := _h(i + 1, j + 1)
	var h: float
	if u >= v:  # the triangle a-b-c (see _chunk)
		var hb := _h(i + 1, j)
		h = ha + (hb - ha) * u + (hc - hb) * v
	else:  # the triangle a-c-d
		var hd := _h(i, j + 1)
		h = ha + (hd - ha) * v + (hc - hd) * u
	return h + origin.y


func _h(i: int, j: int) -> float:
	return _heights[j * (_nx + 1) + i]


## Where this node is in the world. Before it enters a scene (the loading screen builds early) only
## its own transform is known: the desert is meant to sit straight under the level root.
func _to_world() -> Transform3D:
	return global_transform if is_inside_tree() else transform


# ---------------------------------------------------------------- the height field
func _fill_heights() -> void:
	var count := (_nx + 1) * (_nz + 1)
	_heights.resize(count)
	var flat_h := PackedFloat32Array()
	var flat_w := PackedFloat32Array()
	flat_h.resize(count)
	flat_w.resize(count)
	_press_flats(flat_h, flat_w)
	var crests := FastNoiseLite.new()
	crests.seed = seed
	crests.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	crests.fractal_type = FastNoiseLite.FRACTAL_NONE
	crests.frequency = 1.0 / maxf(4.0, wavelength)
	var swell := FastNoiseLite.new()
	swell.seed = seed + 7
	swell.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	swell.fractal_octaves = 2
	swell.frequency = 1.0 / maxf(4.0, wavelength * 2.5)
	var ca := cos(deg_to_rad(ridge_direction))
	var sa := sin(deg_to_rad(ridge_direction))
	for j in _nz + 1:
		var z := j * cell - _half.y
		for i in _nx + 1:
			var x := i * cell - _half.x
			# Stretch the noise along the ridge heading, so the dunes come out as long crests.
			var along := (x * ca - z * sa) * 0.3
			var across := x * sa + z * ca
			var crest := 1.0 - absf(crests.get_noise_2d(along, across))  # sharp crests, round hollows
			var dune := clampf(crest * 0.7 + (swell.get_noise_2d(x, z) * 0.5 + 0.5) * 0.3, 0.0, 1.0)
			var h := dune * amplitude
			var edge := minf(minf(x + _half.x, _half.x - x), minf(z + _half.y, _half.y - z))
			if rim > 0.0 and edge < rim_width:
				h += rim * smoothstep(0.0, 1.0, 1.0 - edge / rim_width) * (0.7 + 0.6 * dune)
			var k := j * (_nx + 1) + i
			if flat_w[k] > 0.0:
				h = lerpf(h, flat_h[k], flat_w[k])
			_heights[k] = h


## Marks every vertex the road or a pad presses flat: its target height and how fully (0..1).
func _press_flats(flat_h: PackedFloat32Array, flat_w: PackedFloat32Array) -> void:
	var origin := _to_world().origin
	for s in road.size() - 1:
		var a := road[s] - origin
		var b := road[s + 1] - origin
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		if run > 0.01 and absf(b.y - a.y) / run > tan(deg_to_rad(25.0)):
			push_warning("%s: road leg %d is steeper than 25 degrees" % [name, s])
		_press(flat_h, flat_w, Vector2(a.x, a.z), Vector2(b.x, b.z), a.y, b.y, road_width * 0.5, road_width)
	for p in pads:
		var q := p - origin
		_press(flat_h, flat_w, Vector2(q.x, q.z), Vector2(q.x, q.z), q.y, q.y, pad_radius, pad_radius)


## One leg from a to b (local metres; a pad is a leg of no length): level within `flat_r` of it,
## easing back into the dunes over `blend` more. Only the vertices near the leg are visited.
func _press(flat_h: PackedFloat32Array, flat_w: PackedFloat32Array, a: Vector2, b: Vector2,
		ya: float, yb: float, flat_r: float, blend: float) -> void:
	var reach := flat_r + blend
	var lo := (Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach) + _half) / cell
	var hi := (Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach) + _half) / cell
	var ab := b - a
	var len2 := ab.length_squared()
	for j in range(clampi(floori(lo.y), 0, _nz), clampi(ceili(hi.y), 0, _nz) + 1):
		for i in range(clampi(floori(lo.x), 0, _nx), clampi(ceili(hi.x), 0, _nx) + 1):
			var p := Vector2(i * cell - _half.x, j * cell - _half.y)
			var t := 0.0 if len2 < 0.0001 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			if d >= reach:
				continue
			var w := 1.0 if d <= flat_r else 1.0 - smoothstep(0.0, 1.0, (d - flat_r) / blend)
			var k := j * (_nx + 1) + i
			if w > flat_w[k]:
				flat_w[k] = w
				flat_h[k] = lerpf(ya, yb, t)


# ---------------------------------------------------------------- meshes and collision
## One chunk of the field, vertices i0..i1 by j0..j1, as its own MeshInstance3D (so the far
## chunks are culled). Corners are shared and the normals come from the field, so the sand is
## smooth and the chunks meet without seams.
func _chunk(i0: int, j0: int, i1: int, j1: int) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var origin := _to_world().origin
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := Vector3(i * cell - _half.x, _h(i, j), j * cell - _half.y)
			verts.append(p)
			norms.append(_normal(i, j))
			uvs.append(Vector2(p.x + origin.x, p.z + origin.z) / UV_METRES)
			cols.append(_shade(p))
	var row := i1 - i0 + 1
	for j in j1 - j0:
		for i in i1 - i0:
			# Godot's front faces are CLOCKWISE seen from outside: a, b, c runs clockwise seen
			# from above (x then x+z), so both triangles face up.
			var a := j * row + i
			idx.append_array([a, a + 1, a + row + 1, a, a + row + 1, a + row])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi, false, INTERNAL_MODE_FRONT)
	_chunks.append(mi)


## The field's slope at a vertex, from its neighbours (one-sided at the edges). Always points up.
func _normal(i: int, j: int) -> Vector3:
	var lo := Vector2i(maxi(i - 1, 0), maxi(j - 1, 0))
	var hi := Vector2i(mini(i + 1, _nx), mini(j + 1, _nz))
	var dx := (_h(hi.x, j) - _h(lo.x, j)) / ((hi.x - lo.x) * cell)
	var dz := (_h(i, hi.y) - _h(i, lo.y)) / ((hi.y - lo.y) * cell)
	return Vector3(-dx, 1.0, -dz).normalized()


## Vertex colour: the hollows darker than the crests, a hair of random variation everywhere.
func _shade(p: Vector3) -> Color:
	var up := clampf(p.y / maxf(0.1, amplitude), 0.0, 1.0)
	var v := lerpf(1.0 - hollow_shade, 1.0, smoothstep(0.0, 1.0, up))
	v *= 0.96 + 0.04 * fmod(absf(sin(p.x * 12.9898 + p.z * 37.719) * 43758.5453), 1.0)
	return Color(v, v, v, 1.0)


## The whole field as one concave shape, the same triangles as the meshes.
func _collision_shape() -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()
	faces.resize(_nx * _nz * 6)
	var k := 0
	for j in _nz:
		for i in _nx:
			var a := Vector3(i * cell - _half.x, _h(i, j), j * cell - _half.y)
			var b := Vector3(a.x + cell, _h(i + 1, j), a.z)
			var c := Vector3(a.x + cell, _h(i + 1, j + 1), a.z + cell)
			var d := Vector3(a.x, _h(i, j + 1), a.z + cell)
			for p: Vector3 in [a, b, c, a, c, d]:  # the same clockwise order as the meshes
				faces[k] = p
				k += 1
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape
