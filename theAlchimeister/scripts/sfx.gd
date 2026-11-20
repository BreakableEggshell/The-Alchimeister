class_name Sfx
extends RefCounted
## Sound effects, on the SFX bus (its volume is the SOUND setting). Add a new
## sound by dropping it in assets/audio/sfx/ and adding a constant here.

const KNOCKBACK := preload("res://assets/audio/sfx/knockback.wav")
const PICKUP := preload("res://assets/audio/sfx/pickup.wav")
const POTION_BREW := preload("res://assets/audio/sfx/potion_brew.wav")
## A fire potion's splash, and a Death potion's.
const POTION_FIRE := preload("res://assets/audio/sfx/potion_fire_sfx.wav")
const POTION_DEATH := preload("res://assets/audio/sfx/potion_death_sfx.mp3")
## Anything bouncing off jelly: a potion, or the knight.
const JELLY_BOUNCE := preload("res://assets/audio/sfx/jelly_bounce_sfx.wav")
## The knight: jumping, landing from a fall, and dying.
const KNIGHT_JUMP := preload("res://assets/audio/sfx/knight_jump_sfx.wav")
const KNIGHT_LAND := preload("res://assets/audio/sfx/knight_land.wav")
const KNIGHT_DEATH := preload("res://assets/audio/sfx/knight_death_sfx.wav")
## The first 3.5 seconds of "Small Audience Chatter Talking", faded out at the end.
const AUDIENCE_CHATTER := preload("res://assets/audio/sfx/audience_chatter.wav")

## Each sound's volume (dB), evening them out: set from each one's loudest
## moment so they hit about alike (~-16 dBFS). The jump, heard all the time,
## sits a bit under the rest. Sounds not listed play as they are.
const GAIN_DB := {
	KNIGHT_JUMP: -9.5,
	KNIGHT_LAND: 5.0,
	KNIGHT_DEATH: -5.0,
	JELLY_BOUNCE: 4.0,
	KNOCKBACK: -3.0,
	PICKUP: 14.0,
	POTION_BREW: -2.0,
}


## Plays `stream` once. With `at`, it sounds from that spot in the world
## (quieter and panned when far from the camera); otherwise it's plain.
## It keeps playing while the game is paused (the notebook, dialogue).
## Returns the player (null if nothing played), e.g. to fade it.
static func play(stream: AudioStream, from: Node, at = null) -> Node:
	if not stream or not from or not from.is_inside_tree():
		return null
	var player: Node
	if at is Vector2:
		var positioned := AudioStreamPlayer2D.new()
		positioned.stream = stream
		positioned.volume_db = GAIN_DB.get(stream, 0.0)
		positioned.bus = &"SFX"
		positioned.global_position = at
		positioned.finished.connect(positioned.queue_free)
		player = positioned
	else:
		var flat := AudioStreamPlayer.new()
		flat.stream = stream
		flat.volume_db = GAIN_DB.get(stream, 0.0)
		flat.bus = &"SFX"
		flat.finished.connect(flat.queue_free)
		player = flat
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	# On the scene root, so it outlives whatever asked for it (a shattered potion).
	var holder: Node = from.get_tree().current_scene
	if not holder:
		holder = from.get_tree().root
	holder.add_child(player)
	player.play()
	return player
