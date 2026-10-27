@tool
extends Node3D
## The rigs the Massacre's grow lamps hang from: each panel (a Block under GrowLamps) gets a steel
## frame round its edge, four hanger rods up to the concrete ceiling, a junction box and a cable
## up into the ceiling; panels in the same row are joined by a cable tray. One mesh for them all.
## Panels lists each panel's centre (this node's space, as the Blocks sit); keep it in step if a
## lamp moves. Purely visual: it is all far above anyone's head.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const STEEL := preload("res://materials/metal_worn.tres")
const DARK := preload("res://materials/rubber.tres")
const RAIL := preload("res://materials/trim_rail_worn.tres")

@export var panels := PackedVector3Array():
	set(value):
		panels = value
		_rebuild()
@export var panel_size := Vector3(6, 0.5, 6):
	set(value):
		panel_size = value
		_rebuild()
## The underside of the ceiling (world height, as this node sits at the origin).
@export var ceiling_y := 26.0:
	set(value):
		ceiling_y = value
		_rebuild()

var _mesh := MeshInstance3D.new()
var _build_pending := false  # waiting to be built once it is in a scene (mesh_build.gd)


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


## Every setting calls this: the mesh is built once, when the prop is in a scene (mesh_build.gd).
func _rebuild() -> void:
	MeshBuild.request(self)


func _rebuild_now() -> void:
	var pm := PropMesh.new()
	var hx := panel_size.x * 0.5
	var hz := panel_size.z * 0.5
	var rows := {}
	for p in panels:
		var top := p.y + panel_size.y * 0.5
		# The frame: four angle irons round the panel, a little proud of it.
		for sz: float in [-1.0, 1.0]:
			pm.box(STEEL, Vector3(panel_size.x + 0.3, 0.22, 0.14), Transform3D(Basis(), p + Vector3(0, -panel_size.y * 0.5 + 0.06, sz * (hz + 0.08))))
		for sx: float in [-1.0, 1.0]:
			pm.box(STEEL, Vector3(0.14, 0.22, panel_size.z + 0.02), Transform3D(Basis(), p + Vector3(sx * (hx + 0.08), -panel_size.y * 0.5 + 0.06, 0)))
		pm.box(RAIL, Vector3(panel_size.x - 0.4, 0.12, 0.2), Transform3D(Basis(), p + Vector3(0, top - p.y + 0.06, 0)))
		# Hangers to the ceiling, a junction box, the feed cable.
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var a := p + Vector3(sx * (hx - 0.3), top - p.y, sz * (hz - 0.3))
				pm.stick(STEEL, a, Vector3(a.x, ceiling_y + 0.05, a.z), 0.06)
		pm.box(STEEL, Vector3(0.6, 0.4, 0.4), Transform3D(Basis(), p + Vector3(hx * 0.4, top - p.y + 0.32, 0)))
		pm.stick(DARK, p + Vector3(hx * 0.4, top - p.y + 0.5, 0.1), Vector3(p.x + hx * 0.4 + 0.4, ceiling_y + 0.05, p.z + 0.6), 0.08)
		var key := snappedf(p.x, 0.1)
		if not rows.has(key):
			rows[key] = []
		rows[key].append(p)
	# Cable trays between neighbours in a row (along Z), hung just above the panels.
	for key in rows:
		var row: Array = rows[key]
		row.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)
		for i in row.size() - 1:
			var a: Vector3 = row[i]
			var b: Vector3 = row[i + 1]
			var y := a.y + panel_size.y * 0.5 + 0.7
			var z0 := a.z + hz - 0.1
			var z1 := b.z - hz + 0.1
			if z1 <= z0:
				continue
			pm.box(RAIL, Vector3(0.5, 0.1, z1 - z0), Transform3D(Basis(), Vector3(a.x - hx * 0.4, y, (z0 + z1) * 0.5)))
			pm.box(DARK, Vector3(0.3, 0.12, z1 - z0), Transform3D(Basis(), Vector3(a.x - hx * 0.4, y + 0.1, (z0 + z1) * 0.5)))
			var mid := (z0 + z1) * 0.5
			pm.stick(STEEL, Vector3(a.x - hx * 0.4, y, mid), Vector3(a.x - hx * 0.4, ceiling_y + 0.05, mid), 0.05)
	_mesh.mesh = pm.commit()
