extends Control
## Level select: a map with one node per stage, numbered in play order (the
## numbers are only for this screen; stages keep their ids, like "1-2").
## Nodes wind across the map in rows (at most MAX_ROWS), placed from however
## many stages there are. Clicking an unlocked node plays that stage; locked
## ones are dimmed with a padlock and can't be picked. Clouds drift across the
## sky, each at its own pace, coming back round the other side.

const BACKGROUND := preload("res://assets/map1.png")
const NODE_TEXTURE := preload("res://assets/map1_levelnode.png")
const CLOUDS := preload("res://assets/map1_clouds.png")
## Each cloud in the cloud sheet, where it floats (its height, and where it
## starts across), and how fast it drifts in pixels per second. Smaller ones
## are further away, so they drift slower.
const CLOUD_LAYOUT: Array[Dictionary] = [
	{"region": Rect2(11, 10, 52, 25), "y": 6.0, "x": 20.0, "speed": 6.0},
	{"region": Rect2(82, 10, 59, 25), "y": 30.0, "x": 170.0, "speed": 4.5},
	{"region": Rect2(170, 16, 30, 13), "y": 50.0, "x": 300.0, "speed": 2.5},
	{"region": Rect2(234, 11, 51, 19), "y": 16.0, "x": 290.0, "speed": 3.5},
]
const GOLD := Color(0.95, 0.85, 0.55)
const TEXT_OUTLINE := Color(0.08, 0.1, 0.06)
const LOCKED_TINT := Color(0.55, 0.55, 0.55)
## A node's button: the art with its number below it.
const NODE_SIZE := Vector2(30, 26)
const NUMBER_BASELINE := 24.0
## Nodes per row: at least this many, more once MAX_ROWS rows would be full.
const MIN_PER_ROW := 5
const MAX_ROWS := 3
## The area of the map the nodes spread across (their centres): the grass,
## below the tree line.
const MAP_AREA := Rect2(44, 100, 296, 76)
## Every other node sits this far up or down, so a row isn't a straight line.
const WOBBLE := 10.0

var _nodes: Array[Button] = []
## Nodes per row on this map (see per_row()).
var _per_row := MIN_PER_ROW
var _sky: Control
## How far each cloud has drifted from where it starts.
var _drift: Array[float] = []


func _ready() -> void:
	add_to_group(UiFocus.SCREENS)
	_build()
	# Start on the furthest stage reached.
	for i in range(_nodes.size() - 1, -1, -1):
		if not _nodes[i].disabled:
			_nodes[i].grab_focus()
			break


func _process(delta: float) -> void:
	for i in _drift.size():
		_drift[i] += CLOUD_LAYOUT[i].speed * delta
	_sky.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SaveGame.go_to(SaveGame.START_MENU)
		get_viewport().set_input_as_handled()


## See UiFocus: the first node (node 1 is always unlocked).
func focus_first() -> bool:
	_nodes[0].grab_focus()
	return true


## How many nodes go in a row for `count` stages: MIN_PER_ROW, or more if
## MAX_ROWS rows of that wouldn't fit them all.
static func per_row(count: int) -> int:
	return maxi(MIN_PER_ROW, ceili(float(count) / MAX_ROWS))


## Where node `index` of `count` goes: rows that snake left to right, then
## right to left, so each number is next to the one before it.
static func node_center(index: int, count: int) -> Vector2:
	var across := per_row(count)
	var rows := ceili(float(count) / across)
	var row := index / across
	var column := _column_of(index, across)
	var x := MAP_AREA.position.x + MAP_AREA.size.x * column / (across - 1)
	var y := MAP_AREA.position.y + (MAP_AREA.size.y * row / (rows - 1) if rows > 1 else MAP_AREA.size.y / 2.0)
	return Vector2(x, y + (WOBBLE if column % 2 == 1 else -WOBBLE))


## Which column node `index` is in, counting from the left of the map, with
## `across` nodes to a row.
static func _column_of(index: int, across: int) -> int:
	var column := index % across
	return across - 1 - column if (index / across) % 2 == 1 else column


# --- Layout

