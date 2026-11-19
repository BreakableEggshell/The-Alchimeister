extends Control
## A note found in a chest: a potion's recipe on a scrap of paper in the
## middle of the screen, over a dim. By default the Death potion's, whose mix
## cycles through mixes that would brew it, like the notebook's row. Set
## `potion`, `title`, `text` and `fixed_mix` before adding it for another one
## (the ??? potion): a fixed mix stays put. "[TAP TO CLOSE]" comes up after
## CLOSE_AFTER seconds; from then a click or tap anywhere (or Enter, Space or
## the interact key) closes it. Before that, three quick taps (TRIPLE_TAP_TIME)
## close it too. Closing slides it down off the screen as the dim fades. Until
## it's gone, it swallows all other input.
## Runs while the game is paused. Usage: `await note.read()`.

signal closed

const CLOSE_AFTER := 3.0
const PAPER_SIZE := Vector2(200, 160)
## The paper: note.png as a 9-slice, the folded top-left corner (13 px) and
## the edges kept as drawn, only the flat paper stretched.
const PAPER := preload("res://assets/note.png")
const PAPER_MARGINS := [13, 13, 2, 2]
static var _style: StyleBoxTexture
const INK := Color(0.35, 0.22, 0.14)
const DIM := Color(0, 0, 0, 0.6)
## The mix drawn as the notebook's brewing table (crafting_book.gd): its
## slots, the gap between them, the result slot and how far it sits from the
## table, and the arrow between. MIX_TOP: the table's top on the paper.
const SLOT := 22.0
const GAP := 4.0
const RESULT_SIZE := 26.0
const RESULT_GAP := 30.0
const ARROW := preload("res://assets/ui/craft_arrow.png")
const MIX_TOP := 44.0
const CYCLE_TIME := 1.0
const TITLE := "WHEN ALL ELSE FAILS"
const TEXT := ["ANY MIX THAT", "ISN'T A RECIPE"]
const CLOSE_TEXT := "[TAP TO CLOSE]"
## Three taps within this many seconds close it early.
const TRIPLE_TAP_TIME := 0.8
## Seconds the note takes to slide away.
const SLIDE_TIME := 0.35

var can_close := false
var _mix: Array[StringName] = []
var _close_alpha := 0.0
## When the last few taps came (ticks, ms), for closing early.
var _taps: Array[int] = []
## Sliding away: 0 in place, 1 gone below the screen (the dim fades with it).
var _away := 0.0
var _closing := false
## What the note is for (see the top).
var potion := PotionData.DEATH
var title := TITLE
var text: Array = TEXT
## The mix shown, fixed; empty: mixes that brew `potion` cycle (Death's way).
var fixed_mix: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not fixed_mix.is_empty():
		_mix = fixed_mix
		return
	_roll_mix()
	var cycle := Timer.new()
	cycle.wait_time = CYCLE_TIME
	cycle.autostart = true
	cycle.timeout.connect(func() -> void:
		_roll_mix()
		queue_redraw())
	add_child(cycle)


## Shows the note and returns once the player has closed it.
func read() -> void:
	show()
	move_to_front()
	can_close = false
	_close_alpha = 0.0
	_away = 0.0
	_closing = false
	_taps.clear()
	queue_redraw()
	get_tree().create_timer(CLOSE_AFTER, true).timeout.connect(_offer_close)
	await closed


## CLOSE_AFTER is up: "[TAP TO CLOSE]" fades in, and any tap closes it.
func _offer_close() -> void:
	if _closing or not visible:
		return
	can_close = true
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(func(alpha: float) -> void:
		_close_alpha = alpha
		queue_redraw(), 0.0, 1.0, 0.3)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if _closing or not _is_tap(event):
		return
	if can_close:
		_close()
		return
	# Not offered yet: three quick taps close it anyway.
	var now := Time.get_ticks_msec()
	_taps.append(now)
	_taps = _taps.filter(func(at: int) -> bool: return now - at <= TRIPLE_TAP_TIME * 1000.0)
	if _taps.size() >= 3:
		_close()


