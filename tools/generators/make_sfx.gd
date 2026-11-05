extends SceneTree
# Synthesizes every sound effect in the game as a 16-bit mono 22050 Hz WAV in res://audio/.
# No audio files from the internet: each sound is a small function below, built from sines,
# noise and simple filters, with its numbers at the top so you can tweak them.
# Run (Godot closed):
#   godot --headless --path PROJ -s make_sfx.gd      then      godot --headless --path PROJ --import
# Loops (neon_hum, cube_drone, vending_hum, running_water) carry a "smpl" chunk, so Godot's WAV importer
# sets loop_mode = Forward on them by itself ("Detect From WAV", the default import setting).

const RATE := 22050
const OUT_DIR := "res://audio"
const CRUNCH_BITS := 9  # samples are quantised to this many bits: the PS1 "a little crunchy" grain

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20261024
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for i in 3:
		_save("footstep_plates_%d" % (i + 1), _footstep_plates(i), false)
		_save("footstep_pavement_%d" % (i + 1), _footstep_pavement(i), false)
		_save("footstep_concrete_%d" % (i + 1), _footstep_concrete(i), false)
	_save("neon_hum", _neon_hum(), true)
	_save("cube_drone", _cube_drone(), true)
	_save("vending_hum", _vending_hum(), true)
	_save("running_water", _running_water(), true)
	_save("parry_clang", _parry_clang(), false)
	_save("swing_whoosh", _swing_whoosh(), false)
	_save("swing_heavy", _swing_heavy(), false)
	_save("hit_thud", _hit_thud(), false)
	_save("takedown_stab", _takedown_stab(), false)
	_save("ui_blip", _ui_blip(), false)
	_save("ui_choose", _ui_choose(), false)
	_save("ui_advance", _ui_advance(), false)
	print("sfx written to ", OUT_DIR)
	quit()


# ---------------------------------------------------------------- the sounds

## Footsteps (remade 2026-11-05, the author: the old ones "stink"): every step is two touches,
## the heel then, 70 ms later, the ball of the foot, both soft and low. No click at the front:
## the heel eases in over 6 ms. A boot on each floor:
##   plates: the heel knocks the plate (a low thump with a short metallic buzz), the toe scuffs it
##   pavement: a dull heel thud and a gritty toe scuff
##   concrete: softer still, more scuff than knock
const TOE_AFTER := 0.07   # seconds from the heel touching to the ball of the foot


func _touch(b: PackedFloat32Array, start: float, amp: float, decay: float, cutoff: float, ease: float) -> void:
	var part := _buf(float(b.size()) / RATE)
	_noise(part, 1.0, decay, cutoff, start)
	_envelope_from(part, start, ease)
	_mix(b, part, amp)


## Eases a sound in from `start` over `ease` seconds (a scuff, not a click).
func _envelope_from(b: PackedFloat32Array, start: float, ease: float) -> void:
	var first := int(start * RATE)
	var n := int(ease * RATE)
	for i in range(first, mini(first + n, b.size())):
		b[i] *= float(i - first) / n


func _footstep_plates(variant: int) -> PackedFloat32Array:
	var pitch: float = [0.94, 1.0, 1.07][variant]
	var b := _buf(0.22)
	_touch(b, 0.0, 1.0, 0.03, 420.0 * pitch, 0.006)              # the heel: a low knock
	var buzz := _buf(0.22)
	_noise(buzz, 1.0, 0.03, 2200.0 * pitch, 0.004)
	buzz = _highpass(buzz, 900.0)
	_envelope_from(buzz, 0.004, 0.006)
	_mix(b, buzz, 0.25)                                            # the plate ringing, faint
	_sine(b, 120.0 * pitch, 0.35, 0.03)
	_touch(b, TOE_AFTER, 0.45, 0.035, 1400.0 * pitch, 0.01)        # the toe: a scuff
	return _finish(b, 0.4, CRUNCH_BITS)


func _footstep_pavement(variant: int) -> PackedFloat32Array:
	var pitch: float = [0.92, 1.0, 1.09][variant]
	var b := _buf(0.2)
	_touch(b, 0.0, 1.0, 0.035, 300.0 * pitch, 0.006)              # the heel: dull, with weight
	_touch(b, 0.0, 0.3, 0.012, 1100.0 * pitch, 0.004)             # a little grit on top
	_touch(b, TOE_AFTER, 0.5, 0.04, 900.0 * pitch, 0.012)         # the toe: gritty scuff
	return _finish(b, 0.36, 8)


