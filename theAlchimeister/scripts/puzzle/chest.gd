@tool
extends Area2D
## A treasure chest. Opens when the player touches it and gives its ingredient.
## Origin is the floor surface at its centre.

@export_enum("ember", "gust_feather", "frost_shard", "ghost_wisp") var contents := "ember"

var _opened := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = PotionData.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 12)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	var inventory := get_tree().get_first_node_in_group("inventory") as Inventory
	if _opened or not inventory or not body.has_method("die"):
		return
	_opened = true
	queue_redraw()
	inventory.add_ingredient(StringName(contents))
	_float_icon()


## Shows the ingredient rising out of the chest and fading.
func _float_icon() -> void:
	var icon := Node2D.new()
	var kind := StringName(contents)
	icon.draw.connect(func() -> void: PotionData.draw_ingredient(icon, kind, Vector2.ZERO))
	icon.position = Vector2(0, -12)
	add_child(icon)
	var tween := icon.create_tween().set_parallel()
	tween.tween_property(icon, "position:y", -30.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(icon, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(icon.queue_free)


func _draw() -> void:
	var wood := Color(0.55, 0.33, 0.18)
	var band := Color(0.95, 0.8, 0.35)
	draw_rect(Rect2(-8, -8, 16, 8), wood)
	draw_rect(Rect2(-8, -8, 16, 1), band)
	if _opened:
		draw_rect(Rect2(-8, -14, 16, 3), wood.darkened(0.2))
		draw_rect(Rect2(-6, -9, 12, 1), Color(1, 0.95, 0.6, 0.8))
	else:
		draw_rect(Rect2(-8, -12, 16, 4), wood.lightened(0.1))
		draw_rect(Rect2(-1, -10, 2, 3), band)
