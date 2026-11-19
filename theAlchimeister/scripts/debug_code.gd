class_name DebugCode
extends RefCounted
## Spots the secret key combo (wwssadad) that opens the debug tools, on the
## start menu and in the pause menu. Feed it every input event.
## Phones have no keys: on the start menu, the same is done by tapping the two
## silhouettes in the background, left and right: L R L R L L R R (see
## feed_tap).

## The keys, in order.
const CODE: Array[Key] = [KEY_W, KEY_W, KEY_S, KEY_S, KEY_A, KEY_D, KEY_A, KEY_D]
## The taps, in order: -1 the left silhouette, 1 the right.
const TAP_CODE: Array[int] = [-1, 1, -1, 1, -1, -1, 1, 1]

## The last few keys pressed.
var _typed: Array[Key] = []
## The last few silhouettes tapped.
var _tapped: Array[int] = []


## True when this key press finishes the combo.
func feed(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return false
	_typed.append(key.physical_keycode)
	if _typed.size() > CODE.size():
		_typed.pop_front()
	if _typed == CODE:
		_typed.clear()
		return true
	return false


## True when this press finishes the tap combo. `left` and `right` are the
## silhouettes' areas; a press anywhere else starts it over. A touch counts
## through the mouse press it makes (so a click works too, on a desktop).
func feed_tap(event: InputEvent, left: Rect2, right: Rect2) -> bool:
	var press := event as InputEventMouseButton
	if not press or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return false
	var side := -1 if left.has_point(press.position) else (1 if right.has_point(press.position) else 0)
	if side == 0:
		_tapped.clear()
		return false
	_tapped.append(side)
	if _tapped.size() > TAP_CODE.size():
		_tapped.pop_front()
	if _tapped == TAP_CODE:
		_tapped.clear()
		return true
	return false
