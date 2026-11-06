extends Control
## Start menu. START opens level select, CONTINUE drops you back into the
## stage you were last in, RESET wipes the save (after asking), EXIT quits.

@onready var _start: Button = %StartButton
@onready var _continue: Button = %ContinueButton
@onready var _reset: Button = %ResetButton
@onready var _exit: Button = %ExitButton

var _confirm: Control


func _ready() -> void:
	_start.pressed.connect(SaveGame.go_to.bind(SaveGame.LEVEL_SELECT))
	_continue.pressed.connect(func() -> void: SaveGame.play_stage(SaveGame.last_stage))
	_reset.pressed.connect(func() -> void: _confirm.show())
	_exit.pressed.connect(get_tree().quit)
	for button in [_start, _continue, _reset, _exit]:
		button.mouse_entered.connect(button.grab_focus)
	_confirm = _build_confirm()
	_refresh()
	_start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm.visible and event.is_action_pressed("ui_cancel"):
		_confirm.hide()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_continue.disabled = not SaveGame.has_last_stage()


func _build_confirm() -> Control:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.hide()
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -100
	panel.offset_right = 100
	panel.offset_top = -32
	panel.offset_bottom = 32
	modal.add_child(panel)
	var question := Label.new()
	question.text = "RESET ALL PROGRESS\nAND SETTINGS?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.position = Vector2(0, 8)
	question.size = Vector2(200, 20)
	panel.add_child(question)
	var yes := Button.new()
	yes.text = "YES"
	yes.position = Vector2(36, 38)
	yes.size = Vector2(56, 16)
	yes.pressed.connect(func() -> void:
		SaveGame.reset_all()
		modal.hide()
		_refresh()
		_start.grab_focus())
	panel.add_child(yes)
	var no := Button.new()
	no.text = "NO"
	no.position = Vector2(108, 38)
	no.size = Vector2(56, 16)
	no.pressed.connect(func() -> void:
		modal.hide()
		_reset.grab_focus())
	panel.add_child(no)
	return modal
