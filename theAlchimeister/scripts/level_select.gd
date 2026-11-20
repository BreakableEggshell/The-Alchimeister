extends Control
## Level select: pages for the SaveGame maps it shows (the first always; the
## others as the debug menu here says, see SaveGame.shown_maps), side by side,
## one per map, except the first map, spread over several (PLAYABLE_PAGES),
## with one node per stage, numbered as SaveGame.stage_tag says ("5", "P2").
## One page shows at a time; the arrows at the screen's edges, PgUp / PgDn,
## or left / right past a page's last column slide to the next. The special
## pages (SPECIAL, PROTOTYPES) have their name under the title.
## Nodes wind across their map in rows (at most MAX_ROWS), placed from however
## many stages it has. Clicking an unlocked node plays that stage; locked ones
## are dimmed with a padlock and can't be picked. A map with nothing unlocked
## says COMING SOON. Behind each page, its picture with drifting clouds
## (MapBackground; the later maps use map1's picture for now).
## Typing the DebugCode (wwssadad) here, or tapping the title 5 times, opens a
## small debug menu that turns the later pages on and off.

const NODE_TEXTURE := preload("res://assets/map1_levelnode.png")
const MAP1 := preload("res://assets/map1.png")
## The first map's pages: how many of its stages each holds, in order, and its
## picture. The last page takes whatever stages are left (up to the Demon
## Lord, at his throne). `extra`: stages from other maps shown there too,
## after its own (and not on their own map's page).
const PLAYABLE_PAGES: Array[Dictionary] = [
	{"stages": 3, "picture": MAP1},
	{"stages": 5, "picture": preload("res://assets/map2_1.png")},
	{"stages": -1, "picture": preload("res://assets/map2_2.png")},
]
const GOLD := Color(0.95, 0.85, 0.55)
## A picked node blinks this many times, over this long, before the iris.
const PICK_BLINKS := 3
const PICK_BLINK_TIME := 0.45
## Seconds the map takes to slide in after CONTINUE.
const SLIDE_IN_TIME := 0.45
## Seconds to slide from one map to the next.
const PAGE_SLIDE_TIME := 0.4
const TEXT_OUTLINE := Color(0.08, 0.1, 0.06)
const LOCKED_TINT := Color(0.55, 0.55, 0.55)
## A node's button: the art with its number below it.
const NODE_SIZE := Vector2(30, 26)
const NUMBER_BASELINE := 24.0
## Nodes per row: at least this many, more once MAX_ROWS rows would be full.
const MIN_PER_ROW := 6
const MAX_ROWS := 3
## The area of the map the nodes spread across (their centres): the grass,
## below the tree line.
const MAP_AREA := Rect2(44, 100, 296, 76)
## Every other node sits this far up or down, so a row isn't a straight line.
const WOBBLE := 10.0
## The arrows that slide to the next map.
const ARROW_SIZE := Vector2(18, 24)
## The debug menu's panel.
const DEBUG_SIZE := Vector2(196, 110)

## Every node, in play order.
var _nodes: Array[Button] = []
## Stage -> its node, for the pages on show.
var _node_of := {}
## Each page's nodes, in play order.
var _map_nodes: Array = []
## Which SaveGame map each page is from.
var _page_maps: Array[int] = []
## Everything built from the maps (rebuilt when the debug menu changes them).
var _screen: Control
## The pages, side by side; sliding this shows one or another.
var _maps: Control
## The page on show.
var _map := 0
var _map_tween: Tween
var _previous_map: Button
var _next_map: Button
var _back: Button
## A level has been picked, or BACK pressed: nothing else can be until the
## screen has changed.
var _picked := false
var _code := DebugCode.new()
## The SELECT LEVEL title, and the taps on it so far (see _title_tapped).
var _title: Label
var _title_taps := 0
var _title_tapped_at := -10.0
const TITLE_TAPS := 5
const TITLE_TAP_GAP := 1.0
var _debug: Control
## The debug menu's toggles: map -> its button.
var _debug_toggles := {}


func _ready() -> void:
	add_to_group(UiFocus.SCREENS)
	# The main menu's music carries on here.
	Music.play(Music.MAIN_MENU)
	_build()
	_debug = _build_debug()
	if SaveGame.slide_in_level_select:
		SaveGame.slide_in_level_select = false
		_slide_in()
	_open_on(_starting_node())
	# Arriving from a level's pause menu: its iris closed, so open it.
	if Iris.is_closed:
		Iris.cover()
		await get_tree().process_frame
		if is_inside_tree():
			Iris.open()


