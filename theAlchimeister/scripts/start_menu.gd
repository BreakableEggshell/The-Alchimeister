extends Control
## Start menu. START wipes progress (after asking, if there's any to lose) and
## starts a new run from the first level (with a secret timer, see SaveGame),
## CONTINUE drops you back into the stage
## you were last in, ALL LEVELS opens level select with everything unlocked,
## SETTINGS opens the settings page, DEBUG holds
## testing tools (reset progress, after asking; unlock everything; a dialogue
## test; a sandbox), EXIT quits.

const DIALOGUE_BOX := preload("res://scenes/ui/dialogue_box.tscn")
const PUZZLE_LEVEL := preload("res://scripts/puzzle/puzzle_level.gd")
const CHEST := preload("res://scripts/puzzle/chest.gd")
const SETTINGS_SIZE := Vector2(360, 186)
const DEBUG_SIZE := Vector2(190, 136)
const GOLD := Color(0.95, 0.85, 0.55)
## Every portrait there is to look at.
const TEST_LINES: Array[String] = [
	"SHELDON: This is my normal face.",
	"SHELDON (glasses): These are my explaining glasses.",
	"SHELDON (squint): And this is me thinking. Hmm.",
	"ALCHEMIST: This is the knight.",
	"ALCHEMIST (red_eye): This is the knight seeing red.",
	"ALCHEMIST (red_eye_rage): And this is the knight very angry.",
	"DEMON KING: AND I AM THE DEMON KING.",
	"DEMON KING (aura): FEEL MY AURA.",
	"SHELDON: He's in my spot.",
]

@onready var _start: Button = %StartButton
@onready var _continue: Button = %ContinueButton
@onready var _all_levels: Button = %AllLevelsButton
@onready var _settings_button: Button = %SettingsButton
@onready var _debug_button: Button = %DebugButton
@onready var _exit: Button = %ExitButton

var _settings: SettingsPanel
var _settings_modal: Control
var _debug: Control
var _debug_first: Button
var _debug_note: Label
var _reset_button: Button
var _dialogue_button: Button
var _dialogue: Control
var _confirm: Control
var _confirm_no: Button
var _start_confirm: Control
var _start_no: Button


func _ready() -> void:
	add_to_group(UiFocus.SCREENS)
	_start.pressed.connect(_on_start_pressed)
	_all_levels.pressed.connect(func() -> void:
		SaveGame.unlock_all_levels()
		SaveGame.go_to(SaveGame.LEVEL_SELECT))
	_continue.pressed.connect(func() -> void: SaveGame.play_stage(SaveGame.last_stage))
	_settings_button.pressed.connect(_open_settings)
	_debug_button.pressed.connect(_open_debug)
	_exit.pressed.connect(get_tree().quit)
	for button in [_start, _continue, _all_levels, _settings_button, _debug_button, _exit]:
		button.mouse_entered.connect(button.grab_focus)
	_settings_modal = _build_settings()
	_debug = _build_debug()
	_confirm = _build_confirm()
	_start_confirm = _build_start_confirm()
	_refresh()
	_start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _start_confirm.visible:
		_close_start_confirm()
	elif _confirm.visible:
		_close_confirm()
	elif _settings_modal.visible:
		_settings.back_out()
	elif _debug.visible:
		_close_debug()
	else:
		return
	get_viewport().set_input_as_handled()


## See UiFocus.
func focus_first() -> bool:
	if _dialogue and _dialogue.is_playing:
		return false
	if _start_confirm.visible:
		_start_no.grab_focus()
	elif _confirm.visible:
		_confirm_no.grab_focus()
	elif _settings_modal.visible:
		_settings.focus_first()
	elif _debug.visible:
		_debug_first.grab_focus()
	else:
		_start.grab_focus()
	return true


func _on_start_pressed() -> void:
	if SaveGame.has_progress():
		_start_confirm.show()
		_start_no.grab_focus()
	else:
		_start_new_run()


func _close_start_confirm() -> void:
	_start_confirm.hide()
	_start.grab_focus()


func _start_new_run() -> void:
	SaveGame.start_new_run()
	# Forget this session's retries too, so first-attempt lines play again.
	PUZZLE_LEVEL._restarts.clear()
	PUZZLE_LEVEL._hint_part.clear()
	PUZZLE_LEVEL._hint_taken_at.clear()
	CHEST.forget_heard()
	SaveGame.play_stage(SaveGame.FIRST_STAGE)


func _refresh() -> void:
	_continue.disabled = not SaveGame.has_last_stage()


func _open_settings() -> void:
	_settings_modal.show()
	_settings.open()


