class_name TouchControls
extends Control
## On-screen buttons for phones and tablets. Bottom left: LEFT and RIGHT,
## with JUMP a flat bar above them, held by touch (several fingers at once;
## sliding a finger from LEFT to RIGHT turns round, and from LEFT or RIGHT up
## onto JUMP jumps while still going that way), pressing the same actions as
## the keys. Bottom right: PAUSE, which does what Esc does (the pause menu; mid-talk, the skip
## box).
## Shown on touchscreens, or with the "touch" user argument to try them on a
## desktop (`-- touch`; the mouse works them there). Hidden while someone's
## talking, the book or pause menu is open, or the stage is over. A touch
## anywhere else still aims and throws as before.
## Lives under the HUD (PotionHud), which it asks what's showing.

## Each button's size, and the gaps round them.
const BUTTON := Vector2(30, 30)
const PAUSE_BUTTON := Vector2(20, 20)
const MARGIN := 6.0
const GAP := 4.0
## JUMP: a flat bar above LEFT and RIGHT, as wide as both.
const JUMP_HEIGHT := 16.0
const FILL := Color(0.1, 0.09, 0.14, 0.45)
const FILL_HELD := Color(0.95, 0.85, 0.55, 0.55)
const EDGE := Color(1, 1, 1, 0.55)
const ICON := Color(1, 1, 1, 0.85)
## A finger held on a button: what it holds.
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump"]
const PAUSE := &"pause"
## The mouse on a desktop ("touch" argument) counts as this finger.
const MOUSE_FINGER := -100

var enabled := false
## Finger index -> the buttons it holds (actions, or PAUSE): one, or JUMP
## plus the way it slid up from.
var _held := {}
## Actions this pressed (so it never lets go of one a key is holding).
var _pressed := {}
@onready var _hud: Node = get_parent()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
			or OS.get_cmdline_user_args().has("touch")
	visible = false


func _process(_delta: float) -> void:
	var show: bool = enabled and _hud != null and not get_tree().paused \
			and not _hud.dialogue.is_playing and not _hud.book.is_open and not _hud._stage_over
	if show != visible:
		visible = show
		if not show:
			_held.clear()
			_apply()
	queue_redraw()


## The buttons' rectangles, laid out from the screen's current size.
func _rects() -> Dictionary:
	var bottom := size.y - MARGIN - BUTTON.y
	var left := Rect2(Vector2(MARGIN, bottom), BUTTON)
	var right := Rect2(Vector2(left.end.x + GAP, bottom), BUTTON)
	var jump := Rect2(Vector2(MARGIN, bottom - GAP - JUMP_HEIGHT), Vector2(right.end.x - MARGIN, JUMP_HEIGHT))
	var pause := Rect2(size - Vector2(MARGIN, MARGIN) - PAUSE_BUTTON, PAUSE_BUTTON)
	return {&"move_left": left, &"move_right": right, &"jump": jump, PAUSE: pause}


## The button under `at` (screen pixels), or &"".
func _button_at(at: Vector2) -> StringName:
	var rects := _rects()
	for button in rects:
		if rects[button].grow(2.0).has_point(at):
			return button
	return &""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var finger := -1
	var pressed := false
	var moved := false
	if event is InputEventScreenTouch:
		finger = event.index
		pressed = event.pressed
	elif event is InputEventScreenDrag:
		finger = event.index
		moved = true
	elif event is InputEventMouse:
		# The mouse a touch pretends to be: kept off the buttons' area, so a
		# press there never starts a throw (the touch itself is handled above).
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			if _button_at(event.position) != &"" or _held.size() > 0 and event is InputEventMouseMotion:
				get_viewport().set_input_as_handled()
			return
		# A real mouse, trying them out on a desktop.
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			finger = MOUSE_FINGER
			pressed = event.pressed
		elif event is InputEventMouseMotion and _held.has(MOUSE_FINGER):
			finger = MOUSE_FINGER
			moved = true
		else:
			return
	else:
		return
	var at: Vector2 = event.position
	var button := _button_at(at)
	if moved:
		# Sliding along: from LEFT onto RIGHT turns round; from LEFT or RIGHT up
		# onto JUMP jumps and keeps going that way (back down drops the jump);
		# off the buttons lets go.
		if not _held.has(finger) or _held[finger].has(PAUSE):
			return
		if button == &"" or button == PAUSE:
			_held.erase(finger)
		elif button == &"jump":
			var holding: Array = [&"jump"]
			for move in _held[finger]:
				if move != &"jump":
					holding.append(move)
			_held[finger] = holding
		else:
			_held[finger] = [button]
		_apply()
		get_viewport().set_input_as_handled()
	elif pressed:
		if button == &"":
			return
		_held[finger] = [button]
		if button == PAUSE:
			_press_escape()
		_apply()
		get_viewport().set_input_as_handled()
	elif _held.has(finger):
		_held.erase(finger)
		_apply()
		get_viewport().set_input_as_handled()


## Presses and lets go of the actions to match the fingers held.
func _apply() -> void:
	var wanted := {}
	for buttons in _held.values():
		for button in buttons:
			if button != PAUSE:
				wanted[button] = true
	for action in ACTIONS:
		if wanted.has(action) and not _pressed.has(action):
			Input.action_press(action)
			_pressed[action] = true
		elif not wanted.has(action) and _pressed.has(action):
			Input.action_release(action)
			_pressed.erase(action)


## PAUSE: as if Esc were pressed.
func _press_escape() -> void:
	for down in [true, false]:
		var escape := InputEventAction.new()
		escape.action = &"ui_cancel"
		escape.pressed = down
		Input.parse_input_event(escape)


func _draw() -> void:
	var rects := _rects()
	var held := {}
	for buttons in _held.values():
		for button in buttons:
			held[button] = true
	for button in rects:
		var box: Rect2 = rects[button]
		draw_rect(box, FILL_HELD if held.has(button) else FILL)
		draw_rect(box.grow(-0.5), EDGE, false)
		var c := box.get_center().round()
		match button:
			&"move_left":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(4, -7), c + Vector2(4, 7)]), ICON)
			&"move_right":
				draw_colored_polygon(PackedVector2Array([c + Vector2(6, 0), c + Vector2(-4, -7), c + Vector2(-4, 7)]), ICON)
			&"jump":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(-7, 3), c + Vector2(7, 3)]), ICON)
			PAUSE:
				draw_rect(Rect2(c + Vector2(-4, -5), Vector2(3, 10)), ICON)
				draw_rect(Rect2(c + Vector2(1, -5), Vector2(3, 10)), ICON)