## Straight to the page `node` is on, without sliding there, picking it.
func _open_on(node: Button) -> void:
	_show_map(node.get_meta("map"), false, true)
	node.grab_focus()


## Where the screen opens: the level last played, if it can still be picked,
## else the furthest one reached on the first map.
func _starting_node() -> Button:
	var last: Button = _node_of.get(SaveGame.last_stage)
	if last and not last.disabled:
		return last
	var stages := SaveGame.map_stages(SaveGame.PLAYABLE_MAP)
	for i in range(stages.size() - 1, -1, -1):
		var node: Button = _node_of.get(stages[i])
		if node and not node.disabled:
			return node
	return _nodes[0]


func _input(event: InputEvent) -> void:
	if (_code.feed(event) or _title_tapped(event)) and not _picked and not _debug.visible:
		_open_debug()
		get_viewport().set_input_as_handled()


## Phones have no keys: tapping the SELECT LEVEL title TITLE_TAPS times in a
## row (each within TITLE_TAP_GAP seconds of the last) opens the debug menu
## too. A click does the same on a PC.
func _title_tapped(event: InputEvent) -> bool:
	var press := event as InputEventMouseButton
	if not press or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return false
	var font := _title.get_theme_font("font")
	var width := font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _title.get_theme_font_size("font_size")).x
	var words := Rect2(_title.get_global_rect().get_center() - Vector2(width / 2.0, _title.size.y / 2.0), Vector2(width, _title.size.y)).grow(3.0)
	var now := Time.get_ticks_msec() / 1000.0
	if not words.has_point(press.position) or now - _title_tapped_at > TITLE_TAP_GAP:
		_title_taps = 0
	_title_tapped_at = now
	if not words.has_point(press.position):
		return false
	_title_taps += 1
	if _title_taps < TITLE_TAPS:
		return false
	_title_taps = 0
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _debug.visible:
			_close_debug()
		else:
			_back_to_menu()
		get_viewport().set_input_as_handled()
	elif _debug.visible or _picked:
		return
	# Like the notebook's pages: PgDn / PgUp slide to the next / previous map.
	elif event.is_action_pressed("ui_page_down") and _map + 1 < _map_nodes.size():
		_show_map(_map + 1, true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_up") and _map > 0:
		_show_map(_map - 1, true)
		get_viewport().set_input_as_handled()


## A level was picked: its node blinks, then the iris closes on it and the
## level opens.
func _pick(node: Button, stage: String) -> void:
	if _picked:
		return
	_picked = true
	var blink := create_tween()
	for i in PICK_BLINKS:
		blink.tween_property(node, "modulate:a", 0.15, PICK_BLINK_TIME / PICK_BLINKS / 2.0)
		blink.tween_property(node, "modulate:a", 1.0, PICK_BLINK_TIME / PICK_BLINKS / 2.0)
	await blink.finished
	SaveGame.play_stage(stage, node.get_global_transform_with_canvas().origin + NODE_SIZE / 2.0)


## Arriving from the start menu's black screen: the whole map slides in from
## the right, pushing the black off to the left.
func _slide_in() -> void:
	var width := get_viewport_rect().size.x
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = get_viewport_rect().size
	black.position.x = -width
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	position.x = width
	var slide := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(self, "position:x", 0.0, SLIDE_IN_TIME)
	slide.tween_callback(black.queue_free)


## BACK: the way in, backwards. The whole map slides off to the right, pulling
## a black screen in from the left, and the start menu carries on from there.
func _back_to_menu() -> void:
	if _picked:
		return
	_picked = true
	var width := get_viewport_rect().size.x
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = get_viewport_rect().size
	black.position.x = -width
	add_child(black)
	var slide := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	slide.tween_property(self, "position:x", width, SLIDE_IN_TIME)
	await slide.finished
	SaveGame.slide_in_start_menu = true
	SaveGame.go_to(SaveGame.START_MENU)


## See UiFocus: the first node (node 1 is always unlocked), or the debug
## menu's first toggle while it's open.
func focus_first() -> bool:
	if _debug.visible:
		_debug_toggles.values()[0].grab_focus()
		return true
	_show_map(0)
	_nodes[0].grab_focus()
	return true


## Slides to `map` (or jumps there, with `instant`). With `take_focus`, the
## keys land on its first open node, or, with none to pick, on the arrow that
## leads back.
func _show_map(map: int, take_focus := false, instant := false) -> void:
	map = clampi(map, 0, _map_nodes.size() - 1)
	var came_from := _map
	_map = map
	_previous_map.visible = map > 0
	_next_map.visible = map + 1 < _map_nodes.size()
	if _map_tween:
		_map_tween.kill()
	var x := -map * get_viewport_rect().size.x
	if instant:
		_maps.position.x = x
	else:
		_map_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_map_tween.tween_property(_maps, "position:x", x, PAGE_SLIDE_TIME)
	if not take_focus:
		return
	for node: Button in _map_nodes[map]:
		if not node.disabled:
			node.grab_focus()
			return
	(_previous_map if map > came_from else _next_map).grab_focus()


## An arrow was pressed: on to the next map that way. The selection stays on
## that arrow if there's still a map further that way, else it moves to the
## other arrow (the only one left).
func _turn_page(step: int) -> void:
	_show_map(_map + step)
	var same := _next_map if step > 0 else _previous_map
	var other := _previous_map if step > 0 else _next_map
	(same if same.visible else other).grab_focus()


## How many nodes go in a row for `count` stages: MIN_PER_ROW, or more if
## MAX_ROWS rows of that wouldn't fit them all; fewer stages than that are one
## row, spread across the map.
static func per_row(count: int) -> int:
	return clampi(count, 1, maxi(MIN_PER_ROW, ceili(float(count) / MAX_ROWS)))


## Where node `index` of the `count` on a map goes: rows that snake left to
## right, then right to left, so each number is next to the one before it.
static func node_center(index: int, count: int) -> Vector2:
	var across := per_row(count)
	var rows := ceili(float(count) / across)
	var row := index / across
	var column := _column_of(index, across)
	var x := MAP_AREA.position.x + (MAP_AREA.size.x * column / (across - 1) if across > 1 else MAP_AREA.size.x / 2.0)
	var y := MAP_AREA.position.y + (MAP_AREA.size.y * row / (rows - 1) if rows > 1 else MAP_AREA.size.y / 2.0)
	return Vector2(x, y + (WOBBLE if column % 2 == 1 else -WOBBLE))


## Which column node `index` is in, counting from the left of the map, with
## `across` nodes to a row.
static func _column_of(index: int, across: int) -> int:
	var column := index % across
	return across - 1 - column if (index / across) % 2 == 1 else column


# --- Layout

func _build() -> void:
	var screen := get_viewport_rect().size
	_screen = Control.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	# Follows the window, so what's pinned to its edges (BACK) stays on screen.
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_maps = Control.new()
	_maps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_maps)
	for map in SaveGame.MAP_COUNT:
		if not SaveGame.is_map_shown(map):
			continue
		var stages := SaveGame.map_stages(map)
		if map != SaveGame.PLAYABLE_MAP:
			# Less any already shown on a page of the first map.
			var left: Array[String] = []
			left.assign(stages.filter(func(stage: String) -> bool: return not _node_of.has(stage)))
			_build_page(map, left, MAP1)
			continue
		for part in PLAYABLE_PAGES:
			var count: int = part.stages if part.stages >= 0 else stages.size()
			var shown := stages.slice(0, count)
			shown.append_array(part.get("extra", []))
			_build_page(map, shown, part.picture)
			stages = stages.slice(count)

	_title = _outlined_label("SELECT LEVEL", 16, 12.0)
	_screen.add_child(_title)

	_previous_map = _arrow("<", 4.0)
	_previous_map.pressed.connect(_turn_page.bind(-1))
	_next_map = _arrow(">", screen.x - ARROW_SIZE.x - 4.0)
	_next_map.pressed.connect(_turn_page.bind(1))

	_back = Button.new()
	_back.text = "BACK"
	_back.pressed.connect(_back_to_menu)
	_screen.add_child(_back)
	# Its real size (the theme's button can be taller than asked), pinned 8 px
	# in from the bottom-left corner, so it stays on screen however the window
	# is sized, now or later.
	_back.size = Vector2(56, 16).max(_back.get_combined_minimum_size())
	_back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, 8)
	_link_keys()
	_show_map(0, false, true)


