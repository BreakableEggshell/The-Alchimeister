extends Node
## Autoload "UiFocus": keeps the keyboard selection out of a mouse player's way.
## Any click clears the selection box. The next WASD / arrow (or Tab) press
## brings it back on the first item of whatever screen is showing. Draws the
## selection mark (SelectionBox) while the player is navigating with the keys
## or a pad, remembered across screens and scenes.
## A screen joins the SCREENS group and has focus_first() -> bool: it selects
## its first item and returns true, or returns false if it isn't showing now.

const SCREENS := &"focus_screens"
## What marks the picked button (every theme's focus style, SelectionBox): its
## top-left and bottom-right corners, which pulse, stepping out a pixel and back, brighter, then fainter.
const SELECTION := preload("res://scenes/ui/selection_style.tres")
## Seconds for one pulse.
const PULSE_TIME := 0.9
## How far the brackets sit outside the button: in, then out a step.
const PULSE_IN := 2.0
const PULSE_OUT := 3.0

var _pulse_out := false
## A menu just popped up over play (hide_mark): a key still held from moving
## the knight (its auto-repeat) doesn't move the selection until it's
## pressed again.
var _ignore_held := false
## Where the mark is drawn: its own layer, over the game and menus, under the
## iris (layer 100).
var _layer: CanvasLayer
var _mark: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 99
	add_child(_layer)
	_mark = Node2D.new()
	_mark.draw.connect(_draw_mark)
	_layer.add_child(_mark)


## The corners round the picked control, on screen, at 1:1 whatever its size or
## scale. A control can give the part to mark as meta "selection_rect" (its
## own coordinates), like a level select node marking its stone, not its number.
func _draw_mark() -> void:
	var picked := get_viewport().gui_get_focus_owner()
	if not SelectionBox.shown or not picked or not picked.is_visible_in_tree():
		return
	var local: Rect2 = picked.get_meta("selection_rect", Rect2(Vector2.ZERO, picked.size))
	var on_screen := picked.get_global_transform_with_canvas() * local
	SelectionBox.for_overlay = true
	SELECTION.draw(_mark.get_canvas_item(), on_screen.abs())
	SelectionBox.for_overlay = false


## The pulse: the brackets step out and back and fade a little, redrawing
## whatever is picked.
func _process(_delta: float) -> void:
	var wave := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / PULSE_TIME)
	var style: SelectionBox = SELECTION
	style.modulate_color = Color(1, 1, 1, lerpf(0.7, 1.0, wave))
	var out := wave > 0.5
	if out != _pulse_out:
		_pulse_out = out
		style.expand = PULSE_OUT if out else PULSE_IN
	_mark.queue_redraw()


## Keeps keyboard moves inside a panel (the automatic moves can land on buttons
## hidden behind it): `controls` go in order top to bottom, wrapping round, and
## left and right stay put. Call once they're in the tree.
static func link_column(controls: Array) -> void:
	for i in controls.size():
		var control: Control = controls[i]
		var up: Control = controls[posmod(i - 1, controls.size())]
		var down: Control = controls[posmod(i + 1, controls.size())]
		control.focus_neighbor_top = up.get_path()
		control.focus_previous = up.get_path()
		control.focus_neighbor_bottom = down.get_path()
		control.focus_next = down.get_path()
		control.focus_neighbor_left = control.get_path()
		control.focus_neighbor_right = control.get_path()


## The same for a row: left and right wrap round, up and down stay put.
static func link_row(controls: Array) -> void:
	for i in controls.size():
		var control: Control = controls[i]
		var left: Control = controls[posmod(i - 1, controls.size())]
		var right: Control = controls[posmod(i + 1, controls.size())]
		control.focus_neighbor_left = left.get_path()
		control.focus_previous = left.get_path()
		control.focus_neighbor_right = right.get_path()
		control.focus_next = right.get_path()
		control.focus_neighbor_top = control.get_path()
		control.focus_neighbor_bottom = control.get_path()


func _input(event: InputEvent) -> void:
	# Which names to show around the game: the controller's, or the keys'.
	if event is InputEventJoypadButton or event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		Controls.set_using_pad(true)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		Controls.set_using_pad(false)
		# On a touchscreen: a key means there's a keyboard after all.
		if event is InputEventKey:
			Controls.set_using_touch(false)
		elif event is InputEventScreenTouch:
			Controls.set_using_touch(true)
	# The selection mark is for navigating with the keys (or a pad): it shows
	# once the player moves the selection in a menu (arrows, WASD, Tab, d-pad)
	# and stays on from screen to screen, scene changes included, until a
	# click, a tap, the mouse moving, or playing (moving the knight with no
	# menu up; see _unhandled_input). Other keys (B, Enter) leave it as it is.
	if _ignore_held and _is_nav(event, true):
		if event.is_echo():
			get_viewport().set_input_as_handled()
			return
		_ignore_held = false
	if _is_nav(event) and get_viewport().gui_get_focus_owner():
		# The first press only reveals where the selection is (START on the
		# start menu, say); the next ones move it.
		if not SelectionBox.shown:
			get_viewport().set_input_as_handled()
		_set_navigating(true)
	elif event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_navigating(false)
	elif event is InputEventMouseMotion and event.relative.length() > 1.0:
		_set_navigating(false)
	# On release: a button that loses focus mid-press cancels the click.
	# Deferred, so it also clears anything the click itself selected.
	if event is InputEventMouseButton and not event.pressed and event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_clear.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_nav(event) or get_viewport().gui_get_focus_owner():
		return
	for screen in get_tree().get_nodes_in_group(SCREENS):
		if screen.focus_first():
			_set_navigating(true)
			get_viewport().set_input_as_handled()
			return
	# Nothing to pick: the keys are moving the knight, not a selection.
	_set_navigating(false)


## A menu just popped up over play (the skip-dialogue box, the end-of-stage
## buttons): the mark waits, so the first key press only shows where the
## selection starts (YES, NEXT) rather than moving it straight off. The mouse
## pointer stays as it was.
func hide_mark() -> void:
	SelectionBox.shown = false
	_ignore_held = true
	_mark.queue_redraw()


## Navigating with the keys or a pad (or not): the selection mark shows, and
## the mouse pointer hides while it does (back as soon as the mouse moves).
func _set_navigating(on: bool) -> void:
	SelectionBox.shown = on
	var mode := Input.MOUSE_MODE_HIDDEN if on else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode and Input.mouse_mode in [Input.MOUSE_MODE_VISIBLE, Input.MOUSE_MODE_HIDDEN]:
		Input.mouse_mode = mode


func _clear() -> void:
	# Never out of a box someone is typing in.
	if not get_viewport().gui_get_focus_owner() is LineEdit:
		get_viewport().gui_release_focus()


## A press moving the selection (with `held`, a held key's repeats count too).
func _is_nav(event: InputEvent, held := false) -> bool:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action_pressed(action, held):
			return true
	return false
