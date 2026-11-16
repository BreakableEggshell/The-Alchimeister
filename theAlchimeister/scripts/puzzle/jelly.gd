@tool
class_name Jelly
extends StaticBody2D
## A block of bouncy jelly. Solid to stand on and walk into, but a potion that
## hits it bounces off instead of shattering, mirrored off the face it hit
## (see Potion.step, which the aim preview uses too, so the dotted arc shows
## the bounce). `strength` scales how fast it comes back: 1 for plain green
## jelly, more for the springy blue kind, which flings potions much further.
## The knight bounces off it too, as hard as they hit it (see
## PuzzleKnight._slide). It wobbles when hit. Origin is the top-left corner.

@export var size := Vector2(16, 48):
	set(value):
		size = value
		queue_redraw()
## Bounce speed as a multiple of the incoming speed.
@export var strength := 1.0:
	set(value):
		strength = value
		queue_redraw()

const PLAIN_COLOR := Color(0.45, 0.9, 0.5, 0.75)
const SPRINGY_COLOR := Color(0.3, 0.55, 1.0, 0.8)
## The knight: slowest hit that bounces off the top or bottom, and off a
## side (walking into a side doesn't bounce; a burning sprint does).
const MIN_BOUNCE_SPEED := 80.0
const MIN_SIDE_BOUNCE_SPEED := 100.0
## Share of the hit speed a plain jelly gives back, so bounces die down.
const KEEP := 0.85
## Fastest the knight is ever flung.
const MAX_BOUNCE_SPEED := 420.0
## Seconds a wobble takes to settle.
const WOBBLE_TIME := 0.5

var _wobble := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = PotionData.LAYER_WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)


## Springier than plain jelly: throws potions back harder.
func is_springy() -> bool:
	return strength > 1.0


## A potion just bounced off.
func wobble() -> void:
	_wobble = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _wobble > 0.0:
		_wobble = maxf(_wobble - delta / WOBBLE_TIME, 0.0)
		queue_redraw()


func _draw() -> void:
	var color := SPRINGY_COLOR if is_springy() else PLAIN_COLOR
	# A quick squash-and-stretch while wobbling; the hitbox stays put.
	var squash := sin(_wobble * TAU * 2.0) * _wobble * 1.5
	var box := Rect2(Vector2(-squash, squash), size + Vector2(squash * 2.0, -squash * 2.0))
	draw_rect(box, color)
	draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(box.size.x - 4, 2)), Color(1, 1, 1, 0.45))
	draw_rect(box, color.darkened(0.45), false, 1.0)
	# Bubbles inside, so it reads as jelly rather than a wall.
	for i in int(size.x * size.y / 160.0) + 1:
		var at := Vector2(fmod(i * 7.3, maxf(size.x - 6.0, 1.0)) + 3.0, fmod(i * 11.7, maxf(size.y - 6.0, 1.0)) + 3.0)
		draw_circle(box.position + at, 1.0, Color(1, 1, 1, 0.35))
	if is_springy():
		# Chevrons pointing out from every face: it pushes back hard.
		var mark := color.lightened(0.5)
		var c := box.get_center()
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var half := box.size / 2.0 - Vector2(4, 4)
			var tip: Vector2 = c + dir * Vector2(maxf(half.x, 0.0), maxf(half.y, 0.0))
			var side: Vector2 = dir.orthogonal() * 2.0
			draw_line(tip - dir * 2.0 + side, tip, mark, 1.0)
			draw_line(tip - dir * 2.0 - side, tip, mark, 1.0)
