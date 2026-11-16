@tool
class_name SelectionBox
extends StyleBox
## The mark round whatever is picked: only the corners of selection_ui.png,
## the top-left one and the bottom-right one, set just outside it. UiFocus
## draws it on its own layer over everything, always at the same size and
## shape, however big (or scaled) the picked thing is. As every theme's focus
## style it draws nothing itself (`for_overlay` is only on for UiFocus's
## drawing), so buttons can't scale or cut it off. UiFocus pulses it (`expand`,
## `modulate_color`), and hides it (`shown`) unless the player is navigating
## with the keys or a pad: something picked by a click or a tap doesn't get it.

@export var texture: Texture2D
## The two corner pieces in the texture, side by side: the left column is the
## top-left corner, the right column the bottom-right one (14 x 16 each).
@export var top_left := Rect2(0, 0, 14, 16)
@export var bottom_right := Rect2(14, 0, 14, 16)
## How far outside the button the corners sit.
@export var expand := 2.0
@export var modulate_color := Color.WHITE
## Only after a key press, and off again while the mouse or touch is in use
## (see UiFocus).
static var shown := false
## Set by UiFocus while it draws the mark on its layer.
static var for_overlay := false


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if not texture or not for_overlay:
		return
	var outer := rect.grow(expand)
	var rid := texture.get_rid()
	RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(outer.position, top_left.size), rid, top_left, modulate_color)
	RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(outer.end - bottom_right.size, bottom_right.size), rid, bottom_right, modulate_color)
