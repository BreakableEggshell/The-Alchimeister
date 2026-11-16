class_name LevelPreview
extends Control
## Debug: a gallery of every level, each shown whole, to look up quickly how a
## puzzle is laid out. Each stage is built offscreen with nothing running (no
## knight script, HUD, dialogue or monsters moving), pictured once, and kept.
## Levels come in the level select's sections (SaveGame maps: MAP 1, SECRET
## LEVELS, SPECIAL, PROTOTYPES), every one of them here whatever the level
## select shows. The upper row picks a section (PgUp / PgDn too), the lower
## row one of its levels (left / right steps through them); BACK or Esc
## closes it.

## The player closed the gallery.
signal closed

const GOLD := Color(0.95, 0.85, 0.55)
const BG := Color(0.06, 0.06, 0.09)
## Where the level's picture fits, keeping its shape.
const PICTURE_AREA := Rect2(6, 20, 372, 146)
const SECTIONS_Y := 170.0
const NUMBERS_Y := 190.0
const NUMBER_SIZE := Vector2(34, 16)
## The stage_base parts that aren't the level itself.
const STAGE_PARTS := ["Backdrop", "Inventory", "Knight", "PotionThrower", "HUD"]

## Stage -> its picture, once taken.
var _pictures := {}
var _stages: Array[String] = []
var _picture: TextureRect
var _title: Label
var _loading: Label
## Map -> its section button, and the section on show.
var _section_buttons := {}
var _section := 0
var _sections_row: HBoxContainer
var _numbers_row: HBoxContainer
## The section on show's level buttons, and their stages.
var _buttons: Array[Button] = []
var _button_stages: Array[String] = []
var _back: Button
var _shown := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stages = SaveGame.all_stages()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_title = Label.new()
	_title.add_theme_color_override("font_color", GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 5)
	_title.size = Vector2(get_viewport_rect().size.x, 10)
	add_child(_title)
	var frame := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(GOLD, 0.5)
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", style)
	frame.position = PICTURE_AREA.position - Vector2.ONE
	frame.size = PICTURE_AREA.size + Vector2(2, 2)
	add_child(frame)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Shrunk to fit, so smooth rather than skipping pixels.
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.position = PICTURE_AREA.position
	_picture.size = PICTURE_AREA.size
	add_child(_picture)
	_loading = Label.new()
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading.position = PICTURE_AREA.position
	_loading.size = PICTURE_AREA.size
	add_child(_loading)
	_sections_row = HBoxContainer.new()
	_sections_row.add_theme_constant_override("separation", 2)
	add_child(_sections_row)
	for map in SaveGame.MAP_COUNT:
		var section := Button.new()
		section.text = SaveGame.MAP_NAMES[map]
		section.custom_minimum_size.y = NUMBER_SIZE.y
		section.focus_mode = Control.FOCUS_ALL
		section.focus_entered.connect(_show_section.bind(map))
		section.mouse_entered.connect(section.grab_focus)
		_sections_row.add_child(section)
		_section_buttons[map] = section
	_back = Button.new()
	_back.text = "BACK"
	_back.custom_minimum_size = Vector2(40, NUMBER_SIZE.y)
	_back.focus_mode = Control.FOCUS_ALL
	_back.pressed.connect(closed.emit)
	_back.mouse_entered.connect(_back.grab_focus)
	_sections_row.add_child(_back)
	_sections_row.reset_size()
	_sections_row.position = Vector2(roundf((get_viewport_rect().size.x - _sections_row.size.x) / 2.0), SECTIONS_Y)
	UiFocus.link_row(_sections_row.get_children())
	_numbers_row = HBoxContainer.new()
	_numbers_row.add_theme_constant_override("separation", 2)
	add_child(_numbers_row)
	_show_section(SaveGame.PLAYABLE_MAP)
	_buttons[0].grab_focus()
	_take_pictures()