func _close_settings() -> void:
	_settings_modal.hide()
	_settings.hide()
	_settings_button.grab_focus()


func _open_debug() -> void:
	_debug_note.text = ""
	_debug.show()
	_debug_first.grab_focus()


func _close_debug() -> void:
	_debug.hide()
	_debug_button.grab_focus()


func _close_confirm() -> void:
	_confirm.hide()
	_reset_button.grab_focus()


func _unlock_all() -> void:
	SaveGame.unlock_all()
	_debug_note.text = "ALL PROGRESS UNLOCKED"


## Every portrait in a row, in a real dialogue box.
func play_dialogue_test() -> void:
	if not _dialogue:
		_dialogue = DIALOGUE_BOX.instantiate()
		add_child(_dialogue)
	_dialogue.move_to_front()
	_dialogue.play(PackedStringArray(TEST_LINES))


# --- Layout

func _modal() -> Control:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.hide()
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	return modal


func _build_settings() -> Control:
	var modal := _modal()
	_settings = SettingsPanel.new()
	modal.add_child(_settings)
	_settings.build(SETTINGS_SIZE, false)
	_settings.position = ((get_viewport_rect().size - SETTINGS_SIZE) / 2.0).round()
	_settings.back_requested.connect(_close_settings)
	return modal


func _build_debug() -> Control:
	var modal := _modal()
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -DEBUG_SIZE.x / 2.0
	panel.offset_right = DEBUG_SIZE.x / 2.0
	panel.offset_top = -DEBUG_SIZE.y / 2.0
	panel.offset_bottom = DEBUG_SIZE.y / 2.0
	modal.add_child(panel)
	var title := Label.new()
	title.text = "DEBUG"
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(DEBUG_SIZE.x, 10)
	panel.add_child(title)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.position = Vector2(12, 18)
	list.size = Vector2(DEBUG_SIZE.x - 24, 0)
	panel.add_child(list)
	_reset_button = _list_button("RESET PROGRESS", list)
	_reset_button.pressed.connect(func() -> void:
		_debug_note.text = ""
		_confirm.show()
		_confirm_no.grab_focus())
	_debug_first = _reset_button
	_list_button("UNLOCK ALL PROGRESS", list).pressed.connect(_unlock_all)
	_dialogue_button = _list_button("DIALOGUE TEST", list)
	_dialogue_button.pressed.connect(play_dialogue_test)
	_list_button("SANDBOX", list).pressed.connect(SaveGame.play_sandbox)
	_list_button("BACK", list).pressed.connect(_close_debug)
	_debug_note = Label.new()
	_debug_note.add_theme_color_override("font_color", GOLD)
	_debug_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_note.position = Vector2(0, 108)
	_debug_note.size = Vector2(DEBUG_SIZE.x, 10)
	panel.add_child(_debug_note)
	UiFocus.link_column(list.get_children())
	return modal


func _list_button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button


func _build_confirm() -> Control:
	var buttons := _yes_no("RESET ALL PROGRESS
AND SETTINGS?", func() -> void:
		SaveGame.reset_all()
		_confirm.hide()
		_refresh()
		_debug_note.text = "PROGRESS RESET"
		_reset_button.grab_focus(), _close_confirm)
	_confirm_no = buttons.no
	return buttons.modal


func _build_start_confirm() -> Control:
	var buttons := _yes_no("START OVER? THIS ERASES
YOUR PROGRESS.", func() -> void:
		_start_confirm.hide()
		_start_new_run(), _close_start_confirm)
	_start_no = buttons.no
	return buttons.modal


## A question with YES and NO: {modal, no}.
func _yes_no(text: String, on_yes: Callable, on_no: Callable) -> Dictionary:
	var modal := _modal()
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -100
	panel.offset_right = 100
	panel.offset_top = -32
	panel.offset_bottom = 32
	modal.add_child(panel)
	var question := Label.new()
	question.text = text
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.position = Vector2(0, 8)
	question.size = Vector2(200, 20)
	panel.add_child(question)
	var yes := Button.new()
	yes.text = "YES"
	yes.pressed.connect(on_yes)
	panel.add_child(yes)
	# After add_child: a size set before then doesn't stick.
	yes.position = Vector2(36, 38)
	yes.size = Vector2(56, 16)
	var no := Button.new()
	no.text = "NO"
	no.pressed.connect(on_no)
	panel.add_child(no)
	no.position = Vector2(108, 38)
	no.size = Vector2(56, 16)
	UiFocus.link_row([yes, no])
	return {"modal": modal, "no": no}
