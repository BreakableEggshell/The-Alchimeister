extends Node
## Autoload "Music": the background music, on the Music bus (its volume is the
## MUSIC setting). One track at a time, looping (set in each track's import).
## Asking for the track already playing changes nothing, so it carries on
## from screen to screen; asking for another crossfades to it.

const SAFE_SPACE := preload("res://assets/audio/music/safe_space_loopable.wav")
const THE_WALL := preload("res://assets/audio/music/the_wall_loopable.wav")
const RAINY_FOOTHILLS := preload("res://assets/audio/music/rainy_foothills_loopable.wav")
const WALTZ := preload("res://assets/audio/music/waltz_of_the_lich_king_loopable.wav")

## Each screen's track.
const MAIN_MENU := SAFE_SPACE
const OPENING := THE_WALL
const LEVELS := RAINY_FOOTHILLS
const BOSS := WALTZ

## Seconds to fade between tracks.
const FADE_TIME := 0.8
const SILENT_DB := -60.0

var _current: AudioStreamPlayer
var _fades := {}


func _ready() -> void:
	# Plays on through pauses (the notebook, dialogue).
	process_mode = Node.PROCESS_MODE_ALWAYS


## Plays `stream`, fading in over `fade` seconds while whatever was playing
## fades out. Nothing changes if it's already the track playing.
func play(stream: AudioStream, fade := FADE_TIME) -> void:
	if _current and _current.stream == stream and _current.playing:
		_fade(_current, 0.0, fade)
		return
	stop(fade)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Music"
	player.volume_db = SILENT_DB if fade > 0.0 else 0.0
	add_child(player)
	player.play()
	_current = player
	_fade(player, 0.0, fade)


## Fades the music out over `fade` seconds (then it's gone).
func stop(fade := FADE_TIME) -> void:
	if not _current:
		return
	var player := _current
	_current = null
	_fade(player, SILENT_DB, fade, true)


## The track playing, or null.
func current() -> AudioStream:
	return _current.stream if _current else null


func _fade(player: AudioStreamPlayer, to_db: float, time: float, free_after := false) -> void:
	if _fades.has(player):
		_fades[player].kill()
	if time <= 0.0:
		player.volume_db = to_db
		if free_after:
			player.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, time).set_trans(Tween.TRANS_SINE)
	if free_after:
		tween.tween_callback(player.queue_free)
	_fades[player] = tween
	tween.finished.connect(func() -> void: _fades.erase(player))
