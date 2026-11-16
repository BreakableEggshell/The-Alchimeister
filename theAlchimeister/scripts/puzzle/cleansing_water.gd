@tool
class_name CleansingWater
extends Area2D
## Cleansing water: a bubbling blue wall that washes off every potion effect
## from anything standing in it, the player and monsters alike (ending
## translucency, putting out fire, thawing ice, waking the stunned).
## Origin is the floor at its centre; it rises `height` pixels.

@export var height := 192.0:
	set(value):
		height = value
		queue_redraw()
@export var width := 10.0:
	set(value):
		width = value
		queue_redraw()

## The water: frames of a tile that repeats up the column (each frame is a
## step of the loop: bubbles rise 4 px a frame, 28 over the loop).
const SHEET := preload("res://assets/sprites/props/cleansing_water.png")
const TILE := Vector2(10, 28)
const FRAMES := 7
const FPS := 8.0
## The notebook's small water icon is still drawn with these.
const WATER := Color(0.3, 0.6, 1.0, 0.4)
const EDGE := Color(0.55, 0.85, 1.0, 0.9)
const BUBBLE := Color(0.8, 0.95, 1.0, 0.85)

var _clock := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = PotionData.LAYER_PLAYER | PotionData.LAYER_ENEMIES
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	shape.position = Vector2(0, -height / 2.0)
	add_child(shape)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Every frame, not just on entry, so a potion splashed inside it wears off too.
	for body in get_overlapping_bodies():
		if body.has_method("clear_potion_effects"):
			body.clear_potion_effects()


## A small cleansing water icon (for the notebook), centred on `at`.
static func draw_icon(canvas: CanvasItem, at: Vector2) -> void:
	var body := Rect2(at + Vector2(-4, -6), Vector2(8, 12))
	canvas.draw_rect(body, Color(WATER, 0.8))
	canvas.draw_line(body.position, body.position + Vector2(0, body.size.y), EDGE)
	canvas.draw_line(body.position + Vector2(body.size.x, 0), body.end, EDGE)
	canvas.draw_circle(at + Vector2(-1, 2), 1.0, BUBBLE)
	canvas.draw_circle(at + Vector2(1.5, -2), 1.0, BUBBLE)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	# cleansing_water.png: FRAMES frames of a 10 x 28 tile, stacked from the
	# floor up (the top one cut short), looping.
	var frame := int(_clock * FPS) % FRAMES
	var x := -roundf(TILE.x / 2.0)
	var bottom := 0.0
	while bottom > -height:
		var piece := minf(TILE.y, height + bottom)
		var source := Rect2(frame * TILE.x, TILE.y - piece, TILE.x, piece)
		draw_texture_rect_region(SHEET, Rect2(x, bottom - piece, TILE.x, piece), source)
		bottom -= piece
