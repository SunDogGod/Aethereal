class_name GuardData
extends Resource
## The numbers and look for one kind of guard. For a new kind of guard, make a new
## .tres file in data/enemies/ (right-click > New Resource > GuardData) instead of a new script.

@export var display_name := "Agency agent"

@export_group("Look")
@export var coat_color := Color(0.08, 0.08, 0.1)
@export var visor_color := Color(1.0, 0.15, 0.1)  ## the eye-light that shows where he's looking

@export_group("Patrol")
@export var walk_speed := 1.6   ## metres per second
@export var turn_speed := 5.0
@export var wait_time := 1.5    ## seconds he waits at each point of his route

@export_group("Sight")
@export var sight_range := 14.0                 ## metres he can see a standing Aeneas
@export_range(10.0, 180.0) var sight_angle := 100.0  ## width of his view, in degrees
@export var crouch_sight_multiplier := 0.55     ## crouched, Aeneas is only seen within this share of the range
@export var notice_time := 1.2                  ## seconds to spot Aeneas up close (longer far away)
@export var forget_rate := 0.4                  ## how fast suspicion fades once he loses sight

@export_group("Fighting")
@export var health := 60.0
@export var attack_damage := 18.0
@export var attack_windup := 0.6     ## seconds of red flash before the blade lands
@export var attack_range := 1.7
@export var attack_cooldown := 1.2   ## seconds between swings (randomised a little)
@export var fight_speed := 3.2       ## metres per second when closing in
@export var unblockable := false     ## true = blocks and parries don't work (the empowered captain)
