@tool
class_name PressurePlate
extends Area2D
## A floor button, pressed while the player, an enemy or a prop stands on it.
## Origin is the floor surface at its centre. Green while free, red while
## pressed. Drawn in front of whatever stands on it so it stays visible.

signal toggled(pressed: bool)

@export var width := 20.0:
	set(value):
		width = value
		queue_redraw()

const FREE_COLOR := Color(0.4, 0.9, 0.45)
const PRESSED_COLOR := Color(1.0, 0.35, 0.35)

var pressed := false


func _ready() -> void:
	# Above the knight (1) and the aim (2), so bodies on it don't hide it.
	z_index = 3
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = PotionData.SPLASH_MASK
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 8)
	shape.shape = rect
	shape.position = Vector2(0, -4)
	add_child(shape)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var now := has_overlapping_bodies()
	if now != pressed:
		pressed = now
		queue_redraw()
		toggled.emit(pressed)


## button_light.png: up and pressed, 24 x 4 each (a 20-wide plate on its
## base). Wider plates stretch the middle; the 3 px at each end stay as drawn.
const SHEET := preload("res://assets/sprites/props/button_light.png")
const FRAME_SIZE := Vector2(24, 4)
const END := 3.0


func _draw() -> void:
	var frame := Rect2(Vector2(FRAME_SIZE.x if pressed else 0.0, 0), FRAME_SIZE)
	PressurePlate.draw_stretched(self, SHEET, frame, Rect2(-width / 2.0 - 2.0, -FRAME_SIZE.y, width + 4.0, FRAME_SIZE.y), END)


## Draws `frame` of `sheet` into `rect`, keeping `end` pixels at each side as
## they are and stretching the middle across.
static func draw_stretched(canvas: CanvasItem, sheet: Texture2D, frame: Rect2, rect: Rect2, end: float, tint := Color.WHITE) -> void:
	var middle := frame.size.x - end * 2.0
	canvas.draw_texture_rect_region(sheet, Rect2(rect.position, Vector2(end, rect.size.y)), Rect2(frame.position, Vector2(end, frame.size.y)), tint)
	canvas.draw_texture_rect_region(sheet, Rect2(rect.position + Vector2(end, 0), Vector2(rect.size.x - end * 2.0, rect.size.y)), Rect2(frame.position + Vector2(end, 0), Vector2(middle, frame.size.y)), tint)
	canvas.draw_texture_rect_region(sheet, Rect2(Vector2(rect.end.x - end, rect.position.y), Vector2(end, rect.size.y)), Rect2(frame.position + Vector2(frame.size.x - end, 0), Vector2(end, frame.size.y)), tint)
