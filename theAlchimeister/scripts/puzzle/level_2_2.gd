extends "res://scripts/puzzle/puzzle_level.gd"
## Stage 2-2 (was tutorial 1-3): knockback, then three guards you can only sneak past by
## throwing a translucent potion at your own feet. Cleansing water then
## washes the effect off before two more guards, so the second potion has to
## go on yourself too. Sheldon drops hints:
## - running out of translucent potions without ever turning translucent
##   yourself gets a nudge (blunt from the 7th attempt on).
## (The "Who says potions are only for throwing at monsters?" wink is part of
## its HINT now.)

const RUN_OUT_LINE := "SHELDON (squint): Darn, we don't have that much potions. If only we can be translucent ourselves."
const BLUNT_LINE := "SHELDON (glasses): Throw. The. Translucent. Potion. To. Your. Feet."
## Attempts (restarts) before the run-out nudge turns blunt.
const BLUNT_AFTER_RESTARTS := 6
## Seconds to let the last potion land before deciding it was wasted.
const RUN_OUT_DELAY := 1.2

var _had_translucent := false
var _was_translucent := false
var _run_out_shown := false


func _ready() -> void:
	super()
	inventory.changed.connect(_check_run_out)


func _physics_process(_delta: float) -> void:
	if player.is_translucent():
		_was_translucent = true


func _check_run_out() -> void:
	if inventory.count(PotionData.TRANSLUCENT) > 0:
		_had_translucent = true
		return
	if _run_out_shown or not _had_translucent or _was_translucent or inventory.ingredient_count(PotionData.GHOST_WISP) > 0:
		return
	_run_out_shown = true
	await get_tree().create_timer(RUN_OUT_DELAY).timeout
	if _was_translucent or _over:
		return
	var line := BLUNT_LINE if restart_count() >= BLUNT_AFTER_RESTARTS else RUN_OUT_LINE
	hud.dialogue.interrupt(PackedStringArray([line]), player, &"hint")
