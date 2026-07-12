class_name BlockSfx
extends Node
## Short Minecraft-style place/break sounds, synthesized at startup so the
## project carries no audio assets. Each play gets a small random pitch
## wobble like Minecraft's.

const RATE := 22050

var _place: AudioStreamWAV
var _break: AudioStreamWAV
var _player: AudioStreamPlayer

func _ready() -> void:
	_place = _make_place()
	_break = _make_break()
	_player = AudioStreamPlayer.new()
	_player.max_polyphony = 4
	_player.volume_db = -6.0
	add_child(_player)

func play_place() -> void:
	_play(_place)

func play_break() -> void:
	_play(_break)

func _play(stream: AudioStreamWAV) -> void:
	_player.stream = stream
	_player.pitch_scale = randf_range(0.88, 1.12)
	_player.play()

## Soft "thock": quick downward pitch sweep with a touch of noise.
func _make_place() -> AudioStreamWAV:
	var n := int(RATE * 0.07)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq := lerpf(620.0, 190.0, t / 0.07)
		phase += TAU * freq / RATE
		var s := sin(phase) * exp(-t * 48.0)
		s += (randf() * 2.0 - 1.0) * 0.25 * exp(-t * 90.0)
		samples[i] = s * 0.8
	return _to_wav(samples)

## Crunchier "break": decaying noise over a low thump.
func _make_break() -> AudioStreamWAV:
	var n := int(RATE * 0.12)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var brown := 0.0
	for i in n:
		var t := float(i) / RATE
		brown = clampf(brown + (randf() * 2.0 - 1.0) * 0.4, -1.0, 1.0)
		phase += TAU * 130.0 / RATE
		var s := brown * exp(-t * 26.0)
		s += sin(phase) * 0.45 * exp(-t * 34.0)
		samples[i] = s * 0.8
	return _to_wav(samples)

func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
