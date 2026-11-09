extends Node
## Autoload "UiFocus": keeps the keyboard selection out of a mouse player's way.
## Any click clears the selection box. The next WASD (or Tab) press brings it
## back on the first item of whatever screen is showing.
## A screen joins the SCREENS group and has focus_first() -> bool: it selects
## its first item and returns true, or returns false if it isn't showing now.

const SCREENS := &"focus_screens"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


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
	# On release: a button that loses focus mid-press cancels the click.
	# Deferred, so it also clears anything the click itself selected.
	if event is InputEventMouseButton and not event.pressed and event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_clear.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_nav(event) or get_viewport().gui_get_focus_owner():
		return
	for screen in get_tree().get_nodes_in_group(SCREENS):
		if screen.focus_first():
			get_viewport().set_input_as_handled()
			return


func _clear() -> void:
	# Never out of a box someone is typing in.
	if not get_viewport().gui_get_focus_owner() is LineEdit:
		get_viewport().gui_release_focus()


func _is_nav(event: InputEvent) -> bool:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action_pressed(action):
			return true
	return false
