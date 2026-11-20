extends Control
## The ending comic, after the ??? potion's ending conversation. It's in pages
## (screens): each page's panels (full-screen pictures, each drawing only its
## own panel) come in one at a time, top to bottom, over BACKGROUND; then the
## page clears for the next. Panels come in by themselves every PANEL_EVERY
## seconds (a full page waits PAGE_HOLD); a tap (a click, Enter, Space, jump
## or interact) brings the next one now, finishing one still coming in first.
## `play()` runs it all; await it. It ends on the last page, for whatever
## covers it next (the -END- black).

## Each page's panels, in the order they come in (top to bottom on screen).
const PAGES: Array = [
	[preload("res://assets/comic/ending/ending_1_2.png"), preload("res://assets/comic/ending/ending_1_1.png")],
	[preload("res://assets/comic/ending/ending_2_1.png"), preload("res://assets/comic/ending/ending_2_2.png")],
	[preload("res://assets/comic/ending/ending_3_1.png"), preload("res://assets/comic/ending/ending_3_2.png")],
	[preload("res://assets/comic/ending/ending_4.png")],
]
## The comic's page colour (the panels' surround).
const BACKGROUND := Color8(46, 34, 47)
const BACKGROUND_IN_TIME := 0.7
## Seconds of empty page before the first panel.
const START_PAUSE := 0.6
## Seconds from one panel to the next, and on a full page before it clears.
const PANEL_EVERY := 2.2
const PAGE_HOLD := 2.6
## The last page stays this long.
const LAST_HOLD := 3.5
## A panel comes in: fades in while settling into place from just above.
const PANEL_IN_TIME := 0.35
const PANEL_DROP := 6.0
## A full page fades away before the next.
const PAGE_OUT_TIME := 0.35
const PAGE_GAP := 0.25

var _bg: ColorRect
var _tween: Tween
var _tapped := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.color = BACKGROUND
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.modulate.a = 0.0
	add_child(_bg)


func play() -> void:
	await _tween_to(_bg, "modulate:a", 1.0, BACKGROUND_IN_TIME)
	await _wait_or_tap(START_PAUSE)
	for p in PAGES.size():
		var page := Control.new()
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(page)
		var panels: Array = PAGES[p]
		for i in panels.size():
			_panel_in(page, panels[i])
			var last_panel: bool = i == panels.size() - 1
			var hold := PANEL_EVERY
			if last_panel:
				hold = LAST_HOLD if p == PAGES.size() - 1 else PAGE_HOLD
			await _wait_or_tap(hold)
		if p < PAGES.size() - 1:
			await _tween_to(page, "modulate:a", 0.0, PAGE_OUT_TIME)
			page.queue_free()
			await _wait_or_tap(PAGE_GAP)


func _panel_in(page: Control, texture: Texture2D) -> void:
	var panel := TextureRect.new()
	panel.texture = texture
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = get_viewport_rect().size
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.position = Vector2(0, -PANEL_DROP)
	panel.modulate.a = 0.0
	page.add_child(panel)
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "modulate:a", 1.0, PANEL_IN_TIME)
	_tween.tween_property(panel, "position", Vector2.ZERO, PANEL_IN_TIME)


func _tween_to(item: Object, property: String, to: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(item, property, to, time)
	await tween.finished


## Waits `seconds` (not while the game's paused), or until a tap. A tap while
## a panel is still coming in only finishes it, and the wait goes on.
func _wait_or_tap(seconds: float) -> void:
	_tapped = false
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		if _tapped:
			_tapped = false
			if _tween and _tween.is_running():
				_tween.custom_step(PANEL_IN_TIME)
			else:
				return
		if not get_tree().paused:
			left -= get_process_delta_time()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_tapped = true
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		_tapped = true
		get_viewport().set_input_as_handled()
