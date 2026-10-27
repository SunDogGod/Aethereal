extends "../test_hall.gd"
# (World copy of test_hall.gd: the same, inside scenes/world/world.tscn.) The Empty Town's ending
# (the 2026-10-26 story), from the Valentina fight to the hand-off to the Massacre.


func _initialize() -> void:
	OS.set_environment("HALL_WORLD", "1")
	_run()