func _footstep_concrete(variant: int) -> PackedFloat32Array:
	var pitch: float = [0.9, 1.0, 1.1][variant]
	var b := _buf(0.2)
	_touch(b, 0.0, 0.8, 0.03, 260.0 * pitch, 0.008)               # the heel: soft
	_touch(b, TOE_AFTER, 0.6, 0.05, 1600.0 * pitch, 0.015)        # the toe: a hiss of a scuff
	return _finish(b, 0.3, 8)


## A neon sign: a 110 Hz buzz with its harmonics, flickering a little. Loops every 1.5 s
## (every frequency in it is a whole number of cycles per 1.5 s, so the seam is silent).
func _neon_hum() -> PackedFloat32Array:
	var length := 1.5
	var base := 110.0
	var b := _buf(length)
	for n in range(1, 8):
		var amp := 0.5 / n * (1.3 if n % 2 == 1 else 1.0)  # odd harmonics louder: buzzier
		_sine(b, base * n, amp, 0.0)
	_noise(b, 0.03, 0.0, 3000.0, 0.0)                  # tube hiss
	_flicker(b, length, [[4.0, 0.12, 0.0], [7.0, 0.08, 1.0], [23.0, 0.05, 2.0]])  # cycles per loop, depth, phase
	return _finish(b, 0.5, CRUNCH_BITS, false)


## The Black Cube: a 48 Hz tone against one a third of a hertz off, so they beat slowly
## (one swell every 3 s, the loop length), a sub-tone, and a faint high whine.
func _cube_drone() -> PackedFloat32Array:
	var length := 3.0
	var b := _buf(length)
	_sine(b, 48.0, 0.6, 0.0)
	_sine(b, 48.0 + 1.0 / length, 0.5, 0.0)          # the beat
	_sine(b, 24.0, 0.3, 0.0)                           # sub
	_sine(b, 96.0, 0.15, 0.0)
	var whine := _buf(length)
	_sine(whine, 2400.0, 1.0, 0.0)
	_flicker(whine, length, [[1.0, 0.5, 1.5]])         # the whine swells once per loop
	_mix(b, whine, 0.04)
	return _finish(b, 0.6, 10, false)


## A vending machine's transformer: a soft 60 Hz hum. Loops every 1.5 s.
func _vending_hum() -> PackedFloat32Array:
	var length := 1.5
	var b := _buf(length)
	for p in [[60.0, 0.5], [120.0, 0.25], [180.0, 0.1], [240.0, 0.05]]:
		_sine(b, p[0], p[1], 0.0)
	_noise(b, 0.02, 0.0, 800.0, 0.0)
	_flicker(b, length, [[2.0, 0.06, 0.0]])
	return _finish(b, 0.4, 10, false)



## The tap at the well: a thin stream falling into a basin of water, like a sink or a garden hose
## (round 8: the old one was broad noise and sounded like a river). Two parts: the stream's
## hiss (band-limited noise, no low end), the trickle (lots of tiny bubbles: short sine chirps
## that rise in pitch, 700-2600 Hz). Loops every 3 s: bubbles that run past
## the end wrap to the start, and the noise's last 0.1 s is crossfaded into its start.
## It has its own random generator; the shared one is stepped as far as the old version stepped
## it, so the sounds after this one come out exactly as before.
func _running_water() -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = 8808
	var length := 3.0
	var n := int(length * RATE)
	var hiss := PackedFloat32Array()
	hiss.resize(n + int(0.1 * RATE))
	var lp := 0.0
	var k := _lp_coefficient(4200.0)
	for i in hiss.size():
		lp += k * (r.randf_range(-1.0, 1.0) - lp)
		hiss[i] = lp
	hiss = _highpass(_highpass(hiss, 900.0), 900.0)
	var xf := hiss.size() - n
	for i in xf:
		var g := float(i) / xf
		hiss[i] = hiss[i] * g + hiss[n + i] * (1.0 - g)
	hiss.resize(n)
	_flicker(hiss, length, [[7.0, 0.18, 0.0], [17.0, 0.12, 2.1], [29.0, 0.08, 0.7]])  # the stream wavers
	var b := _buf(length)
	_mix(b, hiss, 0.22)
	# The trickle: about 40 bubbles a second, most small and quiet, a few bigger "blips".
	for j in int(40 * length):
		var start := r.randi_range(0, n - 1)
		var f0 := r.randf_range(700.0, 2600.0)
		var rise := r.randf_range(1.15, 1.5)
		var dur := r.randf_range(0.006, 0.03)
		var amp := r.randf_range(0.05, 0.22) * (2.0 if r.randf() < 0.08 else 1.0)
		var phase := 0.0
		for i in int(dur * 3.0 * RATE):
			var t := float(i) / RATE
			phase += TAU * f0 * lerpf(1.0, rise, clampf(t / dur, 0.0, 1.0)) / RATE
			b[(start + i) % n] += amp * exp(-t / dur) * sin(phase)
	for i in 2 * int(2.1 * RATE):
		_rng.randf()  # keep the shared random stream where the old version left it
	return _finish(b, 0.42, 10, false)

