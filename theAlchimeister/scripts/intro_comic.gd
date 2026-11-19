extends Control
## The intro comic, after START and before the first level. Its panels (full
## screen pictures, each drawing only its own panel) come in one at a time over
## black: after a moment of black, then every PANEL_EVERY seconds by
## themselves. A tap (a click, a tap, Enter, Space or the interact key) brings
## the next one in straight away (finishing one still coming in first), and
## the count starts over from there. Once the last one is in, CONTINUE fades in
## (bottom right; a tap brings it sooner); it goes on to the level.

const PANELS: Array[Texture2D] = [
	preload("res://assets/comic/1-1.png"),
	preload("res://assets/comic/1-2.png"),
	preload("res://assets/comic/1-3.png"),
	preload("res://assets/comic/1-4.png"),
]
## The same black as the iris, so the screen it opens from and closes to matches.
const BACKGROUND := Color.BLACK
## Sounds as panels come in: panel number (from 1) -> sound.
const PANEL_SOUNDS := {1: Sfx.AUDIENCE_CHATTER}
## Those sounds fade out gradually: starting this many seconds in, over this
## long (the chatter is 3.5 s), down to SOUND_FADE_DB, evenly in dB so it
## sounds steady all the way down rather than holding and then dropping.
## Leaving the comic early fades them out with the picture (OUT_TIME).
const SOUND_FADE_FROM := 0.8
const SOUND_FADE_TIME := 2.7
const SOUND_FADE_DB := -40.0
## Seconds of black before the first panel comes in.
const START_PAUSE := 0.9
## Seconds from one panel coming in to the next, if nothing is tapped.
const PANEL_EVERY := 3.0
## A panel comes in: fades in while settling into place from just above
## (PANEL_DROP), or from wherever PANEL_FROM says (panel number -> offset).
const PANEL_IN_TIME := 0.35
const PANEL_DROP := 6.0
## The wanted poster sweeps in from the right.
const PANEL_FROM := {4: Vector2(48, 0)}
const SLIDE_IN_TIME := 0.6
## After the last panel: a moment, then CONTINUE fades in.
const CONTINUE_AFTER := 1.35
const CONTINUE_FADE_TIME := 0.5
## CONTINUE sits this far in from the bottom-right corner.
const MARGIN := 8.0
const CONTINUE_SIZE := Vector2(72, 16)
## Seconds to fade to black before the level.
const OUT_TIME := 0.4

var _panels: Array[TextureRect] = []
## How many panels are showing.
var _shown := 0
var _tween: Tween
## Seconds until the next panel (or CONTINUE) comes in by itself.
var _wait := START_PAUSE
var _continue: Button
var _leaving := false
## Panel sounds still playing -> their fade.
var _sound_fades := {}


func _ready() -> void:
	add_to_group(UiFocus.SCREENS)
	Music.play(Music.OPENING)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var screen := get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = BACKGROUND
	bg.size = screen
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for texture in PANELS:
		var panel := TextureRect.new()
		panel.texture = texture
		panel.size = screen
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.modulate.a = 0.0
		add_child(panel)
		_panels.append(panel)
	_continue = Button.new()
	_continue.text = "CONTINUE"
	_continue.focus_mode = Control.FOCUS_ALL
	_continue.pressed.connect(_finish)
	_continue.mouse_entered.connect(_continue.grab_focus)
	add_child(_continue)
	# Its real size (the theme's button can be taller than asked).
	_continue.size = CONTINUE_SIZE.max(_continue.get_combined_minimum_size())
	_continue.position = screen - Vector2(MARGIN, MARGIN) - _continue.size
	_continue.modulate.a = 0.0
	_continue.hide()


func _process(delta: float) -> void:
	if _continue.visible or _leaving:
		return
	_wait -= delta
	if _wait <= 0.0:
		_advance()


## See UiFocus: the keys land on CONTINUE once it's there.
func focus_first() -> bool:
	if not _continue.visible:
		return false
	_continue.grab_focus()
	return true


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_tap()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _continue.visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		_tap()
		get_viewport().set_input_as_handled()


## The player moves it on: a panel still coming in finishes; otherwise the
## next panel (or CONTINUE) comes in now.
func _tap() -> void:
	if _continue.visible or _leaving:
		return
	if _tween and _tween.is_running():
		_tween.custom_step(SLIDE_IN_TIME)
		return
	_advance()


## The next panel, or CONTINUE after the last one.
func _advance() -> void:
	if _shown < _panels.size():
		_next()
		_wait = PANEL_EVERY if _shown < _panels.size() else CONTINUE_AFTER
	else:
		_show_continue()


func _next() -> void:
	var panel := _panels[_shown]
	_shown += 1
	var sound: AudioStream = PANEL_SOUNDS.get(_shown)
	if sound:
		_fade_out(Sfx.play(sound, self))
	panel.position = PANEL_FROM.get(_shown, Vector2(0, -PANEL_DROP))
	var time: float = SLIDE_IN_TIME if PANEL_FROM.has(_shown) else PANEL_IN_TIME
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "modulate:a", 1.0, time)
	_tween.tween_property(panel, "position", Vector2.ZERO, time)


## Turns `player` down smoothly over its last seconds (see SOUND_FADE_FROM).
func _fade_out(player: Node) -> void:
	if not player:
		return
	var fade := player.create_tween()
	fade.tween_interval(SOUND_FADE_FROM)
	fade.tween_property(player, "volume_db", SOUND_FADE_DB, SOUND_FADE_TIME)
	fade.tween_property(player, "volume_db", -80.0, 0.1)
	_sound_fades[player] = fade
	player.tree_exited.connect(func() -> void: _sound_fades.erase(player))


## Leaving: whatever's still playing fades out with the picture.
func _fade_sounds_now(time: float) -> void:
	for player: Node in _sound_fades:
		if not is_instance_valid(player):
			continue
		_sound_fades[player].kill()
		player.create_tween().tween_property(player, "volume_db", -80.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _show_continue() -> void:
	_continue.show()
	_continue.grab_focus()
	create_tween().tween_property(_continue, "modulate:a", 1.0, CONTINUE_FADE_TIME)


## To the first level: the comic fades to black, and the level opens with its
## own iris.
func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = get_viewport_rect().size
	black.modulate.a = 0.0
	add_child(black)
	_fade_sounds_now(OUT_TIME)
	Music.stop(OUT_TIME)
	var fade := create_tween()
	fade.tween_property(black, "modulate:a", 1.0, OUT_TIME)
	await fade.finished
	get_tree().change_scene_to_file(SaveGame.STAGE_SCENES[SaveGame.FIRST_STAGE])
