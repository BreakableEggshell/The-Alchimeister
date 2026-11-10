extends Control
## A note found in a chest: the Death potion's recipe on a scrap of paper in
## the middle of the screen, over a dim. Its mix cycles through mixes that
## would brew it, like the notebook's row. "[TAP TO CLOSE]" comes up after
## CLOSE_AFTER seconds; from then a click or tap anywhere (or Enter, Space or
## the interact key) closes it. Until it closes, it swallows all other input.
## Runs while the game is paused. Usage: `await note.read()`.

signal closed

const CLOSE_AFTER := 3.0
const PAPER_SIZE := Vector2(240, 124)
const PAPER := Color(0.92, 0.86, 0.7)
const PAPER_EDGE := Color(0.7, 0.6, 0.44)
const INK := Color(0.35, 0.22, 0.14)
const DIM := Color(0, 0, 0, 0.6)
const CELL := 16.0
const CYCLE_TIME := 1.0
const TITLE := "WHEN ALL ELSE FAILS, USE ON SELF"
const TEXT := ["ANY MIX THAT", "ISN'T A RECIPE"]
const CLOSE_TEXT := "[TAP TO CLOSE]"

var can_close := false
var _mix: Array[StringName] = []
var _close_alpha := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	queue_redraw()
	await get_tree().create_timer(CLOSE_AFTER, true).timeout
	can_close = true
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(func(alpha: float) -> void:
		_close_alpha = alpha
		queue_redraw(), 0.0, 1.0, 0.3)
	await closed


func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if not can_close:
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touched: bool = event is InputEventScreenTouch and event.pressed
	if clicked or touched or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIM)
	var font := get_theme_font("font", "Label")
	var paper := Rect2(((size - PAPER_SIZE) / 2.0).round(), PAPER_SIZE)
	# A scrap of paper: an edge, and a folded-down corner.
	draw_rect(paper.grow(1.0), PAPER_EDGE)
	draw_rect(paper, PAPER)
	var corner := paper.position + Vector2(paper.size.x, 0)
	draw_colored_polygon(PackedVector2Array([corner, corner + Vector2(-12, 0), corner + Vector2(0, 12)]), PAPER_EDGE)
	draw_colored_polygon(PackedVector2Array([corner + Vector2(-12, 0), corner + Vector2(-12, 12), corner + Vector2(0, 12)]), PAPER.darkened(0.12))
	draw_string(font, paper.position + Vector2(0, 18), TITLE, HORIZONTAL_ALIGNMENT_CENTER, paper.size.x, 8, INK)
	draw_line(paper.position + Vector2(20, 24), paper.position + Vector2(paper.size.x - 20, 24), Color(INK, 0.4))
	# The mix, an arrow, and what it brews.
	var table := paper.position + Vector2(36, 34)
	for i in 4:
		var cell := Rect2(table + Vector2(i % 2, floori(i / 2.0)) * (CELL + 1.0), Vector2(CELL, CELL))
		draw_rect(cell, IngredientSlot.FILL)
		if i < _mix.size() and _mix[i] != &"":
			PotionData.draw_ingredient(self, _mix[i], cell.get_center())
	var mid_y := table.y + CELL + 0.5
	var from_x := table.x + CELL * 2.0 + 8.0
	draw_line(Vector2(from_x, mid_y), Vector2(from_x + 22.0, mid_y), INK, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(from_x + 25.0, mid_y), Vector2(from_x + 20.0, mid_y - 4), Vector2(from_x + 20.0, mid_y + 4)]), INK)
	var result := Rect2(from_x + 32.0, mid_y - 12.0, 24.0, 24.0)
	draw_rect(result, IngredientSlot.FILL)
	PotionData.draw_potion(self, PotionData.DEATH, result.get_center() + Vector2(0, 1))
	for i in TEXT.size():
		draw_string(font, paper.position + Vector2(0, 92 + i * 11), TEXT[i], HORIZONTAL_ALIGNMENT_CENTER, paper.size.x, 8, INK)
	if _close_alpha > 0.0:
		draw_string(font, Vector2(0, paper.end.y + 14), CLOSE_TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(1, 1, 1, _close_alpha))