## A page of the level select: `stages` (from SaveGame map `map`) over
## `picture`, after the pages built so far.
func _build_page(map: int, stages: Array[String], picture: Texture2D) -> void:
	var screen := get_viewport_rect().size
	var page_index := _page_maps.size()
	_page_maps.append(map)
	var page := Control.new()
	page.position = Vector2(page_index * screen.x, 0)
	page.size = screen
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_maps.add_child(page)
	var sky := MapBackground.new()
	sky.picture = picture
	# The darkness on the later pictures hides the clouds.
	sky.sky_only = picture != MAP1
	page.add_child(sky)
	var nodes: Array[Button] = []
	for i in stages.size():
		var node := _level_node(stages[i], page_index)
		page.add_child(node)
		node.size = NODE_SIZE
		node.position = (node_center(i, stages.size()) - NODE_SIZE / 2.0).round()
		nodes.append(node)
		_nodes.append(node)
		_node_of[stages[i]] = node
	_map_nodes.append(nodes)
	if SaveGame.MAP_PREFIX.has(map):
		page.add_child(_outlined_label(SaveGame.MAP_NAMES[map], 8, 32.0))
	# The first map's later pages are just the levels not reached yet.
	if map != SaveGame.PLAYABLE_MAP and nodes.all(func(node: Button) -> bool: return node.disabled):
		page.add_child(_outlined_label("COMING SOON", 8, 36.0))


