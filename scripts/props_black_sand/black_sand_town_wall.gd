@tool
extends Node3D
## The Kowloon town seen from under it, closing one side of Black Sand: one solid black block,
## featureless where it meets the sand, with small lit windows only far up (from `windows_from`
## metres above the origin to near the top). The windows are grouped in uneven vertical bands, one
## per building in the stack, each band with its own storey height and its own share of lit rooms.
## Origin: the middle of the block's foot on its front face; the front faces -Z, the mass runs +Z.
## Purely visual: the level's SouthBarrier is the collision. Change any value and it rebuilds.

const PropMesh := preload("res://scripts/props/prop_mesh.gd")
const BLOCK_MAT := preload("res://materials/black_sand_town_block.tres")
const WINDOW_MATS := [
	preload("res://materials/black_sand_town_window_warm.tres"),
	preload("res://materials/black_sand_town_window_cool.tres"),
	preload("res://materials/black_sand_town_window_dim.tres"),
]

@export var width := 182.0:
	set(value):
		width = value
		_rebuild()
@export var height := 82.0:  ## from the origin up (the block's foot is sunk `sink` metres below it)
	set(value):
		height = value
		_rebuild()
@export var sink := 8.0:
	set(value):
		sink = value
		_rebuild()
@export var windows_from := 30.0:  ## the lowest windows start this high (each band a few metres higher or lower)
	set(value):
		windows_from = value
		_rebuild()
@export_range(0.0, 1.0) var lit_share := 0.22:  ## on average, the share of window slots that are lit
	set(value):
		lit_share = value
		_rebuild()
@export var seed_value := 7:
	set(value):
		seed_value = value
		_rebuild()

var _mesh := MeshInstance3D.new()


func _init() -> void:
	add_child(_mesh, false, INTERNAL_MODE_FRONT)
	_rebuild()


func _rebuild() -> void:
	var pm := PropMesh.new()
	var depth := 6.0
	var block := BoxMesh.new()
	block.size = Vector3(width, height + sink, depth)
	block.subdivide_width = int(width / 6.0)
	block.subdivide_height = int((height + sink) / 6.0)
	pm._add(BLOCK_MAT, block, Transform3D(Basis(), Vector3(0, (height - sink) * 0.5, depth * 0.5)))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x := -width * 0.5 + 1.5
	while x < width * 0.5 - 4.0:
		var band := rng.randf_range(7.0, 18.0)
		_band(pm, rng, x, minf(band, width * 0.5 - 1.5 - x))
		x += band + rng.randf_range(0.6, 2.4)  # a dark seam between buildings
	_mesh.mesh = pm.commit()


## One building's column of windows: x0 = its left edge, w = its width.
func _band(pm: PropMesh, rng: RandomNumberGenerator, x0: float, w: float) -> void:
	var bay := rng.randf_range(2.2, 3.2)
	var storey := rng.randf_range(2.6, 3.4)
	var win := Vector2(bay * rng.randf_range(0.28, 0.4), storey * rng.randf_range(0.24, 0.34))
	# Some buildings are nearly dark, most a little lit, a few busy; one column is a lit stairwell.
	var share := lit_share * (0.12 if rng.randf() < 0.3 else rng.randf_range(0.5, 1.9))
	var stair := rng.randi() % maxi(1, int(w / bay)) if rng.randf() < 0.5 else -1
	var main := rng.randi() % WINDOW_MATS.size()
	var cols := int(w / bay)
	var y := windows_from + rng.randf_range(-2.0, 7.0)
	var top := height - rng.randf_range(2.0, 9.0)
	while y + win.y < top:
		for c in cols:
			if rng.randf() > (0.65 if c == stair else share):
				continue
			var mat: Material = WINDOW_MATS[main] if rng.randf() < 0.75 else WINDOW_MATS[rng.randi() % WINDOW_MATS.size()]
			var cx := x0 + (c + 0.5) * bay
			pm.box(mat, Vector3(win.x, win.y, 0.1), Transform3D(Basis(), Vector3(cx, y + win.y * 0.5, -0.04)))
		y += storey
