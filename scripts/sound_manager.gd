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
	play("cable_resonance", -12.0)
	play("cable_sub", -14.0)


func play_cable_remove() -> void:
	play("cable_pop", -10.0)


func play_discovery() -> void:
	play("discovery_chime", -6.0, 0.0)


func play_unlock() -> void:
	play("unlock_fanfare", -4.0, 0.0)


func play_gig_complete() -> void:
	play("gig_complete", -3.0, 0.0)


func play_delivery() -> void:
	play("delivery_blip", -14.0, 0.1)


func play_process_event(building_type: String) -> void:
	match building_type:
		"decryptor":
			play("process_crack", -14.0)
		"encryptor":
			play("process_encrypt", -14.0)
		"recoverer":
			play("process_recover", -14.0)
		"classifier", "separator":
			play("process_classify", -16.0)
		"research", "repair_lab":
			play("process_research", -14.0)
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
	_sounds["cable_resonance"] = _gen(350.0, 0.4, 0.18, "sine")
	_sounds["cable_sub"] = _gen(110.0, 0.25, 0.15, "sine", 80.0)
	_sounds["cable_pop"] = _gen(500.0, 0.08, 0.2, "sine", 200.0)
	# Discovery / Unlock / Gig complete — rich layered versions
	_sounds["discovery_chime"] = _gen_rich_chime([523.0, 659.0, 784.0, 1047.0], 0.15, 0.28, 4, 0.4)
	_sounds["unlock_fanfare"] = _gen_rich_chime([131.0, 262.0, 330.0, 392.0, 523.0], 0.14, 0.32, 3, 0.35)
	# Gig complete (7-note triumphant arpeggio with shimmer)
	_sounds["gig_complete"] = _gen_rich_chime([262.0, 330.0, 392.0, 494.0, 587.0, 659.0, 784.0], 0.12, 0.30, 4, 0.5)
	# Delivery confirmation blip
	_sounds["delivery_blip"] = _gen(880.0, 0.06, 0.2, "sine", 1320.0)
	# Processing — per-building type
	_sounds["process_crack"] = _gen(1200.0, 0.06, 0.15, "square", 2800.0)
	_sounds["process_synth"] = _gen(400.0, 0.12, 0.15, "sine", 1000.0)
	_sounds["process_tick"] = _gen(1000.0, 0.03, 0.1, "sine")
	_sounds["process_encrypt"] = _gen(600.0, 0.08, 0.12, "sine", 1200.0)
	_sounds["process_recover"] = _gen(220.0, 0.15, 0.15, "sine", 440.0)
	_sounds["process_classify"] = _gen(1500.0, 0.04, 0.1, "square")
	_sounds["process_research"] = _gen(330.0, 0.1, 0.12, "sine", 660.0)
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


func _gen_rich_chime(freqs: Array, note_dur: float, vol: float, harmonics: int = 3, tail: float = 0.3) -> AudioStreamWAV:
	## Layered chime with harmonics and reverb-like tail. Notes overlap for fullness.
	var note_samples: int = int(SAMPLE_RATE * note_dur)
	var tail_samples: int = int(SAMPLE_RATE * tail)
	var total: int = note_samples * freqs.size() + tail_samples
	var buffer := PackedFloat32Array()
	buffer.resize(total)
	buffer.fill(0.0)
	for ni in range(freqs.size()):
		var freq: float = freqs[ni]
		var start: int = ni * note_samples
		var ring_len: int = mini(note_samples + tail_samples, total - start)
		for i in range(ring_len):
			var t: float = float(i) / SAMPLE_RATE
			var total_dur: float = note_dur + tail
			var progress: float = t / total_dur
			var env: float = 1.0
			if t < 0.008:
				env = t / 0.008
			env *= pow(1.0 - clampf(progress, 0.0, 1.0), 1.6)
			var sample: float = 0.0
			for h in range(harmonics):
				var harm_freq: float = freq * (h + 1)
				var harm_vol: float = 1.0 / pow(h + 1, 1.3)
				sample += sin(t * harm_freq * TAU) * harm_vol
			sample *= vol * env / float(harmonics)
			buffer[start + i] += sample
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in range(total):
		var s16: int = clampi(int(buffer[i] * 32767.0), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _start_ambient() -> void:
	## Cyberpunk ambient — deep drone + pad sweep + filtered noise + data pulses + shimmer.
	var dur: float = 10.0
	var samples: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / SAMPLE_RATE
		var sample: float = 0.0
		# Layer 1: Deep drone with slow breathing
		var drone_mod: float = 0.85 + sin(t * 0.15 * TAU) * 0.15
		sample += sin(t * 55.0 * TAU) * 0.20 * drone_mod
		sample += sin(t * 82.5 * TAU) * 0.10 * drone_mod
		# Layer 2: Mid pad with sweep
		var pad_sweep: float = 0.5 + sin(t * 0.08 * TAU) * 0.5
		sample += sin(t * 110.0 * TAU) * 0.06 * pad_sweep
		sample += sin(t * 165.0 * TAU) * 0.04 * pad_sweep
		sample += sin(t * 220.0 * TAU) * 0.025 * pad_sweep * pad_sweep
		# Layer 3: Filtered noise (deterministic pseudo-noise)
		var noise: float = sin(t * 7919.0) * sin(t * 6961.0) * sin(t * 5381.0)
		var noise_env: float = 0.3 + sin(t * 0.2 * TAU) * 0.2 + sin(t * 0.07 * TAU) * 0.15
		sample += noise * 0.025 * noise_env
		# Layer 4: Data pulses — subtle pings
		var pulse_t: float = fmod(t, 2.5) / 2.5
		if pulse_t < 0.02:
			var pe: float = 1.0 - pulse_t / 0.02
			sample += sin(t * 880.0 * TAU) * 0.035 * pe * pe
		var pulse_t2: float = fmod(t + 1.25, 2.5) / 2.5
		if pulse_t2 < 0.015:
			var pe2: float = 1.0 - pulse_t2 / 0.015
			sample += sin(t * 660.0 * TAU) * 0.02 * pe2 * pe2
		# Layer 5: High shimmer
		var shimmer_env: float = maxf(0.0, sin(t * 0.12 * TAU)) * 0.5
		sample += sin(t * 1320.0 * TAU) * 0.01 * shimmer_env
		sample += sin(t * 1760.0 * TAU) * 0.005 * shimmer_env
		# Global breathing
		sample *= 0.7 + sin(t * 0.25 * TAU) * 0.15 + sin(t * 0.4 * TAU) * 0.08
		sample *= 0.14
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
