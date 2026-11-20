class_name Controls
extends RefCounted
## The player's key bindings: which actions can be remapped, what they're
## bound to now, and the key names shown around the game. SaveGame stores them;
## the notebook's SETTINGS > CONTROLS page changes them.
## Menus always move with WASD or the arrow keys and back out with Esc,
## whatever is bound here.
## A controller works too, always bound the same way (not remappable; see
## PAD_BUTTONS, PAD_AXES). Once it's used, the names shown around the game are
## its buttons (using_pad), until a key, click or touch.

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
	["POTION 6", &"potion_6"],
]

## Action -> its keys from the project settings, read before any remapping.
static var _defaults := {}
static var _touch_checked := false

## Controller buttons for each action: left stick or d-pad to move and to
## steer menus, A jump (and confirm), B back out, X interact, Y notebook, BACK
## log, START pause (as Esc does), LB / RB the potion before / after (and the
## page before / after in menus). The right stick aims and RT throws (see
## PotionThrower).
const PAD_BUTTONS := {
	&"ui_left": [JOY_BUTTON_DPAD_LEFT],
	&"ui_right": [JOY_BUTTON_DPAD_RIGHT],
	&"ui_up": [JOY_BUTTON_DPAD_UP],
	&"ui_down": [JOY_BUTTON_DPAD_DOWN],
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"move_up": [JOY_BUTTON_DPAD_UP],
	&"move_down": [JOY_BUTTON_DPAD_DOWN],
	&"jump": [JOY_BUTTON_A],
	&"ui_accept": [JOY_BUTTON_A],
	&"ui_cancel": [JOY_BUTTON_B, JOY_BUTTON_START],
	&"interact": [JOY_BUTTON_X],
	&"toggle_book": [JOY_BUTTON_Y],
	&"open_log": [JOY_BUTTON_BACK],
	&"potion_prev": [JOY_BUTTON_LEFT_SHOULDER],
	&"potion_next": [JOY_BUTTON_RIGHT_SHOULDER],
	&"ui_page_up": [JOY_BUTTON_LEFT_SHOULDER],
	&"ui_page_down": [JOY_BUTTON_RIGHT_SHOULDER],
}
## Controller sticks and triggers for each action: [axis, which way].
const PAD_AXES := {
	&"ui_left": [[JOY_AXIS_LEFT_X, -1.0]],
	&"ui_right": [[JOY_AXIS_LEFT_X, 1.0]],
	&"ui_up": [[JOY_AXIS_LEFT_Y, -1.0]],
	&"ui_down": [[JOY_AXIS_LEFT_Y, 1.0]],
	&"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	&"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	&"move_up": [[JOY_AXIS_LEFT_Y, -1.0]],
	&"move_down": [[JOY_AXIS_LEFT_Y, 1.0]],
	&"aim_left": [[JOY_AXIS_RIGHT_X, -1.0]],
	&"aim_right": [[JOY_AXIS_RIGHT_X, 1.0]],
	&"aim_up": [[JOY_AXIS_RIGHT_Y, -1.0]],
	&"aim_down": [[JOY_AXIS_RIGHT_Y, 1.0]],
	&"throw": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
}
## How far a stick must lean to count, for the actions made here (aiming
## reads small leans too).
const PAD_DEADZONE := 0.5
const AIM_DEADZONE := 0.2
## The names shown for each action while a controller is in use. Actions not
## listed have no name then (the potion keys: LB / RB cycle instead).
const PAD_NAMES := {
	&"jump": "A",
	&"interact": "X",
	&"toggle_book": "Y",
	&"open_log": "BACK",
	&"move_left": "LEFT",
	&"move_right": "RIGHT",
}
## Esc's name while a controller is in use.
const PAD_CANCEL_NAME := "B"

## A controller was used last (not a key, click or touch).
static var using_pad := false
## On a touchscreen (TouchControls.touch_on), until a key is pressed: there are
## no keys to name, so none are (key_name gives "").
static var using_touch := false
## With no key to name (a touchscreen): what dialogue calls the button instead
## (see fill).
const TOUCH_NAMES := {&"jump": "the JUMP button", &"toggle_book": "the notebook button"}


## Binds every action to its saved keys, or its default if none are saved.
## `saved` maps action names to arrays of physical keycodes.
static func apply(saved: Dictionary) -> void:
	_read_defaults()
	add_pad_bindings()
	if not _touch_checked:
		_touch_checked = true
		using_touch = TouchControls.touch_on()
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


## The name of `action`'s main key, e.g. "SPACE" (or its controller button's,
## with a controller in use).
static func key_name(action: StringName) -> String:
	if using_pad:
		return PAD_NAMES.get(action, "")
	if using_touch:
		return ""
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
		var action: StringName = entry[1]
		var name := key_name(action)
		if name == "":
			# Nothing to press: "notebook [{toggle_book}]" loses its brackets,
			# and "with {jump}" names the button instead.
			text = text.replace(" [{%s}]" % action, "").replace("[{%s}]" % action, "")
			name = TOUCH_NAMES.get(action, String(entry[0]))
		text = text.replace("{%s}" % action, name)
	return text


## Esc's name: "ESC", or with a controller in use, the button that does it
## (nothing on a touchscreen).
static func cancel_name() -> String:
	if using_pad:
		return PAD_CANCEL_NAME
	return "" if using_touch else "ESC"


## "[E]" for a prompt like "[E]Open", or "" with no key to name.
static func bracket(action: StringName) -> String:
	var name := key_name(action)
	return "[%s]" % name if name != "" else ""


## Adds the controller buttons and sticks (PAD_BUTTONS, PAD_AXES), making the
## actions only a controller has. Safe to call again.
static func add_pad_bindings() -> void:
	for action in PAD_BUTTONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, PAD_DEADZONE)
		for button in PAD_BUTTONS[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			_add_once(action, event)
	for action in PAD_AXES:
		if not InputMap.has_action(action):
			InputMap.add_action(action, AIM_DEADZONE if String(action).begins_with("aim_") else PAD_DEADZONE)
		for axis in PAD_AXES[action]:
			var event := InputEventJoypadMotion.new()
			event.axis = axis[0]
			event.axis_value = axis[1]
			_add_once(action, event)


static func _add_once(action: StringName, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if existing.is_match(event, true):
			return
	InputMap.action_add_event(action, event)


## Notes whether the controller is in use now (see using_pad); the names shown
## around the game change with it.
static func set_using_pad(on: bool) -> void:
	if on == using_pad:
		return
	using_pad = on
	_announce()


## Notes a key (off) or a touch (on) on a touchscreen (see using_touch).
static func set_using_touch(on: bool) -> void:
	if on == using_touch:
		return
	using_touch = on
	_announce()


static func _announce() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var save: Node = tree.root.get_node_or_null("SaveGame") if tree else null
	if save:
		save.controls_changed.emit()


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
