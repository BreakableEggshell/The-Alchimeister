extends "res://scripts/puzzle/puzzle_level.gd"
## A level built round TNT (see tnt.gd). Running out of potions isn't stuck
## once every crate has gone off: the way is as open as it will get. It is
## stuck, potions or not, once:
## - the `bridge` (a WoodenPlatform a blast can break) has been blown away
##   with the knight still short of `bridge_end_x`: there's no way across;
## - the knight is down in the `trap` (stage pixels), a pit with no way out.

@export var bridge: Node2D
@export var bridge_end_x := 0.0
@export var trap := Rect2()

## A bridge was set (once freed, `bridge` reads as null).
var _has_bridge := false


func _ready() -> void:
	_has_bridge = bridge != null
	super()


func is_stuck() -> bool:
	var at := player.global_position
	if bridge_gone() and at.x < bridge_end_x:
		return true
	if trap.has_area() and trap.has_point(at):
		return true
	return super() and get_tree().get_node_count_in_group("tnt") > 0


func bridge_gone() -> bool:
	return _has_bridge and (not is_instance_valid(bridge) or bridge.is_broken())
