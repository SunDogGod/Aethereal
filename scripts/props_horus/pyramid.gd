@tool
extends "res://scripts/props_horus/horus_prop.gd"
## A stepped Voidstone pyramid of Temek: Steps tiers on a Base metres square footprint, a flat
## top with a small shrine, and (Lit) a tiny cold strip at one corner of every tier, a dotted
## line of light up one edge. Origin on the ground under the middle. Solid tier by tier.

@export var base := 60.0:
	set(value):
		base = value
		_rebuild()
@export var steps := 7:
	set(value):
		steps = maxi(value, 1)
		_rebuild()
@export var lit := true:
	set(value):
		lit = value
		_rebuild()


func _build() -> void:
	var tier_h := base * 0.62 / steps
	var hw_top := 0.0
	for i in steps:
		var hw := base * 0.5 * (1.0 - float(i) / (steps + 0.7))
		hw_top = hw
		_solid(M.voidstone, Vector3(hw * 2.0, tier_h, hw * 2.0), _at(0, tier_h * (i + 0.5), 0))
		if lit:
			_pm.stick(M.edge, Vector3(hw, tier_h * i + 0.3, hw), Vector3(hw, tier_h * (i + 1) - 0.3, hw), 0.22)
	# The shrine on top: a block with a dark doorway, a lintel.
	var top := tier_h * steps
	var sw := minf(hw_top * 0.6, 5.0)
	_solid(M.voidstone, Vector3(sw * 2.0, sw * 0.9, sw * 1.6), _at(0, top + sw * 0.45, 0))
	_pm.box(M.hole, Vector3(sw * 0.4, sw * 0.65, 0.1), _at(0, top + sw * 0.33, sw * 0.8 + 0.03))
	_pm.box(M.stone_dark, Vector3(sw * 2.2, 0.4, sw * 1.8), _at(0, top + sw * 0.9 + 0.2, 0))
	if lit:
		_pm.stick(M.edge, Vector3(sw, top + sw * 0.2, sw * 0.8), Vector3(sw, top + sw * 0.8, sw * 0.8), 0.2)
	# A course of stone at the foot, mostly buried, and sand drifted on the lowest tier.
	_pm.box(M.stone_dark, Vector3(base + 2.0, 0.8, base + 2.0), _at(0, 0.1, 0))
	for k in 4:
		var a := k * PI * 0.5 + _r.randf_range(-0.3, 0.3)
		var rad := base * 0.5
		_ball(M.sand, Vector3(base * 0.12, 1.2, base * 0.06), Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * rad, 0.2, sin(a) * rad)), 8, 4)
