class_name PlayerSkills
extends RefCounted
## What Aeneas has gained: his Aether (the currency a sacrifice at the cube gives), the skills he
## bought with it (data/skills/*.tres), and whether he can open the skill tree yet (Kael shows him
## at the cube). Story scenes give Aether with [aether 3] and open things with [unlock skill_tree];
## the pause menu's Skills page spends it. The save keeps all three (save_state.gd "progress").

const FOLDER := "res://data/skills/"

var aether := 0
var owned: Array[String] = []
var tree_open := false

var _player: Player


func _init(player: Player) -> void:
	_player = player


## Every skill there is, in menu order.
static func all() -> Array[SkillData]:
	var list: Array[SkillData] = []
	for file in ResourceLoader.list_directory(FOLDER):
		var skill := load(FOLDER + file) as SkillData
		if skill:
			list.append(skill)
	list.sort_custom(func(a: SkillData, b: SkillData) -> bool: return a.order < b.order)
	return list


## Pays for a skill and turns it on. False if he has it already or can't afford it.
func buy(skill: SkillData) -> bool:
	if owned.has(skill.id) or aether < skill.cost:
		return false
	aether -= skill.cost
	unlock(skill.id)
	return true


## Opens the skill tree ("skill_tree") or turns a skill on for good, paid for or not.
func unlock(what: String) -> void:
	if what == "skill_tree":
		tree_open = true
		return
	if not owned.has(what):
		owned.append(what)
	match what:
		"double_jump":
			_player.double_jump_unlocked = true
		_:
			push_warning("PlayerSkills: '%s' has no effect yet" % what)


func to_save() -> Dictionary:
	return {"aether": aether, "owned": owned.duplicate(), "tree_open": tree_open}


## Continue: back as saved, quietly. The save file layer has already checked the types.
func restore(data: Dictionary) -> void:
	aether = int(data.get("aether", 0))
	tree_open = data.get("tree_open", false) == true
	for id: String in data.get("owned", []):
		unlock(id)
