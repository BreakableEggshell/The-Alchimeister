class_name DebugCode
extends RefCounted
## Spots the secret key combo (wwssadad) that opens the debug tools, on the
## start menu and in the pause menu. Feed it every input event.

## The keys, in order.
const CODE: Array[Key] = [KEY_W, KEY_W, KEY_S, KEY_S, KEY_A, KEY_D, KEY_A, KEY_D]

## The last few keys pressed.
var _typed: Array[Key] = []


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
