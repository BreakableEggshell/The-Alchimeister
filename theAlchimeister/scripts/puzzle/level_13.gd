extends "res://scripts/puzzle/puzzle_level.gd"
## "Blast radius": dynamite (see dynamite.gd) blows open the cracked walls in
## the way. Once every stick has gone off, the way to the exit is open, so
## nothing left calls for a restart even with no potions left.


func is_stuck() -> bool:
	return super() and get_tree().get_node_count_in_group("dynamite") > 0
