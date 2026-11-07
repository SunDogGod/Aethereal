extends Node3D
## Black Sand's skylight shafts: each child (a light_shaft.gd node, with an OmniLight child for its
## pool of light on the sand if you like) stays hidden until the ceiling panel above it has lit
## in the artificial dawn, then appears with it. It watches the panels themselves (a panel is lit
## once the ArtificialDawn node has given it its "on" material), so retiming the dawn needs
## nothing here. In the big world a frozen zone freezes this too.

@export var dawn: NodePath  ## the ArtificialDawn node (its children are the panels)

var _waiting: Array = []  # [shaft, panel] pairs still dark


func _ready() -> void:
	var dawn_node := get_node_or_null(dawn)
	if dawn_node == null:
		return  # no dawn: leave the shafts as they are
	for shaft in get_children():
		if not shaft is Node3D:
			continue
		var panel := _panel_over(dawn_node, (shaft as Node3D).global_position)
		if panel:
			(shaft as Node3D).visible = false
			_waiting.append([shaft, panel])


func _process(_delta: float) -> void:
	if _waiting.is_empty():
		set_process(false)
		return
	var on: Material = get_node(dawn).get("on_material")
	for i in range(_waiting.size() - 1, -1, -1):
		var pair: Array = _waiting[i]
		if (pair[1] as MeshInstance3D).material_override == on:
			(pair[0] as Node3D).visible = true
			_waiting.remove_at(i)


## The panel nearest above a point (seen from above, ignoring height).
func _panel_over(dawn_node: Node, at: Vector3) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_d := INF
	for panel in dawn_node.get_children():
		if panel is MeshInstance3D:
			var p: Vector3 = (panel as MeshInstance3D).global_position
			var d := Vector2(p.x - at.x, p.z - at.z).length()
			if d < best_d:
				best_d = d
				best = panel
	return best
