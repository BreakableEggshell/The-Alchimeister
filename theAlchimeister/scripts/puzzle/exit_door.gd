@tool
extends Area2D
## The stage exit. Emits `reached` when the player walks into it.
## Origin is the floor surface at its centre.

signal reached

var _done := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("stage_exit")
	collision_layer = 0
	collision_mask = PotionData.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 20)
	shape.shape = rect
	shape.position = Vector2(0, -10)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	# A knight knocked into it as he dies doesn't count.
	if not _done and body.has_method("die") and not body.get("_dead"):
		_done = true
		reached.emit()


const ART := preload("res://assets/sprites/props/exit_door.png")


func _draw() -> void:
	draw_texture(ART, Vector2(-roundf(ART.get_width() / 2.0), -ART.get_height()))
