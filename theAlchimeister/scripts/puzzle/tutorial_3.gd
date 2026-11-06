extends "res://scripts/puzzle/puzzle_level.gd"
## Tutorial 1-3: knockback, then three guards you can only sneak past by
## throwing a translucent potion at your own feet. A cleansing portal then
## washes the effect off before two more guards, so the second potion has to
## go on yourself too. Sheldon drops hints:
## - running out of translucent potions without ever turning translucent
##   yourself gets a nudge (blunt from the 7th attempt on);
## - from the 3rd attempt, a wink at the start.

const RUN_OUT_LINE := "SHELDON: Darn, we don't have that much potions. If only we can be translucent ourselves."
const WINK_LINE := "SHELDON: I wonder if we can use the potion on ourselves. Why not try throwing it on your feet? *Wink* *Wink*"
const BLUNT_LINE := "SHELDON: Throw. The. Translucent. Potion. To. Your. Feet."
## Attempts (restarts) before each hint kicks in.
const WINK_AFTER_RESTARTS := 2
const BLUNT_AFTER_RESTARTS := 6
## Seconds to let the last potion land before deciding it was wasted.
const RUN_OUT_DELAY := 1.2

var _had_translucent := false
var _was_translucent := false
var _run_out_shown := false


func _ready() -> void:
	super()
	inventory.changed.connect(_check_run_out)


func _on_stage_start(attempt: int) -> void:
	if attempt == 0:
		super(attempt)
	elif attempt >= WINK_AFTER_RESTARTS and attempt < BLUNT_AFTER_RESTARTS:
		hud.dialogue.play(PackedStringArray([WINK_LINE]))


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
	hud.dialogue.play(PackedStringArray([line]))
