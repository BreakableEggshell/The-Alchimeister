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
