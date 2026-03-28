extends Node

## Global audio manager with bus control and lightweight SFX/music API.

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_AMBIENCE := "Ambience"

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _music_using_a: bool = true
var _current_music_id: StringName = &""
var _current_ambience_id: StringName = &""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_library: Dictionary = {}
var _music_library: Dictionary = {}

func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_UI)
	_ensure_bus(BUS_AMBIENCE)
	_setup_players()
	_register_default_audio()

func play_sfx(event_id: StringName, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _sfx_library.get(event_id, null)
	if stream == null:
		return
	var player := _next_available_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.play()

func play_music(track_id: StringName, crossfade_sec: float = 0.4) -> void:
	if track_id == _current_music_id:
		return
	var stream: AudioStream = _music_library.get(track_id, null)
	if stream == null:
		return
	var incoming := _music_player_a if _music_using_a else _music_player_b
	var outgoing := _music_player_b if _music_using_a else _music_player_a
	_music_using_a = not _music_using_a
	_current_music_id = track_id
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0, maxf(crossfade_sec, 0.01))
	tween.tween_property(outgoing, "volume_db", -40.0, maxf(crossfade_sec, 0.01))
	tween.chain().tween_callback(outgoing.stop)

func play_ambience(track_id: StringName, fade_sec: float = 0.4) -> void:
	if track_id == _current_ambience_id:
		return
	var stream: AudioStream = _music_library.get(track_id, null)
	if stream == null:
		return
	_current_ambience_id = track_id
	_ambience_player.stream = stream
	_ambience_player.volume_db = -40.0
	_ambience_player.play()
	var tween := create_tween()
	tween.tween_property(_ambience_player, "volume_db", -8.0, maxf(fade_sec, 0.01))

func stop_ambience(fade_sec: float = 0.3) -> void:
	_current_ambience_id = &""
	if not _ambience_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_ambience_player, "volume_db", -40.0, maxf(fade_sec, 0.01))
	tween.chain().tween_callback(_ambience_player.stop)

func stop_music() -> void:
	_current_music_id = &""
	_music_player_a.stop()
	_music_player_b.stop()

func set_bus_volume(bus_name: String, volume_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, volume_db)

func get_bus_volume(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return 0.0
	return AudioServer.get_bus_volume_db(index)

func register_sfx(event_id: StringName, stream: AudioStream) -> void:
	if stream == null:
		return
	_sfx_library[event_id] = stream

func register_music(track_id: StringName, stream: AudioStream) -> void:
	if stream == null:
		return
	_music_library[track_id] = stream

func _setup_players() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = BUS_MUSIC
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = BUS_MUSIC
	add_child(_music_player_b)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = BUS_AMBIENCE
	add_child(_ambience_player)

	for _i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_pool.append(player)

func _next_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	return _sfx_pool[0]

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus(AudioServer.bus_count)
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)

func _register_default_audio() -> void:
	_register_default_sfx()
	_register_default_music()

func _register_default_sfx() -> void:
	var sfx_defs := {
		"jump": _load_audio_or_fallback("res://assets/audio/sfx/jump.ogg", _make_tone_wav(460.0, 0.08, 0.35)),
		"attack": _load_audio_or_fallback("res://assets/audio/sfx/attack.ogg", _make_tone_wav(320.0, 0.07, 0.28)),
		"attack_charge": _load_audio_or_fallback("res://assets/audio/sfx/attack_charge.ogg", _make_tone_wav(180.0, 0.22, 0.32)),
		"hit": _load_audio_or_fallback("res://assets/audio/sfx/hit.ogg", _make_tone_wav(120.0, 0.06, 0.3)),
		"player_hit": _load_audio_or_fallback("res://assets/audio/sfx/player_hit.ogg", _make_tone_wav(140.0, 0.08, 0.33)),
		"player_die": _load_audio_or_fallback("res://assets/audio/sfx/player_die.ogg", _make_tone_wav(90.0, 0.22, 0.38)),
		"enemy_die": _load_audio_or_fallback("res://assets/audio/sfx/enemy_die.ogg", _make_tone_wav(210.0, 0.12, 0.3)),
		"pickup": _load_audio_or_fallback("res://assets/audio/sfx/pickup.ogg", _make_tone_wav(820.0, 0.06, 0.22)),
		"ui_move": _load_audio_or_fallback("res://assets/audio/sfx/ui_move.ogg", _make_tone_wav(700.0, 0.03, 0.15)),
		"ui_accept": _load_audio_or_fallback("res://assets/audio/sfx/ui_accept.ogg", _make_tone_wav(920.0, 0.06, 0.2)),
		"ui_cancel": _load_audio_or_fallback("res://assets/audio/sfx/ui_cancel.ogg", _make_tone_wav(280.0, 0.05, 0.18)),
	}
	for event_id in sfx_defs.keys():
		if _sfx_library.has(event_id):
			continue
		register_sfx(event_id, sfx_defs[event_id])