## A click, a tap, or Enter / Space / the interact key.
func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	# A tap also arrives as a click when touch is turned into the mouse.
	if event is InputEventScreenTouch:
		return event.pressed and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	return event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")


## Slides the note down and away, then it's closed.
func _close() -> void:
	_closing = true
	can_close = false
	var slide := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	slide.tween_method(func(away: float) -> void:
		_away = away
		queue_redraw(), 0.0, 1.0, SLIDE_TIME)
	await slide.finished
	hide()
	closed.emit()


## A random mix that would brew a Death potion: two to four boxes filled.
func _roll_mix() -> void:
	var inventory := get_tree().get_first_node_in_group("inventory") as Inventory if is_inside_tree() else null
	var choices: Array[StringName] = PotionData.INGREDIENTS.duplicate()
	choices.append(&"")
	var mix: Array[StringName] = []
	for attempt in 200:
		mix = []
		for i in 4:
			mix.append(choices.pick_random())
		if mix == _mix or mix.count(&"") > 2:
			continue
		if not inventory or inventory.match_recipe(mix).potion == PotionData.DEATH:
			break
	_mix = mix


static func _paper_style() -> StyleBoxTexture:
	if not _style:
		_style = StyleBoxTexture.new()
		_style.texture = PAPER
		_style.texture_margin_left = PAPER_MARGINS[0]
		_style.texture_margin_top = PAPER_MARGINS[1]
		_style.texture_margin_right = PAPER_MARGINS[2]
		_style.texture_margin_bottom = PAPER_MARGINS[3]
	return _style


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(DIM, DIM.a * (1.0 - clampf(_away, 0.0, 1.0))))
	var font := get_theme_font("font", "Label")
	var paper := Rect2(((size - PAPER_SIZE) / 2.0).round(), PAPER_SIZE)
	# Sliding away: from the middle to just below the bottom edge.
	paper.position.y += _away * (size.y - paper.position.y + 24.0)
	# The scrap of paper: note.png, its folded corner kept whole (9-slice).
	draw_style_box(_paper_style(), paper)
	draw_string(font, paper.position + Vector2(0, 24), title, HORIZONTAL_ALIGNMENT_CENTER, paper.size.x, 8, INK)
	draw_line(paper.position + Vector2(24, 30), paper.position + Vector2(paper.size.x - 24, 30), Color(INK, 0.4))
	# The mix, the arrow and what it brews: the notebook's brewing table (its
	# crafting slots and arrow), centred on the paper.
	var table_size := Vector2(SLOT * 2.0 + GAP, SLOT * 2.0 + GAP)
	var width := table_size.x + RESULT_GAP + RESULT_SIZE
	var table := (paper.position + Vector2((paper.size.x - width) / 2.0, MIX_TOP)).round()
	for i in 4:
		var cell := Rect2(table + Vector2(i % 2, floori(i / 2.0)) * (SLOT + GAP), Vector2(SLOT, SLOT))
		PotionData.draw_slot_box(self, cell)
		if i < _mix.size() and _mix[i] != &"":
			PotionData.draw_ingredient(self, _mix[i], cell.get_center())
	var mid_y := table.y + table_size.y / 2.0
	var result := Rect2(Vector2(table.x + table_size.x + RESULT_GAP, mid_y - RESULT_SIZE / 2.0).round(), Vector2(RESULT_SIZE, RESULT_SIZE))
	var arrow_at := Vector2((table.x + table_size.x + result.position.x) / 2.0, mid_y)
	draw_texture(ARROW, (arrow_at - ARROW.get_size() / 2.0).round())
	PotionData.draw_slot_box(self, result)
	PotionData.draw_potion(self, potion, result.get_center() + Vector2(0, 1))
	for i in text.size():
		draw_string(font, paper.position + Vector2(0, 118 + i * 11), text[i], HORIZONTAL_ALIGNMENT_CENTER, paper.size.x, 8, INK)
	if _close_alpha > 0.0:
		draw_string(font, Vector2(0, paper.end.y + 14), CLOSE_TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(1, 1, 1, _close_alpha))
