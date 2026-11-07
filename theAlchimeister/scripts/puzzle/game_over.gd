class_name GameOver
extends RefCounted
## What the game over screen says for each way the player can die. To add a
## new one, add a cause here and pass it to the knight's die(cause).

const CAUGHT := &"caught"
const BURNED := &"burned"
const DEATH_POTION := &"death_potion"
const CRUSHED := &"crushed"

const COLOR := Color(1, 0.45, 0.45)

## Cause -> [title, message].
const SCREENS := {
	CAUGHT: ["CAUGHT!", "A MONSTER GOT YOU."],
	BURNED: ["BURNT TO A CRISP!", "YOU SET YOURSELF ON FIRE."],
	DEATH_POTION: ["STRUCK DOWN!", "THE DEATH POTION SPARES NO ONE."],
	CRUSHED: ["CRUSHED!", "DON'T STAND UNDER FALLING ROCKS."],
}


static func title_of(cause: StringName) -> String:
	return SCREENS.get(cause, ["GAME OVER"])[0]


static func message_of(cause: StringName) -> String:
	var screen: Array = SCREENS.get(cause, [])
	return screen[1] if screen.size() > 1 else ""
