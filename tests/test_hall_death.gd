extends "test_hall.gd"
# Headless test: die to the captain BEFORE half health (the 2026-10-26 story). Aeneas should restart
# in the hall (the capture's teleport moved the checkpoint there), every agent killed before should
# stay down, Valentina stays gone, and the captain fight starts again. Prints HALL DEATH PASS/FAIL.
# The flow up to the captain is test_hall.gd's.


func _initialize() -> void:
	OS.set_environment("HALL_DEATH", "1")
	_run()
