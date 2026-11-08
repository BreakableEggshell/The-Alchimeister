class_name Sfx
extends RefCounted
## Sound effects, on the SFX bus (its volume is the SOUND setting). Add a new
## sound by dropping it in assets/audio/sfx/ and adding a constant here.

const KNOCKBACK := preload("res://assets/audio/sfx/knockback.wav")
const PICKUP := preload("res://assets/audio/sfx/pickup.wav")
const POTION_BREW := preload("res://assets/audio/sfx/potion_brew.wav")


## Plays `stream` once. With `at`, it sounds from that spot in the world
## (quieter and panned when far from the camera); otherwise it's plain.
## It keeps playing while the game is paused (the notebook, dialogue).
static func play(stream: AudioStream, from: Node, at = null) -> void:
	if not stream or not from or not from.is_inside_tree():
		return
	var player: Node
	if at is Vector2:
		var positioned := AudioStreamPlayer2D.new()
		positioned.stream = stream
		positioned.bus = &"SFX"
		positioned.global_position = at
		positioned.finished.connect(positioned.queue_free)
		player = positioned
	else:
		var flat := AudioStreamPlayer.new()
		flat.stream = stream
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