func _register_default_music() -> void:
	if not _music_library.has("title"):
		register_music("title", _load_audio_or_fallback("res://assets/audio/music/title.ogg", _make_music_loop([220.0, 246.94, 293.66, 246.94], 0.45, 2.0, 0.22)))
	if not _music_library.has("level"):
		register_music("level", _load_audio_or_fallback("res://assets/audio/music/level.ogg", _make_music_loop([174.61, 196.0, 220.0, 196.0], 0.5, 2.0, 0.2)))
	if not _music_library.has("boss"):
		register_music("boss", _load_audio_or_fallback("res://assets/audio/music/boss.ogg", _make_music_loop([110.0, 123.47, 130.81, 123.47], 0.4, 2.0, 0.24)))
	if not _music_library.has("world1_level"):
		register_music("world1_level", _music_library["level"])
	if not _music_library.has("world1_boss"):
		register_music("world1_boss", _music_library["boss"])
	if not _music_library.has("ambience_wind"):
		register_music("ambience_wind", _load_audio_or_fallback("res://assets/audio/ambience/wind.ogg", _make_music_loop([82.0, 96.0, 88.0, 76.0], 0.8, 3.2, 0.08)))

func _load_audio_or_fallback(path: String, fallback: AudioStream) -> AudioStream:
	if ResourceLoader.exists(path):
		var stream := load(path)
		if stream is AudioStream:
			return stream
	return fallback

func _make_tone_wav(freq_hz: float, duration_sec: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := maxi(int(duration_sec * sample_rate), 1)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var attack_samples := maxi(int(sample_rate * 0.01), 1)
	var release_samples := maxi(int(sample_rate * 0.02), 1)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var env := 1.0
		if i < attack_samples:
			env = float(i) / float(attack_samples)
		elif i >= sample_count - release_samples:
			env = float(sample_count - i) / float(release_samples)
		env = clampf(env, 0.0, 1.0)
		var sample := sin(TAU * freq_hz * t) * amplitude * env
		_write_sample_16(data, i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = data
	return wav

func _make_music_loop(notes_hz: Array[float], note_len_sec: float, total_length_sec: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := maxi(int(total_length_sec * sample_rate), 1)
	var note_count := maxi(notes_hz.size(), 1)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var note_index := int(floor(t / note_len_sec)) % note_count
		var note_freq := notes_hz[note_index] if note_index < notes_hz.size() else 220.0
		var local_t := fmod(t, note_len_sec)
		var local_norm := local_t / maxf(note_len_sec, 0.001)
		var env := 0.6 + 0.4 * (1.0 - local_norm)
		var fundamental := sin(TAU * note_freq * t)
		var harmonic := sin(TAU * (note_freq * 0.5) * t) * 0.45
		var sample := (fundamental + harmonic) * amplitude * env
		_write_sample_16(data, i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = sample_count
	wav.data = data
	return wav

func _write_sample_16(data: PackedByteArray, offset: int, sample: float) -> void:
	var pcm: int = clampi(int(round(sample * 32767.0)), -32768, 32767)
	data[offset] = pcm & 0xFF
	data[offset + 1] = (pcm >> 8) & 0xFF
