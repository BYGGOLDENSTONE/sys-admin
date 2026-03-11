extends Node

## Procedural sound system — all sounds generated from code, zero external assets.

var _sfx_players: Array[AudioStreamPlayer] = []
var _ambient_player: AudioStreamPlayer = null
var _sounds: Dictionary = {}
var _sfx_volume_offset: float = 0.0

const SFX_POOL_SIZE: int = 8
const SAMPLE_RATE: int = 22050
const AMBIENT_BASE_DB: float = -18.0


func _ready() -> void:
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.volume_db = AMBIENT_BASE_DB
	add_child(_ambient_player)
	_generate_sounds()
	_start_ambient()
	apply_settings()


func play(sound_name: String, volume_db: float = -6.0, pitch_variance: float = 0.05) -> void:
	if not _sounds.has(sound_name):
		return
	var player := _get_free_player()
	if player == null:
		return
	player.stream = _sounds[sound_name]
	player.volume_db = volume_db + _sfx_volume_offset
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


func play_building_place() -> void:
	play("place_thud", -8.0)
	play("place_chirp", -12.0)


func play_building_remove() -> void:
	play("remove_whoosh", -10.0)


func play_cable_connect() -> void:
	play("cable_snap", -10.0)
	play("cable_resonance", -14.0)


func play_cable_remove() -> void:
	play("cable_pop", -10.0)


func play_discovery() -> void:
	play("discovery_chime", -6.0, 0.0)


func play_unlock() -> void:
	play("unlock_fanfare", -4.0, 0.0)


func play_process_event(building_type: String) -> void:
	match building_type:
		"decryptor":
			play("process_crack", -14.0)
		"compiler":
			play("process_synth", -14.0)
		"quarantine":
			play("quarantine_flush", -10.0)
		_:
			play("process_tick", -16.0)


func play_ui_hover() -> void:
	play("ui_hover", -20.0, 0.1)


func play_ui_click() -> void:
	play("ui_click", -16.0, 0.05)


func set_ambient_volume(db: float) -> void:
	_ambient_player.volume_db = db


func apply_settings() -> void:
	## Read SFX and ambient volumes from SettingsManager and apply.
	var settings := SettingsManager.get_settings()
	var sfx_pct: int = clampi(int(settings.get("sfx_volume", 80)), 0, 100)
	if sfx_pct > 0:
		_sfx_volume_offset = linear_to_db(sfx_pct / 100.0)
	else:
		_sfx_volume_offset = -80.0
	var ambient_pct: int = clampi(int(settings.get("ambient_volume", 50)), 0, 100)
	if ambient_pct > 0:
		_ambient_player.volume_db = AMBIENT_BASE_DB + linear_to_db(ambient_pct / 100.0)
	else:
		_ambient_player.volume_db = -80.0
	print("[SoundManager] Settings applied — SFX offset: %.1f dB, Ambient: %.1f dB" % [_sfx_volume_offset, _ambient_player.volume_db])


# --- Player pool ---

func _get_free_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]


# --- Sound generation ---

func _generate_sounds() -> void:
	# Building
	_sounds["place_thud"] = _gen(70.0, 0.18, 0.5, "sine", 40.0)
	_sounds["place_chirp"] = _gen(600.0, 0.12, 0.3, "sine", 1400.0)
	_sounds["remove_whoosh"] = _gen(800.0, 0.15, 0.3, "sine", 150.0)
	# Cable
	_sounds["cable_snap"] = _gen(1800.0, 0.05, 0.25, "square")
	_sounds["cable_resonance"] = _gen(350.0, 0.3, 0.15, "sine")
	_sounds["cable_pop"] = _gen(500.0, 0.08, 0.2, "sine", 200.0)
	# Discovery / Unlock
	_sounds["discovery_chime"] = _gen_chime([523.0, 659.0, 784.0], 0.12, 0.3)
	_sounds["unlock_fanfare"] = _gen_chime([262.0, 330.0, 392.0, 523.0], 0.12, 0.35)
	# Processing
	_sounds["process_crack"] = _gen(1200.0, 0.06, 0.15, "square", 2800.0)
	_sounds["process_synth"] = _gen(400.0, 0.12, 0.15, "sine", 1000.0)
	_sounds["process_tick"] = _gen(1000.0, 0.03, 0.1, "sine")
	_sounds["quarantine_flush"] = _gen(55.0, 0.5, 0.35, "saw", 30.0)
	# UI
	_sounds["ui_hover"] = _gen(3200.0, 0.015, 0.06, "square")
	_sounds["ui_click"] = _gen(1800.0, 0.035, 0.12, "square")


func _gen(freq: float, duration: float, vol: float, wave: String, freq_end: float = -1.0) -> AudioStreamWAV:
	var samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var progress: float = t / duration
		var f: float = freq if freq_end < 0 else lerpf(freq, freq_end, progress)
		# Envelope: quick attack + natural decay
		var env: float = 1.0
		if t < 0.005:
			env = t / 0.005
		if progress > 0.3:
			env *= 1.0 - (progress - 0.3) / 0.7
		# Waveform
		var phase: float = t * f * TAU
		var sample: float = 0.0
		match wave:
			"sine":
				sample = sin(phase)
			"square":
				sample = 1.0 if fmod(phase, TAU) < PI else -1.0
			"saw":
				sample = fmod(t * f, 1.0) * 2.0 - 1.0
		sample *= vol * env
		var s16: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _gen_chime(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var note_samples: int = int(SAMPLE_RATE * note_dur)
	var total: int = note_samples * freqs.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	for ni in range(freqs.size()):
		var freq: float = freqs[ni]
		var base: int = ni * note_samples
		for i in range(note_samples):
			var t: float = float(i) / SAMPLE_RATE
			var progress: float = t / note_dur
			var env: float = 1.0
			if t < 0.005:
				env = t / 0.005
			if progress > 0.4:
				env *= 1.0 - (progress - 0.4) / 0.6
			var sample: float = sin(t * freq * TAU) * vol * env
			sample += sin(t * freq * 2.0 * TAU) * vol * env * 0.15
			var s16: int = clampi(int(sample * 32767.0), -32768, 32767)
			var idx: int = (base + i) * 2
			data[idx] = s16 & 0xFF
			data[idx + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _start_ambient() -> void:
	var dur: float = 3.0
	var samples: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var sample: float = 0.0
		sample += sin(t * 55.0 * TAU) * 0.25
		sample += sin(t * 82.5 * TAU) * 0.12
		sample += sin(t * 110.0 * TAU) * 0.08
		sample += sin(t * 165.0 * TAU) * 0.04
		sample *= 0.8 + sin(t * 0.3 * TAU) * 0.2
		sample *= 0.12
		var s16: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples
	_ambient_player.stream = stream
	_ambient_player.play()
