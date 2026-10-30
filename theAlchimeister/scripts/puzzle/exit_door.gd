@tool
extends Area2D
## The stage exit. Emits `reached` when the player walks into it.
## Origin is the floor surface at its centre.

signal reached

var _done := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
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
	if not _done and body.has_method("die"):
		_done = true
		reached.emit()


func _draw() -> void:
	draw_circle(Vector2(0, -22), 10.0, Color(0.95, 0.85, 0.55))
	draw_rect(Rect2(-10, -22, 20, 22), Color(0.95, 0.85, 0.55))
	draw_circle(Vector2(0, -22), 8.0, Color(0.05, 0.05, 0.08))
	draw_rect(Rect2(-8, -22, 16, 22), Color(0.05, 0.05, 0.08))
	draw_rect(Rect2(-8, -1, 16, 1), Color(0.95, 0.85, 0.55, 0.5))
