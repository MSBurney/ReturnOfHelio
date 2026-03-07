extends Node

## Global audio manager with bus control and lightweight SFX/music API.

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_AMBIENCE := "Ambience"

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _music_using_a: bool = true
var _current_music_id: StringName = &""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_library: Dictionary = {}
var _music_library: Dictionary = {}

func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_UI)
	_ensure_bus(BUS_AMBIENCE)
	_setup_players()

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
