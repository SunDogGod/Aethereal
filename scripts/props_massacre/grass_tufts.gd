@tool
extends Node3D
## Grass tufts and wild flowers scattered over the village's lawns, drawn as MultiMeshes (one
## draw per chunk, however many tufts): the floor's flat grass texture gets a bit of height.
## Areas are rectangles (x, z, width, depth, in this node's space) to fill; Holes are rectangles
## to leave bare (paths, houses, beds). The scatter is the same every run (Seed). The field is
## cut into Chunk-metre squares, so only the ones near the camera draw (Draw distance; a chunk
## fades out over FADE metres there instead of switching off). Each chunk is two MultiMeshes,
## the grass and the flowers: every tuft's shade or flower colour is its instance colour.
## Purely visual: the tufts are a few centimetres tall, no collision.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const TUFT_MAT := preload("res://materials/massacre_tuft.tres")
const GRASS_SHADES: Array[Color] = [Color(0.1, 0.21, 0.05), Color(0.13, 0.26, 0.06), Color(0.17, 0.3, 0.07)]
const FLOWER_HEADS: Array[Color] = [Color(0.95, 0.9, 0.85), Color(0.95, 0.8, 0.3), Color(0.7, 0.55, 0.95), Color(0.95, 0.5, 0.45)]
const STEM := Color(0.15, 0.3, 0.07)  # times the flower colour: a darker green

@export var areas: Array[Rect2] = []:
	set(value):
		areas = value
		_rebuild()
@export var holes: Array[Rect2] = []:
	set(value):
		holes = value
		_rebuild()
## Tufts per square metre.
@export var density := 0.6:
	set(value):
		density = value
		_rebuild()
## Of every 100 tufts, this many are flowers.
@export_range(0, 100) var flowers := 6:
	set(value):
		flowers = value
		_rebuild()
@export var random_seed := 7:
	set(value):
		random_seed = value
		_rebuild()
@export var chunk := 16.0:
	set(value):
		chunk = value
		_rebuild()
@export var draw_distance := 46.0:
	set(value):
		draw_distance = value
		_rebuild()

const FADE := 8.0

var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)
var _chunks: Array[MultiMeshInstance3D] = []


func _init() -> void:
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	for c in _chunks:
		c.queue_free()
	_chunks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var groups := {}  # [chunk key, is flower] -> [Array of Transform3D, Array of Color]
	for r in areas:
		var n := int(r.size.x * r.size.y * density)
		for i in n:
			var p := Vector2(r.position.x + rng.randf() * r.size.x, r.position.y + rng.randf() * r.size.y)
			var is_flower := rng.randi_range(0, 99) < flowers
			var yaw := rng.randf() * TAU
			var s := 0.7 + rng.randf() * 0.7
			var pick := rng.randi_range(0, 2) if not is_flower else rng.randi_range(0, FLOWER_HEADS.size() - 1)
			if _in_hole(p):
				continue
			var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * (0.8 + rng.randf() * 0.5), s)), Vector3(p.x, 0, p.y))
			var key := [Vector2i(floori(p.x / chunk), floori(p.y / chunk)), is_flower]
			if not groups.has(key):
				groups[key] = [[], []]
			groups[key][0].append(xf)
			groups[key][1].append(FLOWER_HEADS[pick] if is_flower else GRASS_SHADES[pick])
	var meshes := {false: _tuft_mesh(false), true: _tuft_mesh(true)}
	for key in groups:
		_chunk(meshes[key[1]], groups[key][0], groups[key][1])


func _in_hole(p: Vector2) -> bool:
	for h in holes:
		if h.has_point(p):
			return true
	return false


func _chunk(mesh: Mesh, items: Array, colours: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i])
		mm.set_instance_color(i, colours[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = draw_distance
	mmi.visibility_range_end_margin = FADE
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi, false, INTERNAL_MODE_FRONT)
	_chunks.append(mmi)


## One tuft: four thin blades leaning out (cones); a flower is a stem with a head.
## massacre_tuft.tres multiplies by the vertex colour, which Godot multiplies by the instance
## colour: the grass is painted light to dark from tip to root and tinted by its shade; a flower's
## head is white (it takes the flower colour) and its stem a green that the colour only darkens.
func _tuft_mesh(is_flower: bool) -> Mesh:
	var pm := PropMesh.new()
	if is_flower:
		pm.stick(TUFT_MAT, Vector3.ZERO, Vector3(0.02, 0.3, 0), 0.015)
		pm.sphere(TUFT_MAT, 0.045, 0.05, Transform3D(Basis(), Vector3(0.02, 0.33, 0)), 5, 2)
		pm.cyl(TUFT_MAT, 0.0, 0.03, 0.14, Transform3D(Basis(Vector3.FORWARD, 0.5), Vector3(0.04, 0.07, 0)), 3)
	else:
		for k in 4:
			var a := TAU * k / 4.0 + 0.4
			var lean := Basis(Vector3(cos(a), 0, sin(a)), -(0.35 + k * 0.08))  # tips splay outward
			pm.cyl(TUFT_MAT, 0.0, 0.035, 0.22 + k * 0.04, Transform3D(lean, Vector3(sin(a) * 0.03, 0.1, -cos(a) * 0.03)), 3)
	var plain := pm.commit()
	var out := ArrayMesh.new()
	for si in plain.get_surface_count():
		var arrays := plain.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for i in verts.size():
			if is_flower:
				cols[i] = STEM if verts[i].y < 0.29 else Color.WHITE
			else:
				# Blades darker at the root, lighter at the tip.
				cols[i] = Color.WHITE.darkened(0.35 * (1.0 - clampf(verts[i].y / 0.25, 0.0, 1.0)))
		arrays[Mesh.ARRAY_COLOR] = cols
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, TUFT_MAT)
	return out