## Steel on steel: a bright strike whose partials die at different speeds.
func _parry_clang() -> PackedFloat32Array:
	var b := _buf(0.7)
	var strike := _buf(0.7)
	_noise(strike, 0.8, 0.008, 9000.0, 0.0)
	_mix(b, _highpass(strike, 1500.0), 1.0)
	for p in [[870.0, 0.3, 0.35], [1750.0, 0.5, 0.28], [2630.0, 0.4, 0.22], [3920.0, 0.3, 0.16], [5230.0, 0.2, 0.1]]:
		_sine(b, p[0], p[1], p[2])
	return _finish(b, 0.85, CRUNCH_BITS)


## The blade through the air: noise whose brightness sweeps up and back down. Deeper than it was
## (2026-11-05): the cuts are low and heavy now, so it starts dark and the hold is longer.
func _swing_whoosh() -> PackedFloat32Array:
	var b := _buf(0.34)
	_noise(b, 1.0, 0.0, 20000.0, 0.0)
	b = _lowpass_sweep(b, 250.0, 2000.0, 400.0)        # cutoff: start, middle, end
	b = _highpass(b, 180.0)
	_envelope(b, 0.07, 0.06, 0.18)                     # attack, hold, release (s)
	return _finish(b, 0.6, 8)


## The cleave: a longer, darker whoosh with a low body behind it, like a bigger blade moving.
func _swing_heavy() -> PackedFloat32Array:
	var b := _buf(0.5)
	_noise(b, 1.0, 0.0, 20000.0, 0.0)
	b = _lowpass_sweep(b, 180.0, 1500.0, 260.0)
	b = _highpass(b, 120.0)
	_envelope(b, 0.12, 0.08, 0.24)
	var body := _buf(0.5)
	_glide(body, 110.0, 60.0, 0.3, 1.0, 0.16)
	_envelope(body, 0.1, 0.05, 0.2)
	_mix(b, body, 0.35)
	return _finish(b, 0.65, 8)


## A body blow: a low tone that drops in pitch, under a short dull burst.
func _hit_thud() -> PackedFloat32Array:
	var b := _buf(0.28)
	_glide(b, 95.0, 45.0, 0.15, 1.0, 0.09)             # from Hz, to Hz, glide s, amp, decay s
	_noise(b, 0.7, 0.015, 900.0, 0.0)
	return _finish(b, 0.85, CRUNCH_BITS)


## The knife: a short muffled impact with a brief wet give. Kept small and low.
func _takedown_stab() -> PackedFloat32Array:
	var b := _buf(0.35)
	_noise(b, 0.9, 0.02, 1800.0, 0.0)                  # cloth and impact
	_noise(b, 0.9, 0.035, 220.0, 0.0)                  # the thump: low noise, not a tuned note
	var wet := _buf(0.35)
	_noise(wet, 1.0, 0.0, 20000.0, 0.0)
	wet = _lowpass_sweep(wet, 1200.0, 500.0, 250.0)
	_envelope(wet, 0.02, 0.0, 0.14)
	_mix(b, wet, 0.35)
	return _finish(b, 0.75, 8)


## The UI sounds (2026-10-26, the author found the old square-wave ping "the most annoying sound
## ever"): soft, low, rounded tones like a felt mallet on a wooden bar. Sines only, a 5-6 ms
## eased attack (no click), a gentle decay, a touch of low-passed noise for the "paper" of it.
## No crunch here (16 bits): quantising a quiet tone adds a gritty hiss.

