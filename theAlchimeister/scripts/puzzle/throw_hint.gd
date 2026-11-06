extends Node2D
## A "TAP AND DRAG" sign in the world that acts out a throw on a loop: a finger
## presses, drags back with the band stretching behind it, the dotted aim arc
## grows the opposite way, and on release the potion flies along the dots.
## Same colours as the real aim (PotionThrower). It fades in once the player
## holds a potion and goes away for good after their first throw.
## Place it in a stage whose root is a puzzle level (it reads owner.thrower
## and owner.inventory).

const FONT := preload("res://assets/brackeys_platformer_assets/fonts/PixelOperator8.ttf")
const SIZE := Vector2(112, 64)
const PANEL_COLOR := Color(0.1, 0.09, 0.14, 0.82)
const TEXT_COLOR := Color(0.95, 0.9, 0.8)
const BAND_COLOR := Color(0.95, 0.85, 0.55, 0.9)
const DOT_COLOR := Color(1, 1, 1, 0.95)
const FINGER_COLOR := Color(1, 1, 1)
const LOOP_TIME := 2.6
## Where the press starts, and the pull (drag) relative to it, in local pixels.
const ANCHOR := Vector2(-10, 2)
const PULL := Vector2(-16, 16)
## Launch velocity per pixel of pull and gravity, scaled down to fit the sign.
const LAUNCH_SCALE := 4.2
const GRAVITY := 160.0
const FLIGHT_TIME := 0.62
const DOT_COUNT := 9

var _clock := 0.0
var _shown := false
var _done := false
var _inventory: Inventory


func _ready() -> void:
	modulate.a = 0.0
	z_index = 4
	var stage := owner
	if stage and stage.get("thrower"):
		stage.thrower.thrown.connect(_on_thrown)
	if stage and stage.get("inventory"):
		_inventory = stage.inventory
		_inventory.changed.connect(_update_shown)
	_update_shown()


func _process(delta: float) -> void:
	_clock = fmod(_clock + delta, LOOP_TIME)
	if modulate.a > 0.0:
		queue_redraw()


func _update_shown() -> void:
	var holding := false
	if _inventory:
		for kind in PotionData.KINDS:
			holding = holding or _inventory.count(kind) > 0
	var show_now := holding and not _done
	if show_now == _shown:
		return
	_shown = show_now
	if show_now:
		_clock = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0 if show_now else 0.0, 0.4)


func _on_thrown() -> void:
	_done = true
	_update_shown()


func _draw() -> void:
	var panel := Rect2(-SIZE / 2.0, SIZE)
	draw_rect(panel, PANEL_COLOR)
	draw_rect(panel.grow(-0.5), Color(TEXT_COLOR, 0.5), false)
	draw_string(FONT, Vector2(panel.position.x, panel.position.y + 11), "TAP AND DRAG", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 8, TEXT_COLOR)
	draw_string(FONT, Vector2(panel.position.x, panel.end.y - 4), "LET GO TO THROW", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 8, Color(TEXT_COLOR, 0.7))

	# 0-0.25 press, 0.25-1.15 drag back, 1.15-1.5 hold, then throw.
	var t := _clock
	var pull_amount := clampf((t - 0.25) / 0.9, 0.0, 1.0)
	pull_amount = 1.0 - pow(1.0 - pull_amount, 2.0)
	var released := t >= 1.5
	var pull := PULL * pull_amount
	var launch := -pull * LAUNCH_SCALE

	if not released:
		# The aim: band from the press point to the finger, dots along the arc.
		if pull_amount > 0.0:
			draw_line(ANCHOR, ANCHOR + pull, BAND_COLOR, 1.0)
			for i in DOT_COUNT:
				var at := _arc(launch, FLIGHT_TIME * (i + 1) / DOT_COUNT)
				var fade := 1.0 - 0.6 * float(i) / DOT_COUNT
				draw_circle(at, 1.2, Color(DOT_COLOR, DOT_COLOR.a * fade))
		draw_circle(ANCHOR, 2.0, BAND_COLOR)
		PotionData.draw_potion(self, PotionData.FREEZE, ANCHOR + Vector2(0, -1))
		_draw_finger(ANCHOR + pull, t < 0.25)
	else:
		# The potion flies along where the dots were; the finger lifts away.
		var flight := clampf((t - 1.5) / FLIGHT_TIME, 0.0, 1.0)
		if flight < 1.0:
			PotionData.draw_potion(self, PotionData.FREEZE, _arc(-PULL * LAUNCH_SCALE, FLIGHT_TIME * flight))
		var lift := clampf((t - 1.5) / 0.3, 0.0, 1.0)
		var finger_color := Color(FINGER_COLOR, 1.0 - lift)
		draw_circle(ANCHOR + PULL, 3.0, Color(finger_color, finger_color.a * 0.35))
		draw_arc(ANCHOR + PULL, 3.0 + 3.0 * lift, 0.0, TAU, 16, finger_color, 1.0)


## Point on the aim arc `time` seconds after launch, starting at the anchor.
func _arc(launch: Vector2, time: float) -> Vector2:
	return ANCHOR + launch * time + Vector2(0, 0.5 * GRAVITY * time * time)


## A fingertip: a filled circle, with a ring pulsing out while pressing.
func _draw_finger(at: Vector2, pressing: bool) -> void:
	draw_circle(at, 3.0, Color(FINGER_COLOR, 0.35))
	draw_arc(at, 3.0, 0.0, TAU, 16, FINGER_COLOR, 1.0)
	if pressing:
		var pulse := _clock / 0.25
		draw_arc(at, 3.0 + 4.0 * pulse, 0.0, TAU, 16, Color(FINGER_COLOR, 1.0 - pulse), 1.0)