func _build() -> void:
	var map := TextureRect.new()
	map.texture = BACKGROUND
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_SCALE
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map)

	_sky = Control.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.draw.connect(_draw_clouds)
	add_child(_sky)
	for cloud in CLOUD_LAYOUT:
		_drift.append(0.0)

	var title := Label.new()
	title.text = "SELECT LEVEL"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 12
	title.offset_bottom = 30
	add_child(title)

	var stages := SaveGame.all_stages()
	_per_row = per_row(stages.size())
	for i in stages.size():
		var node := _level_node(stages[i], i + 1)
		add_child(node)
		node.size = NODE_SIZE
		node.position = (node_center(i, stages.size()) - NODE_SIZE / 2.0).round()
		_nodes.append(node)

	var back := Button.new()
	back.text = "BACK"
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 8
	back.offset_top = -24
	back.offset_right = 64
	back.offset_bottom = -8
	back.pressed.connect(SaveGame.go_to.bind(SaveGame.START_MENU))
	add_child(back)
	_link_keys(back)


## WASD moves along a node's row and column on the map (the automatic guess can
## pick the wrong node on a winding layout). Locked nodes are skipped: left and
## right stay put, and down from there goes to BACK.
func _link_keys(back: Button) -> void:
	for i in _nodes.size():
		var node := _nodes[i]
		if node.disabled:
			continue
		var row := i / _per_row
		var column := _column_of(i, _per_row)
		node.focus_neighbor_left = _open_node_path(row, column - 1, node.get_path())
		node.focus_neighbor_right = _open_node_path(row, column + 1, node.get_path())
		node.focus_neighbor_top = _open_node_path(row - 1, column, node.get_path())
		node.focus_neighbor_bottom = _open_node_path(row + 1, column, back.get_path())
	var last_open := _nodes[0]
	for node in _nodes:
		if not node.disabled:
			last_open = node
	back.focus_neighbor_top = last_open.get_path()
	back.focus_neighbor_right = last_open.get_path()


## The path of the unlocked node at that spot on the map, else `otherwise`.
func _open_node_path(row: int, column: int, otherwise: NodePath) -> NodePath:
	if column < 0 or column >= _per_row or row < 0:
		return otherwise
	var index := row * _per_row + (_per_row - 1 - column if row % 2 == 1 else column)
	if index >= _nodes.size() or _nodes[index].disabled:
		return otherwise
	return _nodes[index].get_path()


func _level_node(stage: String, number: int) -> Button:
	var node := Button.new()
	node.flat = true
	node.tooltip_text = "LEVEL %d" % number
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		node.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var unlocked := SaveGame.is_unlocked(stage)
	node.disabled = not unlocked
	if unlocked:
		node.focus_mode = Control.FOCUS_ALL
		node.pressed.connect(SaveGame.play_stage.bind(stage))
		node.mouse_entered.connect(node.grab_focus)
		node.focus_entered.connect(node.queue_redraw)
		node.focus_exited.connect(node.queue_redraw)
	else:
		node.focus_mode = Control.FOCUS_NONE
	node.draw.connect(_draw_node.bind(node, number))
	return node


## Each cloud where it has drifted to, coming back in on the left once it has
## gone off the right edge. Whole pixels, so the pixel art stays crisp.
func _draw_clouds() -> void:
	var width := _sky.size.x
	for i in CLOUD_LAYOUT.size():
		var cloud: Dictionary = CLOUD_LAYOUT[i]
		var region: Rect2 = cloud.region
		var lap := width + region.size.x
		var x := fposmod(cloud.x + _drift[i] + region.size.x, lap) - region.size.x
		_sky.draw_texture_rect_region(CLOUDS, Rect2(Vector2(roundf(x), cloud.y), region.size), region)


func _draw_node(node: Button, number: int) -> void:
	var art := Vector2(roundf((NODE_SIZE.x - NODE_TEXTURE.get_width()) / 2.0), 1.0)
	var locked := node.disabled
	node.draw_texture(NODE_TEXTURE, art, LOCKED_TINT if locked else Color.WHITE)
	if locked:
		PotionData.draw_lock_icon(node, art + NODE_TEXTURE.get_size() / 2.0, Color(1, 1, 1, 0.85))
	elif node.has_focus():
		node.draw_rect(Rect2(art, NODE_TEXTURE.get_size()).grow(1.5), GOLD, false, 1.0)
	var font := node.get_theme_font("font")
	var color := GOLD if node.has_focus() else (Color(1, 1, 1, 0.6) if locked else Color.WHITE)
	var at := Vector2(0, NUMBER_BASELINE)
	node.draw_string_outline(font, at, str(number), HORIZONTAL_ALIGNMENT_CENTER, NODE_SIZE.x, 8, 3, TEXT_OUTLINE)
	node.draw_string(font, at, str(number), HORIZONTAL_ALIGNMENT_CENTER, NODE_SIZE.x, 8, color)