## Moving the highlight in a menu: a soft wooden "tok", around C5 with a warm octave under it.
func _ui_blip() -> PackedFloat32Array:
	var b := _buf(0.2)
	_soft_tone(b, 523.25, 0.55, 0.006, 0.05)   # the note (Hz, amp, attack s, decay s)
	_soft_tone(b, 261.63, 0.35, 0.006, 0.07)   # the body, an octave down
	_soft_tone(b, 1046.5, 0.05, 0.004, 0.02)   # a breath of overtone so it isn't dull
	_felt(b, 0.12, 1400.0)
	return _finish(b, 0.4, 16)


## Choosing something: two soft notes a fifth apart (G4 then D5), a little longer.
func _ui_choose() -> PackedFloat32Array:
	var b := _buf(0.42)
	_soft_tone(b, 392.0, 0.5, 0.006, 0.09)
	_soft_tone(b, 196.0, 0.3, 0.006, 0.11)
	var second := _buf(0.42)
	_soft_tone(second, 587.33, 0.42, 0.008, 0.11)
	_soft_tone(second, 293.66, 0.2, 0.008, 0.12)
	var delay := int(0.055 * RATE)
	for i in range(delay, b.size()):
		b[i] += second[i - delay]
	_felt(b, 0.1, 1200.0)
	return _finish(b, 0.45, 16)


## Moving a dialogue line on: the softest of all, a low muted tap (G4 with D4 under it), short.
func _ui_advance() -> PackedFloat32Array:
	var b := _buf(0.16)
	_soft_tone(b, 392.0, 0.45, 0.005, 0.035)
	_soft_tone(b, 293.66, 0.35, 0.005, 0.05)
	_felt(b, 0.18, 900.0)
	return _finish(b, 0.3, 16)


## A sine with an eased attack (a raised-cosine ramp) and an exponential decay.
func _soft_tone(b: PackedFloat32Array, freq: float, amp: float, attack: float, decay: float) -> void:
	for i in b.size():
		var t := float(i) / RATE
		var env := exp(-t / decay)
		if t < attack:
			env *= 0.5 - 0.5 * cos(PI * t / attack)
		b[i] += amp * env * sin(TAU * freq * t)


## A felt / paper touch: low-passed noise, eased in over 3 ms, gone in about 10 ms.
func _felt(b: PackedFloat32Array, amp: float, cutoff: float) -> void:
	var touch := _buf(float(b.size()) / RATE)
	_noise(touch, amp, 0.01, cutoff, 0.0)
	_envelope(touch, 0.003, 0.0, 0.01)
	_mix(b, touch, 1.0)


# ---------------------------------------------------------------- building blocks

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	b.fill(0.0)
	return b


## Adds a sine at `freq` Hz; `decay` seconds (0 = steady, for loops).
func _sine(b: PackedFloat32Array, freq: float, amp: float, decay: float) -> void:
	for i in b.size():
		var t := float(i) / RATE
		var env := 1.0 if decay <= 0.0 else exp(-t / decay)
		b[i] += amp * env * sin(TAU * freq * t)


## A sine whose pitch slides from f0 to f1 over `glide` seconds, dying away over `decay`.
func _glide(b: PackedFloat32Array, f0: float, f1: float, glide: float, amp: float, decay: float) -> void:
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := lerpf(f0, f1, clampf(t / glide, 0.0, 1.0))
		phase += TAU * f / RATE
		b[i] += amp * exp(-t / decay) * sin(phase)


## Adds white noise through a one-pole lowpass, fading over `decay` seconds (0 = steady).
func _noise(b: PackedFloat32Array, amp: float, decay: float, cutoff: float, start: float) -> void:
	var k := _lp_coefficient(cutoff)
	var y := 0.0
	var first := int(start * RATE)
	for i in range(first, b.size()):
		var t := float(i - first) / RATE
		y += k * (_rng.randf_range(-1.0, 1.0) - y)
		var env := 1.0 if decay <= 0.0 else exp(-t / decay)
		b[i] += amp * env * y


## Slow amplitude wobble that repeats exactly every `length` seconds: each entry is
## [cycles per loop, depth, phase].
func _flicker(b: PackedFloat32Array, length: float, lfos: Array) -> void:
	for i in b.size():
		var t := float(i) / RATE
		var gain := 1.0
		for l in lfos:
			gain += l[1] * sin(TAU * l[0] / length * t + l[2])
		b[i] *= gain


func _mix(into: PackedFloat32Array, from: PackedFloat32Array, gain: float) -> void:
	for i in mini(into.size(), from.size()):
		into[i] += from[i] * gain


