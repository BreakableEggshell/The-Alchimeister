extends "res://scripts/puzzle/puzzle_level.gd"
## LET OFF STEAM (level 10): the way across the pit is a bridge of ice, made
## by melting the slab to smoke and freezing it level with the ledges. Set
## yourself on fire and you run fast enough to leap the pit instead: Sheldon
## calls that out at the door.

const CHEAT_LINES := ["SHELDON: Hey, that's cheating!"]
## Where the far ledge starts, and how high the slab must be to be the bridge.
const FAR_LEDGE_X := 262.0
const BRIDGE_Y := 140.0

@export var slab: Node2D

## Landed across burning, with no bridge there.
var _cheated := false
var _across := false


func _physics_process(_delta: float) -> void:
	if _across or player._dead:
		return
	if player.global_position.x >= FAR_LEDGE_X and player.is_on_floor():
		_across = true
		var bridged: bool = slab != null and slab.form == slab.Form.ICE and slab.global_position.y < BRIDGE_Y
		_cheated = player.is_burning() and not bridged


func _exit_lines() -> PackedStringArray:
	if _cheated:
		return PackedStringArray(CHEAT_LINES)
	return super()
