extends CanvasLayer
## The slow passage into a memory, over the whole screen (shaders/hall_memory.gdshader):
##   out(seconds)   the hall's end ([call MemoryFade out 2.8]): the picture goes soft and pale and
##                  sinks into black, and the hall's sounds and the music fade away with it.
##                  Follow it with a [wait] as long, and the scene's [level] line finds it black.
##   open(seconds)  from black into a pale, soft dream that settles into the scene.
## `open_on_start` (the Massacre) opens by itself as the level starts, under Story's own short
## fade-in. Set `layer` above 15 (the dialogue box) to cover the text too, below it to keep the
## text on top. The PS1 filter (layer 50) stays above it, so the dither covers the fade too.

const SHADER := preload("res://shaders/hall_memory.gdshader")

## Opens from black as soon as the level starts (the Massacre).
@export var open_on_start := false
@export var open_seconds := 4.5
## Sounds (AudioStreamPlayer / AudioStreamPlayer3D) faded out with out(): the fire, the cube's drone.
@export var sounds: Array[NodePath] = []

var _rect := ColorRect.new()
var _mat := ShaderMaterial.new()
var _tween: Tween


func _ready() -> void:
	_mat.shader = SHADER
	_rect.material = _mat
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_set_look(0.0, 0.0)
	_rect.visible = false
	if open_on_start:
		open(open_seconds)


## Into black, slowly, the picture going soft on the way.
func out(seconds := 2.8) -> void:
	_restart()
	_rect.visible = true
	_tween.set_parallel(true)
	_tween.tween_method(func(v: float) -> void: _mat.set_shader_parameter("black", v), 0.0, 1.0, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_method(func(v: float) -> void: _mat.set_shader_parameter("dream", v), 0.0, 0.8, seconds * 0.7)
	MusicBus.stop(seconds)
	for path in sounds:
		var s := get_node_or_null(path)
		if s is AudioStreamPlayer3D or s is AudioStreamPlayer:
			_tween.tween_property(s, "volume_db", -60.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Out of black into a pale dream, which then settles into the scene as it is.
func open(seconds := 4.5) -> void:
	_restart()
	_rect.visible = true
	_set_look(1.0, 1.0)
	_tween.tween_interval(0.3)
	_tween.tween_method(func(v: float) -> void: _mat.set_shader_parameter("black", v), 1.0, 0.0, seconds * 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(v: float) -> void: _mat.set_shader_parameter("dream", v), 1.0, 0.0, seconds * 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void: _rect.visible = false)


func _restart() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()


func _set_look(black: float, dream: float) -> void:
	_mat.set_shader_parameter("black", black)
	_mat.set_shader_parameter("dream", dream)
