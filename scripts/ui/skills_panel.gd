class_name SkillsPanel
extends PanelContainer
## The pause menu's Skills page: his Aether, and every skill in data/skills/ with its price.
## Pressing a skill he can afford buys it at once (PlayerSkills.buy). The page only shows in the
## pause menu once a story scene has opened the skill tree ([unlock skill_tree]).

signal closed

const WIDTH := 420.0

var _list := VBoxContainer.new()
var _aether := Label.new()
var _about := Label.new()
var _rows: Array[MenuItem] = []
var _skills: PlayerSkills


func _ready() -> void:
	custom_minimum_size.x = WIDTH
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)


## Shows the page for this player's skills, the first skill highlighted.
func open(skills: PlayerSkills) -> void:
	_skills = skills
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	var header := Label.new()
	header.text = "SKILLS"
	header.theme_type_variation = "HeaderLabel"
	_list.add_child(header)
	_aether = Label.new()
	_list.add_child(_aether)
	_list.add_child(_rule())
	for skill in PlayerSkills.all():
		var row := MenuItem.make(skill.title, WIDTH - 32.0, _buy.bind(skill), "")
		row.focus_entered.connect(_describe.bind(skill))
		_rows.append(row)
		_list.add_child(row)
	_list.add_child(_rule())
	_about = Label.new()
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.custom_minimum_size = Vector2(WIDTH - 32.0, 44.0)
	_about.modulate = Color(1, 1, 1, 0.75)
	_list.add_child(_about)
	var back := MenuItem.make("Back", WIDTH - 32.0, close)
	back.focus_entered.connect(func() -> void: _about.text = "")
	_list.add_child(back)
	_refresh()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	await get_tree().process_frame  # the rows are in the tree now
	focus_first()


func focus_first() -> void:
	if not _rows.is_empty():
		MenuFx.focus_quietly(_rows[0])


func close() -> void:
	visible = false
	closed.emit()


func _buy(skill: SkillData) -> void:
	_skills.buy(skill)
	_refresh()
	_describe(skill)


func _refresh() -> void:
	_aether.text = "Aether  %d" % _skills.aether
	var all := PlayerSkills.all()
	for i in _rows.size():
		var skill: SkillData = all[i]
		_rows[i].set_detail("owned" if _skills.owned.has(skill.id) else "%d Aether" % skill.cost)


func _describe(skill: SkillData) -> void:
	var line := skill.description
	if not _skills.owned.has(skill.id) and _skills.aether < skill.cost:
		line += "\nNot enough Aether."
	_about.text = line


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = MenuFx.LINE
	rule.custom_minimum_size.y = 1
	return rule
