extends Node2D
## A "DRAG ONTO THE X / TO CANCEL" sign that acts out a cancelled throw on a
## loop: a finger presses and drags back (the aim appears, and so does a
## little red X box up and to the right, like the real cancel box), then moves up
## onto the X (the aim goes away, the X lights up) and lets go: nothing is
## thrown. Same look as the "TAP AND DRAG" sign (ThrowHint).
## It appears once `chest` has been opened and its conversation is over, and
## goes away for good after the player first cancels a throw on the real X.
## Place it in a stage whose root is a puzzle level (it reads owner.thrower).

const ThrowHint := preload("res://scripts/puzzle/throw_hint.gd")
const SIZE := Vector2(106, 64)
const LOOP_TIME := 3.6
## The mini cancel box, in the sign's top right; colours match the HUD's.
const BOX := Rect2(32, -18, 16, 16)
const BOX_FILL := Color(0.8, 0.2, 0.25, 0.35)
const BOX_BORDER := Color(1, 0.4, 0.45, 0.9)
const BOX_X := Color(1, 0.75, 0.78)
## Where the press starts and how far it drags back (left of the usual sign,
## so the aim arc stays clear of the box).
const ANCHOR := Vector2(-26, 4)
const PULL := Vector2(-16, 16)

## The chest whose opening brings the sign up.
@export var chest: Node

var _clock := 0.0
var _shown := false
var _done := false


func _ready() -> void:
	modulate.a = 0.0
	z_index = 4
	if chest and chest.has_signal("opened"):
		chest.opened.connect(_on_chest_opened)
	var stage := owner
	if stage and stage.get("thrower"):
		stage.thrower.throw_cancelled.connect(_on_cancelled)


func _process(delta: float) -> void:
	_clock = fmod(_clock + delta, LOOP_TIME)
	if modulate.a > 0.0:
		queue_redraw()


func is_shown() -> bool:
	return _shown


## Right away; the "+1 ..." pickup text would be in the sign's way, so it goes.
func _on_chest_opened() -> void:
	var stage := owner
	if stage and stage.get("hud"):
		stage.hud.clear_messages()
	_set_shown(true)


func _on_cancelled(on_cancel_zone: bool) -> void:
	# Only on the X, and only once they've seen the sign; then it's learned.
	if _shown and on_cancel_zone:
		_done = true
		_set_shown(false)


func _set_shown(show_now: bool) -> void:
	show_now = show_now and not _done
	if show_now == _shown:
		return
	_shown = show_now
	if show_now:
		_clock = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0 if show_now else 0.0, 0.4)


func _draw() -> void:
	var font := ThrowHint.FONT
	var text_color := ThrowHint.TEXT_COLOR
	var panel := Rect2(-SIZE / 2.0, SIZE)
	draw_rect(panel, ThrowHint.PANEL_COLOR)
	draw_rect(panel.grow(-0.5), Color(text_color, 0.5), false)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 11), "DRAG ONTO THE X", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 8, text_color)
	draw_string(font, Vector2(panel.position.x, panel.end.y - 4), "TO CANCEL", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 8, Color(text_color, 0.7))

	# 0-0.25 press, 0.25-0.9 drag back, 0.9-1.2 hold, 1.2-2.0 move onto the
	# X, 2.0-2.3 rest there, then let go: nothing is thrown.
	var t := _clock
	var out := clampf((t - 0.25) / 0.65, 0.0, 1.0)
	out = 1.0 - pow(1.0 - out, 2.0)
	var to_box := smoothstep(0.0, 1.0, clampf((t - 1.2) / 0.8, 0.0, 1.0))
	var released := t >= 2.3
	var finger := (ANCHOR + PULL * out).lerp(BOX.get_center(), to_box)
	var over_box := BOX.has_point(finger)
	PotionData.draw_potion(self, PotionData.FIRE, ANCHOR + Vector2(0, -1))

	# The X box shows while aiming, brighter with the finger on it, and
	# fades after letting go.
	var box_alpha := 0.0
	if t >= 0.25:
		box_alpha = 1.0 if over_box else 0.5
		if released:
			box_alpha *= 1.0 - clampf((t - 2.3) / 0.4, 0.0, 1.0)
	if box_alpha > 0.0:
		draw_rect(BOX, Color(BOX_FILL, BOX_FILL.a * box_alpha))
		draw_rect(BOX.grow(-0.5), Color(BOX_BORDER, BOX_BORDER.a * box_alpha), false)
		var c := BOX.get_center()
		var x_color := Color(BOX_X, box_alpha)
		draw_line(c + Vector2(-3, -3), c + Vector2(3, 3), x_color, 1.5)
		draw_line(c + Vector2(3, -3), c + Vector2(-3, 3), x_color, 1.5)

	if not released:
		if t >= 0.25:
			# The band points from the press toward the finger, at most a
			# full pull long, like the real one.
			var pull := (finger - ANCHOR).limit_length(PULL.length())
			draw_circle(ANCHOR, 2.0, ThrowHint.BAND_COLOR)
			draw_line(ANCHOR, ANCHOR + pull, ThrowHint.BAND_COLOR, 1.0)
			# The aim arc only while pulling back; it goes once the finger
			# heads for the X.
			if t < 1.2 and pull.length() > 5.0:
				var launch := -pull * ThrowHint.LAUNCH_SCALE
				for i in ThrowHint.DOT_COUNT:
					var time := ThrowHint.FLIGHT_TIME * (i + 1) / ThrowHint.DOT_COUNT
					var at := ANCHOR + launch * time + Vector2(0, 0.5 * ThrowHint.GRAVITY * time * time)
					var fade := 1.0 - 0.6 * float(i) / ThrowHint.DOT_COUNT
					draw_circle(at, 1.2, Color(ThrowHint.DOT_COLOR, ThrowHint.DOT_COLOR.a * fade))
		_draw_finger(finger, t < 0.25)
	else:
		# The finger lifts away from the X; the potion stays where it was.
		var lift := clampf((t - 2.3) / 0.3, 0.0, 1.0)
		var color := Color(ThrowHint.FINGER_COLOR, 1.0 - lift)
		draw_circle(finger, 3.0, Color(color, color.a * 0.35))
		draw_arc(finger, 3.0 + 3.0 * lift, 0.0, TAU, 16, color, 1.0)


## A fingertip: a filled circle, with a ring pulsing out while pressing.
func _draw_finger(at: Vector2, pressing: bool) -> void:
	draw_circle(at, 3.0, Color(ThrowHint.FINGER_COLOR, 0.35))
	draw_arc(at, 3.0, 0.0, TAU, 16, ThrowHint.FINGER_COLOR, 1.0)
	if pressing:
		var pulse := _clock / 0.25
		draw_arc(at, 3.0 + 4.0 * pulse, 0.0, TAU, 16, Color(ThrowHint.FINGER_COLOR, 1.0 - pulse), 1.0)
