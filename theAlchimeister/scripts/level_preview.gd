class_name LevelPreview
extends Control
## Debug: a gallery of every level, each shown whole, to look up quickly how a
## puzzle is laid out. Each stage is built offscreen with nothing running (no
## knight script, HUD, dialogue or monsters moving), pictured once, and kept.
## The numbers along the bottom, in two rows, pick a level (left / right
## steps through them); BACK or Esc closes it.

## The player closed the gallery.
signal closed

const GOLD := Color(0.95, 0.85, 0.55)
const BG := Color(0.06, 0.06, 0.09)
## Where the level's picture fits, keeping its shape.
const PICTURE_AREA := Rect2(6, 20, 372, 146)
const BUTTONS_Y := 172.0
## Number buttons in each row.
const PER_ROW := 9
## The stage_base parts that aren't the level itself.
const STAGE_PARTS := ["Backdrop", "Inventory", "Knight", "PotionThrower", "HUD"]

## Stage -> its picture, once taken.
var _pictures := {}
var _stages: Array[String] = []
var _picture: TextureRect
var _title: Label
var _loading: Label
var _buttons: Array[Button] = []
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
	var row := GridContainer.new()
	row.columns = PER_ROW
	row.add_theme_constant_override("h_separation", 2)
	row.add_theme_constant_override("v_separation", 2)
	add_child(row)
	for i in _stages.size():
		var button := Button.new()
		button.text = str(i + 1)
		button.custom_minimum_size = Vector2(36, 16)
		button.focus_mode = Control.FOCUS_ALL
		button.focus_entered.connect(_show.bind(_stages[i]))
		button.mouse_entered.connect(button.grab_focus)
		row.add_child(button)
		_buttons.append(button)
	_back = Button.new()
	_back.text = "BACK"
	_back.custom_minimum_size = Vector2(36, 16)
	_back.focus_mode = Control.FOCUS_ALL
	_back.pressed.connect(closed.emit)
	_back.mouse_entered.connect(_back.grab_focus)
	row.add_child(_back)
	row.reset_size()
	row.position = Vector2(roundf((get_viewport_rect().size.x - row.size.x) / 2.0), BUTTONS_Y)
	UiFocus.link_row(row.get_children())
	_buttons[0].grab_focus()
	_take_pictures()


func focus_first() -> void:
	for i in _stages.size():
		if _stages[i] == _shown:
			_buttons[i].grab_focus()
			return
	_buttons[0].grab_focus()


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
