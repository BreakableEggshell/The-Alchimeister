class_name GameOver
extends RefCounted
## The ways the player can die, passed to the knight's die(cause).

const CAUGHT := &"caught"
const BURNED := &"burned"
const DEATH_POTION := &"death_potion"
const CRUSHED := &"crushed"
const BLOWN_UP := &"blown_up"

## Shown over the knight's head, with a skull, for deaths that need explaining.
const TEXT := {
	BURNED: "[BURNED]",
	CRUSHED: "[CRUSHED]",
	BLOWN_UP: "[BLOWN UP]",
}
const TEXT_COLOR := Color(1.0, 0.25, 0.25)
## The colours the knight fades out in, per cause: [base, accent] for
## knight_death.png's white and magenta. Anything not listed: CRUSHED's.
const FADE_COLORS := {
	CAUGHT: [Color(0.62, 0.95, 0.66), Color(0.14, 0.56, 0.39)],
	BURNED: [Color(1.0, 0.78, 0.38), Color(0.92, 0.32, 0.1)],
	DEATH_POTION: [Color(0.78, 0.34, 0.5), Color(0.42, 0.07, 0.2)],
	BLOWN_UP: [Color(1.0, 0.93, 0.62), Color(0.96, 0.56, 0.2)],
	CRUSHED: [Color.WHITE, Color(0.68, 0.66, 0.72)],
}
