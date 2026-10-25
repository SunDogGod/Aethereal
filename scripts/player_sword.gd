class_name PlayerSword
extends RefCounted
## When Aeneas's sword is out. It starts in its scabbard at his left hip; his first attack draws
## it (the quick draw), and blocking draws it at once. It stays out while he's locked on, while
## a fight is on near him, and for KEEP_DRAWN seconds after his last swing; then he sheathes it
## (a short animation he can walk through) and carries it again with his left hand on the
## scabbard. Characters without a scabbard (a level that hides it) always have it in hand.
## PlayerCombat owns one of these and calls tick() every physics frame.

const KEEP_DRAWN := 4.0     ## seconds after his last swing before he puts it away (Proposed)
const FIGHT_RANGE := 25.0   ## an enemy fighting within this many metres keeps it out

var combat: PlayerCombat
var player: Player
var _since_swing := 99.0


func _init(owner_combat: PlayerCombat) -> void:
	combat = owner_combat
	player = owner_combat.get_parent()


## True when the sword is in his hand (always true for a model without a scabbard).
func drawn() -> bool:
	return player.animator == null or not player.animator.has_carry or player.animator.sword_in_hand


## He just swung (or started to): keep it out a while.
func swung() -> void:
	_since_swing = 0.0


## Straight into his hand, no cut (he blocked with it sheathed).
func draw_now() -> void:
	if not drawn():
		player.animator.draw_instant()
	_since_swing = 0.0


## Back in the scabbard at once (a restart).
func reset() -> void:
	_since_swing = 99.0


func tick(delta: float) -> void:
	_since_swing += delta
	if drawn() and player.animator and player.animator.has_carry and _may_sheathe():
		player.animator.sheathe()


func _may_sheathe() -> bool:
	if _since_swing < KEEP_DRAWN or combat.lock_target or combat.move != PlayerCombat.Move.NONE:
		return false
	if combat.blocking or combat.is_charging() or combat.erupting or not player.is_on_floor():
		return false
	if player.animator.sheathing() or player.animator.dead:
		return false
	return not fight_near()


## True while an enemy near him is fighting (or reeling from a parry).
func fight_near() -> bool:
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		var state = enemy.get("state")
		if state in [Guard.State.FIGHTING, Guard.State.STAGGERED] \
				and enemy.global_position.distance_to(player.global_position) < FIGHT_RANGE:
			return true
	return false
