class_name SettingsPanel
extends Panel
## The settings page, shared by the notebook and the start menu: music and
## sound volume, fullscreen, the CONTROLS page, and optionally SELECT LEVEL.

## The player asked to leave (BACK).
signal back_requested

const PAGE_COLOR := Color(0.94, 0.88, 0.74)
const COVER_COLOR := Color(0.42, 0.2, 0.14)
const INK := Color(0.35, 0.22, 0.14)
const ACTIVE_INK := Color(0.75, 0.25, 0.2)
const BUTTONS_Y := 148.0

var first_setting: Control
var controls: Panel
var controls_button: Button
var select_level_button: Button


func build(panel_size: Vector2, with_select_level: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PAGE_COLOR
	style.border_color = COVER_COLOR
	style.set_border_width_all(5)
	add_theme_stylebox_override("panel", style)
	size = panel_size
	hide()
	var title := _ink_label("SETTINGS", Vector2(0, 14), panel_size.x)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rows := [["MUSIC", SaveGame.music_volume, SaveGame.set_music_volume], ["SOUND", SaveGame.sound_volume, SaveGame.set_sound_volume]]
	for i in rows.size():
		var y := 46.0 + i * 30.0
		var label := _ink_label(rows[i][0], Vector2(70, y), 60)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = rows[i][1]
		slider.focus_mode = Control.FOCUS_ALL
		# Sliders have no focus ring, so the label lights up instead.
		slider.focus_entered.connect(label.add_theme_color_override.bind("font_color", ACTIVE_INK))
		slider.focus_exited.connect(label.add_theme_color_override.bind("font_color", INK))
		if not first_setting:
			first_setting = slider
		slider.position = Vector2(140, y - 2)
		slider.size = Vector2(150, 14)
		slider.value_changed.connect(rows[i][2])
		add_child(slider)
	var fullscreen := CheckBox.new()
	fullscreen.text = "FULLSCREEN"
	fullscreen.button_pressed = SaveGame.fullscreen
	fullscreen.focus_mode = Control.FOCUS_ALL
	fullscreen.add_theme_color_override("font_focus_color", ACTIVE_INK)
	fullscreen.add_theme_color_override("font_color", INK)
	fullscreen.add_theme_color_override("font_hover_color", INK)
	fullscreen.add_theme_color_override("font_pressed_color", INK)
	fullscreen.add_theme_color_override("font_hover_pressed_color", INK)
	# Plain text on the page, not the dark HUD button box.
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		fullscreen.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	fullscreen.position = Vector2(66, 104)
	fullscreen.toggled.connect(SaveGame.set_fullscreen)
	add_child(fullscreen)
	# The editor's Game tab ignores window mode changes, so say why it can't work.
	if Engine.is_embedded_in_editor():
		fullscreen.disabled = true
		fullscreen.add_theme_color_override("font_disabled_color", Color(INK, 0.45))
		var note := _ink_label("(NOT IN THE EDITOR'S GAME TAB)", Vector2(70, 124), 240)
		note.add_theme_color_override("font_color", Color(INK, 0.6))
	var sliders: Array[Control] = []
	for child in get_children():
		if child is HSlider:
			sliders.append(child)
	var row := HBoxContainer.new()
	add_child(row)
	if with_select_level:
		select_level_button = _button("SELECT LEVEL", row)
		select_level_button.pressed.connect(SaveGame.go_to.bind(SaveGame.LEVEL_SELECT))
	controls_button = _button("CONTROLS", row)
	controls_button.pressed.connect(open_controls)
	var back := _button("BACK", row)
	back.pressed.connect(back_requested.emit)
	row.reset_size()
	row.position = Vector2(roundf((panel_size.x - row.size.x) / 2.0), BUTTONS_Y)
	controls = preload("res://scripts/puzzle/controls_page.gd").new()
	add_child(controls)
	controls.build(panel_size, style)
	controls.back_requested.connect(close_controls)
	visibility_changed.connect(func() -> void:
		if not visible:
			controls.hide())
	_link_keys(sliders, fullscreen, row.get_children())


## Top to bottom: sliders, fullscreen, the row of buttons (wrapping round).
## Left and right stay on the page; on a slider they change its value.
func _link_keys(sliders: Array[Control], fullscreen: Control, buttons: Array) -> void:
	var column: Array = []
	column.append_array(sliders)
	column.append(fullscreen)
	column.append(buttons[0])
	UiFocus.link_column(column)
	UiFocus.link_row(buttons)
	for button: Control in buttons:
		button.focus_neighbor_top = fullscreen.get_path()
		button.focus_neighbor_bottom = column[0].get_path()
	fullscreen.focus_neighbor_bottom = buttons[0].get_path()
	column[0].focus_neighbor_top = buttons[0].get_path()
	fullscreen.focus_next = buttons[0].get_path()
	var last: Control = buttons[buttons.size() - 1]
	last.focus_next = column[0].get_path()
	column[0].focus_previous = last.get_path()
	buttons[0].focus_previous = fullscreen.get_path()


func open() -> void:
	show()
	first_setting.grab_focus()


func open_controls() -> void:
	controls.show()
	controls.focus_first()


func close_controls() -> void:
	controls.hide()
	controls_button.grab_focus()


## Keyboard focus on the first thing on whichever page is showing.
func focus_first() -> void:
	if controls.visible:
		controls.focus_first()
	else:
		first_setting.grab_focus()


## One step back on Esc: CONTROLS to settings, settings to whoever opened it.
func back_out() -> void:
	if controls.visible:
		close_controls()
	else:
		back_requested.emit()


func _button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = " %s " % text
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button


func _ink_label(text: String, at: Vector2, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", INK)
	add_child(label)
	label.position = at
	label.size = Vector2(width, 10)
	return label
