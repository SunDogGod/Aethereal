class_name SkillData
extends Resource
## One skill in the skill tree (pause menu → Skills), bought with Aether. A new skill is a new
## .tres in data/skills/; `id` is what PlayerSkills.unlock() turns on, so a skill that changes how
## Aeneas plays also needs a line there.

@export var id := ""                    ## e.g. "double_jump"
@export var title := ""                 ## what the menu shows
@export_multiline var description := ""
@export var cost := 1                   ## Aether
@export var order := 0                  ## lower comes first in the list
