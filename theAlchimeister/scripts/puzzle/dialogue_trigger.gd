@tool
class_name DialogueTrigger
extends Area2D
## An invisible zone that starts a conversation the first time the knight
## walks into it (the game pauses, a speech bubble pops up, then the lines
## play). Origin is the top-left corner; outlined in the editor only.

## Width and height of the zone.
@export var size := Vector2(64, 32):
	set(value):
		size = value
		queue_redraw()
## "SPEAKER: text" lines to play.
@export var lines: PackedStringArray
## What they teach, so skipping them warns the player.
@export_enum("none", "hint", "tutorial") var teaches := "none"
## Only on the stage's first attempt, not again after a restart.
@export var first_attempt_only := true
## With first_attempt_only off: lines for every attempt after the first.
## Empty plays `lines` again.
@export var retry_lines: PackedStringArray

var _done := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = PotionData.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	body_entered.connect(_on_body_entered)
	var stage := owner
	if first_attempt_only and stage and stage.has_method("restart_count") and stage.restart_count() > 0:
		_done = true


func _on_body_entered(body: Node) -> void:
	if _done or not body.has_method("die"):
		return
	_done = true
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	var stage := owner
	var retry: bool = stage and stage.has_method("restart_count") and stage.restart_count() > 0
	var said := retry_lines if retry and not retry_lines.is_empty() else lines
	if dialogue:
		dialogue.interrupt(said, body, &"" if teaches == "none" else StringName(teaches))


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.95, 0.85, 0.15))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.95, 0.85, 0.6), false)
