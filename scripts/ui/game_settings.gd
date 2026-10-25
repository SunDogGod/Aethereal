class_name GameSettings
extends RefCounted
## The player's settings: volumes (master, music, effects), camera speeds, invert Y,
## fullscreen. Saved to user://settings.cfg and loaded the first time anything reads them.
## Gameplay scripts read them straight from here (GameSettings.mouse_sensitivity), never
## through an autoload. The PauseMenu autoload calls apply() once at startup; the Settings
## screen (settings_panel.gd) changes them with set_value() and saves.

const PATH := "user://settings.cfg"

static var master_volume := 1.0      ## 0 = silent, 1 = full
static var music_volume := 1.0       ## the Music bus (music and ambience beds)
static var effects_volume := 1.0     ## the SFX bus (every sound effect and level hum)
static var mouse_sensitivity := 1.0  ## times the camera's own mouse speed
static var stick_sensitivity := 1.0  ## times the camera's own right-stick speed
static var invert_y := false         ## true: push up / move the mouse up to look down
static var fullscreen := false


static func _static_init() -> void:
	load_file()


## Back to the defaults above (used by the test).
static func reset() -> void:
	master_volume = 1.0
	music_volume = 1.0
	effects_volume = 1.0
	mouse_sensitivity = 1.0
	stick_sensitivity = 1.0
	invert_y = false
	fullscreen = false


static func load_file(path := PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return  # no file yet: keep the defaults
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	effects_volume = clampf(float(cfg.get_value("audio", "effects_volume", effects_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(cfg.get_value("camera", "mouse_sensitivity", mouse_sensitivity)), 0.1, 5.0)
	stick_sensitivity = clampf(float(cfg.get_value("camera", "stick_sensitivity", stick_sensitivity)), 0.1, 5.0)
	invert_y = bool(cfg.get_value("camera", "invert_y", invert_y))
	fullscreen = bool(cfg.get_value("screen", "fullscreen", fullscreen))


static func save_file(path := PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "effects_volume", effects_volume)
	cfg.set_value("camera", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("camera", "stick_sensitivity", stick_sensitivity)
	cfg.set_value("camera", "invert_y", invert_y)
	cfg.set_value("screen", "fullscreen", fullscreen)
	cfg.save(path)


## Puts the volumes and the window mode into effect.
static func apply() -> void:
	apply_volumes()
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## The three volumes onto their buses (Music and SFX come from default_bus_layout.tres).
static func apply_volumes() -> void:
	for pair: Array in [["Master", master_volume], ["Music", music_volume], ["SFX", effects_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus < 0:
			continue
		var v: float = pair[1]
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(bus, v <= 0.001)


## -1 when the camera's up/down is inverted, else 1. The camera multiplies its pitch by this.
static func y_sign() -> float:
	return -1.0 if invert_y else 1.0


## Read and write a setting by name (the Settings screen builds its rows from names).
static func get_value(key: String) -> Variant:
	match key:
		"master_volume": return master_volume
		"music_volume": return music_volume
		"effects_volume": return effects_volume
		"mouse_sensitivity": return mouse_sensitivity
		"stick_sensitivity": return stick_sensitivity
		"invert_y": return invert_y
		"fullscreen": return fullscreen
	return null


static func set_value(key: String, value: Variant) -> void:
	match key:
		"master_volume": master_volume = float(value)
		"music_volume": music_volume = float(value)
		"effects_volume": effects_volume = float(value)
		"mouse_sensitivity": mouse_sensitivity = float(value)
		"stick_sensitivity": stick_sensitivity = float(value)
		"invert_y": invert_y = bool(value)
		"fullscreen": fullscreen = bool(value)
