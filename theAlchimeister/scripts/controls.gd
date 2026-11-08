class_name Controls
extends RefCounted
## The player's key bindings: which actions can be remapped, what they're
## bound to now, and the key names shown around the game. SaveGame stores them;
## the notebook's SETTINGS > CONTROLS page changes them.
## Menus always move with WASD and back out with Esc, whatever is bound here.

## Name on the controls page, and the input action.
const REMAPPABLE: Array[Array] = [
	["MOVE LEFT", &"move_left"],
	["MOVE RIGHT", &"move_right"],
	["JUMP", &"jump"],
	["INTERACT", &"interact"],
	["NOTEBOOK", &"toggle_book"],
	["LOG", &"open_log"],
	["RESTART", &"restart"],
	["POTION 1", &"potion_1"],
	["POTION 2", &"potion_2"],
	["POTION 3", &"potion_3"],
	["POTION 4", &"potion_4"],
	["POTION 5", &"potion_5"],
]

## Action -> its keys from the project settings, read before any remapping.
static var _defaults := {}


## Binds every action to its saved keys, or its default if none are saved.
## `saved` maps action names to arrays of physical keycodes.
static func apply(saved: Dictionary) -> void:
	_read_defaults()
	for entry in REMAPPABLE:
		var action: StringName = entry[1]
		var keys: Variant = saved.get(String(action), [])
		_bind(action, keys if keys is Array and not keys.is_empty() else _defaults[action])


## Binds `action` to `key` alone. Any other action using that key loses it; one
## left with no keys takes `action`'s old key, so the two swap.
static func rebind(action: StringName, key: int) -> void:
	_read_defaults()
	var old := keys_of(action)
	for entry in REMAPPABLE:
		var other: StringName = entry[1]
		var keys := keys_of(other)
		if other == action or not keys.has(key):
			continue
		keys.erase(key)
		if keys.is_empty() and not old.is_empty() and old[0] != key:
			keys.append(old[0])
		_bind(other, keys)
	_bind(action, [key])


## Every remappable action's keys now, in the form apply() takes.
static func current() -> Dictionary:
	var bindings := {}
	for entry in REMAPPABLE:
		bindings[String(entry[1])] = keys_of(entry[1])
	return bindings


## The physical keycodes bound to `action`.
static func keys_of(action: StringName) -> Array:
	var keys := []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append(int(event.physical_keycode))
	return keys


## The name of `action`'s main key, e.g. "SPACE".
static func key_name(action: StringName) -> String:
	var keys := keys_of(action)
	return name_of(keys[0]) if not keys.is_empty() else "?"


## Every key bound to `action`, e.g. "SPACE / W".
static func all_key_names(action: StringName) -> String:
	return " / ".join(keys_of(action).map(name_of))


static func name_of(key: int) -> String:
	return OS.get_keycode_string(key).to_upper()


## `text` with each {action} swapped for its key, e.g. "Press {toggle_book}".
static func fill(text: String) -> String:
	if not text.contains("{"):
		return text
	for entry in REMAPPABLE:
		text = text.replace("{%s}" % entry[1], key_name(entry[1]))
	return text


static func _read_defaults() -> void:
	if _defaults.is_empty():
		for entry in REMAPPABLE:
			_defaults[entry[1]] = keys_of(entry[1])


static func _bind(action: StringName, keys: Array) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = int(key) as Key
		InputMap.action_add_event(action, event)
