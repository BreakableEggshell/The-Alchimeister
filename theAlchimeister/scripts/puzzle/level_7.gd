extends "res://scripts/puzzle/puzzle_level.gd"
## Level 7, "The only way out": the path drops you into a pit you can't climb
## out of, with a chest of three random ingredients. That's the softlock, on
## purpose: the way out is to die, by setting yourself on fire with no water
## around or by brewing a Death potion (any mix that isn't a recipe). Doing
## so clears the level instead of restarting it. Being stuck any other way
## (potions wasted) still calls for a restart.

## Seconds after dying before Sheldon speaks up.
const ESCAPE_BEAT := 1.0

@export var chest: Node


func _ready() -> void:
	super()
	_fill_chest()


## Three random ingredients, always leaving a way out: an ember (fire) or at
## least two different kinds (which mix into a Death potion).
func _fill_chest() -> void:
	var picks: Array[StringName] = []
	while true:
		picks.clear()
		for i in 3:
			picks.append(PotionData.INGREDIENTS.pick_random())
		if picks.has(PotionData.EMBER) or picks.any(func(kind: StringName) -> bool: return kind != picks[0]):
			break
	chest.contents = String(picks[0])
	chest.amount = 1
	chest.extra_contents = String(picks[1])
	chest.extra_amount = 1
	chest.third_contents = String(picks[2])
	chest.third_amount = 1


func _on_player_died(cause: StringName) -> void:
	if cause != GameOver.BURNED and cause != GameOver.DEATH_POTION:
		super(cause)
		return
	# That's the way out.
	_stop_play()
	hud.set_potions_enabled(false)
	await get_tree().create_timer(ESCAPE_BEAT).timeout
	_on_exit_reached()