func _envelope(b: PackedFloat32Array, attack: float, hold: float, release: float) -> void:
	var n := b.size()
	for i in n:
		var t := float(i) / RATE
		var g := 1.0
		if t < attack:
			g = t / attack
		elif t > attack + hold:
			g = exp(-(t - attack - hold) / release)
		b[i] *= g


func _lp_coefficient(cutoff: float) -> float:
	return clampf(1.0 - exp(-TAU * cutoff / RATE), 0.0, 1.0)


func _highpass(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(b.size())
	var k := _lp_coefficient(cutoff)
	var low := 0.0
	for i in b.size():
		low += k * (b[i] - low)
		out[i] = b[i] - low
	return out


## A lowpass whose cutoff moves start -> mid -> end across the buffer (a whoosh).
func _lowpass_sweep(b: PackedFloat32Array, c_start: float, c_mid: float, c_end: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(b.size())
	var y := 0.0
	var n := b.size()
	for i in n:
		var u := float(i) / n
		var cutoff := lerpf(c_start, c_mid, u * 2.0) if u < 0.5 else lerpf(c_mid, c_end, (u - 0.5) * 2.0)
		y += _lp_coefficient(cutoff) * (b[i] - y)
		out[i] = y
	return out


## Peak-normalise to `peak`, then quantise to `bits` (the crunch), then a 2 ms fade at both
## ends so nothing clicks.
## Loops pass fade_ends = false: they are whole cycles and must join without a dip at the seam.
func _finish(b: PackedFloat32Array, peak: float, bits: int, fade_ends := true) -> PackedFloat32Array:
	var biggest := 0.0001
	for v in b:
		biggest = maxf(biggest, absf(v))
	var steps := float(1 << (bits - 1))
	var fade := int(0.002 * RATE)
	var n := b.size()
	for i in n:
		var v: float = b[i] / biggest * peak
		v = round(v * steps) / steps
		if fade_ends and i < fade:
			v *= float(i) / fade
		elif fade_ends and i >= n - fade:
			v *= float(n - 1 - i) / fade
		b[i] = clampf(v, -1.0, 1.0)
	return b


## RIFF/WAVE, PCM 16-bit mono. Loops get a "smpl" chunk (forward loop over the whole file).
func _wav_bytes(b: PackedFloat32Array, loop: bool) -> PackedByteArray:
	var s := StreamPeerBuffer.new()
	var data_size := b.size() * 2
	var smpl_size := 68 if loop else 0  # 8 header + 60 payload
	s.put_data("RIFF".to_ascii_buffer())
	s.put_u32(4 + 24 + 8 + data_size + smpl_size)
	s.put_data("WAVE".to_ascii_buffer())
	s.put_data("fmt ".to_ascii_buffer())
	s.put_u32(16)
	s.put_u16(1)          # PCM
	s.put_u16(1)          # mono
	s.put_u32(RATE)
	s.put_u32(RATE * 2)   # bytes per second
	s.put_u16(2)          # block align
	s.put_u16(16)         # bits
	s.put_data("data".to_ascii_buffer())
	s.put_u32(data_size)
	for v in b:
		s.put_16(int(round(v * 32767.0)))
	if loop:
		s.put_data("smpl".to_ascii_buffer())
		s.put_u32(60)
		for i in 7:
			s.put_u32(0)  # manufacturer, product, period, unity note, pitch fraction, SMPTE x2
		s.put_u32(1)      # one loop
		s.put_u32(0)      # no extra sampler data
		s.put_u32(0)      # cue id
		s.put_u32(0)      # type 0 = forward
		s.put_u32(0)      # start sample
		s.put_u32(b.size())  # end sample (Godot reads it as exclusive, so the last frame stays in the loop)
		s.put_u32(0)      # fraction
		s.put_u32(0)      # play count: forever
	return s.data_array


func _save(name: String, b: PackedFloat32Array, loop: bool) -> void:
	# SFX_ONLY=name,name writes just those files (every sound is still built, so the random
	# stream, and with it every other sound, stays the same).
	var only := OS.get_environment("SFX_ONLY")
	if only != "" and not only.split(",").has(name):
		return
	var path := "%s/%s.wav" % [OUT_DIR, name]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + path)
		return
	f.store_buffer(_wav_bytes(b, loop))
	f.close()
	print("  %-22s %.2f s%s" % [name, float(b.size()) / RATE, "  (loop)" if loop else ""])