## The debug menu changed which maps show: everything built again, with the
## same level picked if it's still there.
func _rebuild() -> void:
	var picked := ""
	for stage in _node_of:
		if _node_of[stage].has_focus():
			picked = stage
	if _map_tween:
		_map_tween.kill()
	_screen.free()
	_nodes.clear()
	_node_of.clear()
	_map_nodes.clear()
	_page_maps.clear()
	_map = 0
	_build()
	_debug.move_to_front()
	var node: Button = _node_of.get(picked)
	_show_map(node.get_meta("map") if node else 0, false, true)


## The debug menu: a toggle for each map after the first, and BACK.
func _build_debug() -> Control:
	var modal := Control.new()
	modal.size = get_viewport_rect().size
	modal.hide()
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = modal.size
	modal.add_child(dim)
	var panel := Panel.new()
	panel.size = DEBUG_SIZE
	panel.position = ((modal.size - DEBUG_SIZE) / 2.0).round()
	modal.add_child(panel)
	var title := Label.new()
	title.text = "SHOW LEVELS"
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(DEBUG_SIZE.x, 10)
	panel.add_child(title)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.position = Vector2(12, 20)
	list.size = Vector2(DEBUG_SIZE.x - 24, 0)
	panel.add_child(list)
	for map in range(1, SaveGame.MAP_COUNT):
		var toggle := Button.new()
		toggle.focus_mode = Control.FOCUS_ALL
		toggle.pressed.connect(func() -> void:
			SaveGame.set_map_shown(map, not SaveGame.is_map_shown(map))
			_label_debug()
			_rebuild())
		toggle.mouse_entered.connect(toggle.grab_focus)
		list.add_child(toggle)
		_debug_toggles[map] = toggle
	var back := Button.new()
	back.text = "BACK"
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(_close_debug)
	back.mouse_entered.connect(back.grab_focus)
	list.add_child(back)
	UiFocus.link_column(list.get_children())
	_label_debug()
	return modal


func _label_debug() -> void:
	for map in _debug_toggles:
		_debug_toggles[map].text = "%s: %s" % [SaveGame.MAP_NAMES[map], "ON" if SaveGame.is_map_shown(map) else "OFF"]


func _open_debug() -> void:
	_label_debug()
	_debug.move_to_front()
	_debug.show()
	_debug_toggles.values()[0].grab_focus()


func _close_debug() -> void:
	_debug.hide()
	var shown: Array = _map_nodes[_map]
	for node: Button in shown:
		if not node.disabled:
			node.grab_focus()
			return
	_back.grab_focus()


