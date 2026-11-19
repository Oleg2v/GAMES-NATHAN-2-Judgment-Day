extends Node
## Small original synthesized effects, cached as PCM resources.
var sounds: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var next := 0

func _ready() -> void:
	for index in range(8):
		var player := AudioStreamPlayer.new()
		add_child(player)
		pool.append(player)
	for kind in ["hit", "heavy", "step", "break", "whoosh"]:
		sounds[kind] = _synthesize(kind)

func play(kind: String, volume := -8.0) -> void:
	if not sounds.has(kind) or pool.is_empty():
		return
	var player := pool[next]
	next = (next + 1) % pool.size()
	player.stream = sounds[kind]
	player.pitch_scale = randf_range(0.92, 1.08)
	player.volume_db = volume
	player.play()

func _synthesize(kind: String) -> AudioStreamWAV:
	var duration := 0.16
	if kind == "heavy": duration = 0.25
	if kind == "break": duration = 0.65
	if kind == "step": duration = 0.085
	if kind == "whoosh": duration = 0.22
	var rate := 22050
	var count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var smooth_noise := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4361 + kind.hash()
	for index in range(count):
		var time := float(index) / rate
		var t := time / duration
		var white := rng.randf_range(-1.0, 1.0)
		smooth_noise = lerpf(smooth_noise, white, 0.18)
		var envelope := pow(1.0 - t, 3.0) * minf(1.0, t * 70.0)
		var value := sin(TAU * (95.0 * time - 100.0 * time * time)) * 0.65 + white * 0.15
		match kind:
			"heavy": value = sin(TAU * (62.0 * time - 40.0 * time * time)) * 0.68 + smooth_noise * 0.8
			"break": value = white * 0.35 + sin(time * 2700.0) * exp(-fmod(time, 0.055) * 90.0) * 0.25
			"step": value = smooth_noise * 1.4 + sin(time * TAU * 120.0) * 0.22
			"whoosh": value = smooth_noise * sin(t * PI) * 1.5
		bytes.encode_s16(index * 2, int(clampf(value * envelope, -1.0, 1.0) * 25000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