func focus_first() -> void:
	var at := _button_stages.find(_shown)
	_buttons[maxi(at, 0)].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var step := 0
	if event.is_action_pressed("ui_page_down"):
		step = 1
	elif event.is_action_pressed("ui_page_up"):
		step = -1
	if step != 0:
		var to := posmod(_section + step, SaveGame.MAP_COUNT)
		_show_section(to)
		_buttons[0].grab_focus()
		get_viewport().set_input_as_handled()


## The lower row becomes `map`'s levels, and its first is shown (unless
## one of them is already).
func _show_section(map: int) -> void:
	if map == _section and not _buttons.is_empty():
		return
	_section = map
	for other in _section_buttons:
		var color := GOLD if other == map else Color.WHITE
		for prop in ["font_color", "font_hover_color", "font_focus_color"]:
			_section_buttons[other].add_theme_color_override(prop, color)
	for button in _buttons:
		button.free()
	_buttons.clear()
	_button_stages = SaveGame.map_stages(map)
	for stage in _button_stages:
		var button := Button.new()
		button.text = SaveGame.stage_tag(stage)
		button.custom_minimum_size = NUMBER_SIZE
		button.focus_mode = Control.FOCUS_ALL
		button.focus_entered.connect(_show.bind(stage))
		button.mouse_entered.connect(button.grab_focus)
		_numbers_row.add_child(button)
		_buttons.append(button)
	_numbers_row.reset_size()
	_numbers_row.position = Vector2(roundf((get_viewport_rect().size.x - _numbers_row.size.x) / 2.0), NUMBERS_Y)
	UiFocus.link_row(_buttons)
	# Up from a level goes to its section; down from a section to its levels.
	for button in _buttons:
		button.focus_neighbor_top = button.get_path_to(_section_buttons[map])
	for section in _sections_row.get_children():
		section.focus_neighbor_bottom = section.get_path_to(_buttons[0])
	if not _button_stages.has(_shown):
		_show(_button_stages[0])


func _show(stage: String) -> void:
	_shown = stage
	var group: Dictionary = SaveGame.LEVELS[SaveGame.level_of(stage)]
	_title.text = "%s  %s" % [SaveGame.stage_label(stage), group.title]
	_picture.texture = _pictures.get(stage)
	_loading.text = "" if _pictures.has(stage) else "LOADING..."


## Pictures every stage in turn, the one on show first.
func _take_pictures() -> void:
	var order := _stages.duplicate()
	if _shown != "":
		order.erase(_shown)
		order.push_front(_shown)
	for stage in order:
		if not is_inside_tree():
			return
		if not _pictures.has(stage):
			_pictures[stage] = await _picture_of(stage)
		if stage == _shown:
			_show(stage)


## The whole stage, drawn once offscreen: its level and monsters over the room
## behind, with the knight where he starts.
func _picture_of(stage: String) -> Texture2D:
	var built: Node = load(SaveGame.STAGE_SCENES[stage]).instantiate()
	var size: Vector2 = built.stage_size
	var view := SubViewport.new()
	view.size = Vector2i(size)
	view.process_mode = Node.PROCESS_MODE_DISABLED
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var room := ColorRect.new()
	room.color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	room.size = size
	view.add_child(room)
	var backdrop := Board.new()
	backdrop.columns = ceili(size.x / backdrop.cell_size)
	backdrop.rows = ceili(size.y / backdrop.cell_size)
	view.add_child(backdrop)
	# Everything the stage adds to the base: the level, monsters and so on.
	for part in built.get_children():
		if part.name in STAGE_PARTS:
			continue
		built.remove_child(part)
		part.owner = null
		view.add_child(part)
	var knight := built.get_node("Knight") as Node2D
	var sprite := knight.get_node("Sprite").duplicate() as Sprite2D
	sprite.position += knight.position
	sprite.z_index = 1
	view.add_child(sprite)
	built.free()
	add_child(view)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture := ImageTexture.create_from_image(view.get_texture().get_image())
	view.queue_free()
	return picture