## Gold text with a dark outline, centred across the screen at `top`.
func _outlined_label(text: String, font_size: int, top: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, top)
	label.size = Vector2(get_viewport_rect().size.x, font_size + 2.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## An arrow at the side of the screen, halfway down the grass.
func _arrow(text: String, x: float) -> Button:
	var arrow := Button.new()
	arrow.text = text
	arrow.focus_mode = Control.FOCUS_ALL
	arrow.mouse_entered.connect(arrow.grab_focus)
	_screen.add_child(arrow)
	arrow.position = Vector2(x, roundf(MAP_AREA.get_center().y - ARROW_SIZE.y / 2.0))
	arrow.size = ARROW_SIZE
	return arrow


## WASD moves along a node's row and column on its map (the automatic guess
## can pick the wrong node on a winding layout). Locked nodes are skipped. Off
## the side of a map goes to the arrow there, and on to the next map; down
## from the bottom goes to BACK.
func _link_keys() -> void:
	for map in _map_nodes.size():
		var nodes: Array = _map_nodes[map]
		var across := per_row(nodes.size())
		for i in nodes.size():
			var node: Button = nodes[i]
			if node.disabled:
				continue
			var row := i / across
			var column := _column_of(i, across)
			var left := _previous_map.get_path() if map > 0 else node.get_path()
			var right := _next_map.get_path() if map + 1 < _map_nodes.size() else node.get_path()
			node.focus_neighbor_left = _open_node_path(nodes, row, column - 1, left)
			node.focus_neighbor_right = _open_node_path(nodes, row, column + 1, right)
			node.focus_neighbor_top = _open_node_path(nodes, row - 1, column, node.get_path())
			node.focus_neighbor_bottom = _open_node_path(nodes, row + 1, column, _back.get_path())
	_back.focus_neighbor_right = _next_map.get_path()
	for arrow in [_previous_map, _next_map]:
		arrow.focus_neighbor_bottom = _back.get_path()
		arrow.focus_neighbor_top = arrow.get_path()
	# Between the arrows: across the map on show, by its nearest open node.
	_previous_map.focus_neighbor_left = _previous_map.get_path()
	_next_map.focus_neighbor_right = _next_map.get_path()
	_previous_map.focus_neighbor_right = NodePath()
	_next_map.focus_neighbor_left = NodePath()
	_back.focus_neighbor_top = NodePath()


## The path of the unlocked node at that spot on a map, else `otherwise`.
func _open_node_path(nodes: Array, row: int, column: int, otherwise: NodePath) -> NodePath:
	var across := per_row(nodes.size())
	if column < 0 or column >= across or row < 0:
		return otherwise
	var index := row * across + (across - 1 - column if row % 2 == 1 else column)
	if index >= nodes.size() or nodes[index].disabled:
		return otherwise
	return nodes[index].get_path()


## A stage's node on page `map` (an index into the pages on show).
func _level_node(stage: String, map: int) -> Button:
	var node := Button.new()
	node.flat = true
	node.set_meta("map", map)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		node.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var unlocked := SaveGame.is_unlocked(stage)
	node.disabled = not unlocked
	if unlocked:
		node.focus_mode = Control.FOCUS_ALL
		node.pressed.connect(_pick.bind(node, stage))
		node.mouse_entered.connect(node.grab_focus)
		node.focus_entered.connect(node.queue_redraw)
		# The keys reaching a node on another map bring that map along.
		node.focus_entered.connect(func() -> void:
			if _map != map:
				_show_map(map))
		node.focus_exited.connect(node.queue_redraw)
	else:
		node.focus_mode = Control.FOCUS_NONE
	node.draw.connect(_draw_node.bind(node, SaveGame.stage_tag(stage)))
	# The selection marks the stone, not the number under it.
	node.set_meta("selection_rect", Rect2(Vector2(roundf((NODE_SIZE.x - NODE_TEXTURE.get_width()) / 2.0), 1.0), NODE_TEXTURE.get_size()))
	return node


func _draw_node(node: Button, number: String) -> void:
	var art := Vector2(roundf((NODE_SIZE.x - NODE_TEXTURE.get_width()) / 2.0), 1.0)
	var locked := node.disabled
	node.draw_texture(NODE_TEXTURE, art, LOCKED_TINT if locked else Color.WHITE)
	if locked:
		PotionData.draw_lock_icon(node, art + NODE_TEXTURE.get_size() / 2.0, Color(1, 1, 1, 0.85))
	var font := node.get_theme_font("font")
	var color := GOLD if node.has_focus() else (Color(1, 1, 1, 0.6) if locked else Color.WHITE)
	var at := Vector2(0, NUMBER_BASELINE)
	node.draw_string_outline(font, at, number, HORIZONTAL_ALIGNMENT_CENTER, NODE_SIZE.x, 8, 3, TEXT_OUTLINE)
	node.draw_string(font, at, number, HORIZONTAL_ALIGNMENT_CENTER, NODE_SIZE.x, 8, color)
