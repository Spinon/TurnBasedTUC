extends Node

const MUSIC_FADE_TIME := 1.5

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size := 8

var music_volume: float = 0.8
var sfx_volume: float = 1.0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	for i in _sfx_pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)


func play_music(stream: AudioStream, loop := true) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, MUSIC_FADE_TIME)
	await tween.finished
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player.play()
	# Godot não tem loop nativo no player — usa AudioStreamOggVorbis.loop


func stop_music() -> void:
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, MUSIC_FADE_TIME)
	await tween.finished
	_music_player.stop()


func play_sfx(stream: AudioStream) -> void:
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(sfx_volume)
			p.play()
			return
