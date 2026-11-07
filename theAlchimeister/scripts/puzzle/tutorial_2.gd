extends "res://scripts/puzzle/puzzle_level.gd"
## Stage 1-2: brew freeze potions and freeze the wall slime while it's on the
## button; then brew knockback from the next chest and knock the slime sitting
## on the second button off it (that gate opens once the button is free).
## A chest by the door holds an ember, just because.
## At the exit, Sheldon points out that every playtester needed a second
## freeze potion here (teasing a little if one was enough).

const ONE_POTION_LINE := "SHELDON: Just one freeze potion? Show-off. 5 out of 5 playtesters needed a second one here."
const MORE_POTIONS_LINE := "SHELDON: Don't sweat the extra potion. 5 out of 5 playtesters needed that second freeze potion too."

## Freeze potions used up (thrown) this attempt.
var _freezes_used := 0
var _freezes_held := 0


func _ready() -> void:
	super()
	inventory.changed.connect(_count_freezes)


func _count_freezes() -> void:
	var held := inventory.count(PotionData.FREEZE)
	if held < _freezes_held:
		_freezes_used += _freezes_held - held
	_freezes_held = held


func _exit_lines() -> PackedStringArray:
	return PackedStringArray([ONE_POTION_LINE if _freezes_used <= 1 else MORE_POTIONS_LINE])
