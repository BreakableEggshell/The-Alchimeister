extends "res://scripts/puzzle/puzzle_level.gd"
## THE DEMON LORD: a chase in three stages (`part`), the Demon King's giant
## form (DemonLord, a wall of darkness) creeping after the knight.
## 1 (P11): the Demon King stands there at his normal size, until a fly bush
##   throws a growth potion at him and he grows into the wall (first try
##   only; retries start with the wall). Run; near the end (`door_reveal_x`)
##   the door appears.
## 2 (P12): a room with a chest: the ??? potion's recipe (found for good, and
##   shown on a note with its fixed mix). Then the wall bursts in from the
##   left and the door opens: run for it. Seen up close until the chest is
##   opened, then out to the chase's view.
## 3 (P13): the chase again, with no door. Only the ??? potion touches him:
##   it ends the chase, and the game, with the ending conversation. Up close
##   at the chests at the start, out to the chase's view past `zoom_out_x`.
## Doors go straight on to the next stage. In any stage, a Death potion on him
## kills him instead: a different ending, after which there's nowhere to go
## (the restart hint shows).

const RECIPE_NOTE := preload("res://scripts/puzzle/recipe_note.gd")
const DK_STANDING := preload("res://assets/dk_stand.png")
const DK_KNEELING := preload("res://assets/dk_kneel.png")
const FLY_BUSH := preload("res://assets/sprites/characters/fly_bush.png")
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
## Where each Demon King picture's feet are (the sprite's offset puts them on
## its origin).
const DK_STANDING_OFFSET := Vector2(0, -38)
const DK_KNEELING_OFFSET := Vector2(0, -33)
const ENDING_START := [
	"DEMON KING: What is this?",
	"DEMON KING: It's not a potion of weakness, or poison, or burn...",
	"DEMON KING: This is-",
]
const ENDING_REST := [
	"DEMON KING (aura): HAHAHAHA",
	"DEMON KING: Not bad, Alchemist. Not bad",
	"DEMON KING: This is a first",
	"ALCHEMIST: ...",
	"DEMON KING: ...",
	"DEMON KING: ... well, what are you waiting for?",
	"ALCHEMIST: You're willingly letting me k*** you?",
	"DEMON KING: Isn't that the entire reason why you and all of humanity came to my castle?",
	"ALCHEMIST: I wanted to k*** you in a different scenario",
	"ALCHEMIST: But if you're offering...",
	"ALCHEMIST: Then close your eyes first",
	"DEMON KING: Hah, I don't fear whatever comes next",
	"DEMON KING: You have the gal to tell me to close my eyes to whatever will come next",
	"ALCHEMIST: Then prepare yourself",
]
const BAD_END := [
	"SHELDON: ...",
	"ALCHEMIST: What have I done...?",
	"SHELDON: This is what you wanted, isn't it?",
	"ALCHEMIST: But my curse",
	"ALCHEMIST: ...",
	"ALCHEMIST: I'll never be able to break it",
]
## The camera (Godot 4: below 1 shows more): zoomed out to 2/3 while running
## (the stages' cameras start like this), in to normal size for the cutscenes
## (the transformation, the endings).
const CHASE_ZOOM := Vector2(2.0 / 3.0, 2.0 / 3.0)
const CUTSCENE_ZOOM := Vector2.ONE
const ZOOM_TIME := 0.9
const SECRET_NOTE_TITLE := "???"
const SECRET_NOTE_TEXT := ["ONE OF EVERY", "INGREDIENT"]

@export_range(1, 3) var part := 1
@export var boss: DemonLord
## The Demon King at his normal size (and kneeling, at the end).
@export var demon_king: Sprite2D
## The door on to the next stage (parts 1 and 2), hidden until it's time.
@export var exit_door: Area2D
## Part 1: the door appears once the knight gets this far.
@export var door_reveal_x := 0.0
## Part 2: the chest with the recipe.
@export var chest: Node
## Seconds before the chase starts, when there's no transformation to watch.
@export var chase_delay := 1.5
## Part 2: how fast the wall comes in after the note.
@export var burst_speed := 40.0
## Part 3: past this (a little beyond the chests), the camera zooms out.
@export var zoom_out_x := 210.0

## Killed with a Death potion: no way on.
var _doomed := false
var _ending := false
var _door_shown := false
## Parts 2 and 3: still up close, until the chest (2) or zoom_out_x (3).
var _close := false
## Over everything (white-out, black, the end).
var _overlay: CanvasLayer


func _ready() -> void:
	super()
	_overlay = CanvasLayer.new()
	_overlay.layer = 90
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)
	boss.struck.connect(_on_struck)
	boss.killed.connect(_on_killed)
	if exit_door:
		_set_door(false)
	if chest:
		chest.opened.connect(_on_chest_opened)
	if demon_king:
		demon_king.texture = DK_STANDING
		demon_king.offset = DK_STANDING_OFFSET
		demon_king.scale = Vector2(0.8, 0.8)
		demon_king.hide()
	# The transformation is a cutscene: it opens at normal size.
	if part == 1 and restart_count() == 0:
		_camera().zoom = CUTSCENE_ZOOM
	# The chest stages open up close, on the chests.
	if part >= 2:
		_camera().zoom = CUTSCENE_ZOOM
		_close = true


func _on_stage_start(attempt: int) -> void:
	super(attempt)
	match part:
		1:
			if attempt == 0:
				_transformation()
			else:
				_chase_after(chase_delay)
		2:
			boss.hide()
		3:
			_chase_after(chase_delay)


## The Demon Lord's waltz, all three stages through.
func _music() -> AudioStream:
	return Music.BOSS


## No retry nudges from Sheldon here: the only lines are the scripted ones.
func _offer_hint(_attempt: int) -> void:
	pass


func _chase_after(seconds: float) -> void:
	boss.show()
	await get_tree().create_timer(seconds, false).timeout
	if is_inside_tree() and not _doomed and not _ending:
		boss.start()


func _process(_delta: float) -> void:
	if part == 1 and exit_door and not _door_shown and not _doomed and player.global_position.x >= door_reveal_x:
		_set_door(true, true)
	if part == 3 and _close and player.global_position.x >= zoom_out_x:
		_zoom_out()


## Out from the close view to the chase's, once (parts 2 and 3).
func _zoom_out() -> void:
	if not _close:
		return
	_close = false
	if not _ending and not _doomed:
		_zoom_to(CHASE_ZOOM)


## Shows or hides the door on to the next stage (and lets it be walked into).
func _set_door(on: bool, fade := false) -> void:
	_door_shown = on
	exit_door.visible = on
	exit_door.set_deferred("monitoring", on)
	if on and fade:
		exit_door.modulate.a = 0.0
		create_tween().tween_property(exit_door, "modulate:a", 1.0, 0.6)


# --- Part 1: the transformation

## The Demon King, normal size, left of the knight. A fly bush flutters in and
## throws a growth potion at him; a flash, and he swells into the wall.
func _transformation() -> void:
	boss.hide()
	thrower.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player.face(-1.0)
	demon_king.show()
	var feet := demon_king.global_position
	await _wait(0.8)
	var bush := Sprite2D.new()
	bush.texture = FLY_BUSH
	bush.hframes = 4
	bush.offset = Vector2(0, -7)
	bush.z_index = 4
	add_child(bush)
	var flap := bush.create_tween().set_loops()
	flap.tween_property(bush, "frame", 3, 0.5).from(0)
	bush.global_position = Vector2(player.global_position.x + 220.0, feet.y - 150.0)
	var perch := Vector2(feet.x + 80.0, feet.y - 90.0)
	var fly_in := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fly_in.tween_property(bush, "global_position", perch, 1.6)
	await fly_in.finished
	await _wait(0.3)
	# The throw: an arc onto the Demon King.
	var potion := Potion.new()
	potion.kind = PotionData.GROWTH
	potion.gravity = 400.0
	var flight := 0.7
	var target := feet + Vector2(0, -10)
	potion.velocity = (target - perch) / flight - Vector2(0, 0.5 * potion.gravity * flight)
	add_child(potion)
	potion.global_position = perch
	await _wait(flight)
	_flash(Color(0.85, 0.6, 1.0), 0.9, 0.6)
	_shake(1.2)
	demon_king.hide()
	var fly_off := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	bush.flip_h = true
	fly_off.tween_property(bush, "global_position", Vector2(player.global_position.x + 260.0, feet.y - 260.0), 1.2)
	fly_off.tween_callback(bush.queue_free)
	await boss.grow_at(feet, 1.2)
	await _wait(0.3)
	# Out to the chase's view as it starts.
	await _zoom_to(CHASE_ZOOM)
	player.set_physics_process(true)
	thrower.set_process_unhandled_input(throwing_enabled)
	if not _doomed:
		boss.start()


# --- Part 2: the recipe

## The ??? recipe (found for good), on a note with its one mix. Then the wall
## bursts in from the left, and the door opens.
func _on_chest_opened() -> void:
	var tree := get_tree()
	tree.paused = true
	SaveGame.find_recipe(PotionData.SECRET)
	var note := RECIPE_NOTE.new()
	note.potion = PotionData.SECRET
	note.title = SECRET_NOTE_TITLE
	note.text = SECRET_NOTE_TEXT
	note.fixed_mix.assign(PotionData.INGREDIENTS)
	hud.add_child(note)
	await note.read()
	note.queue_free()
	if not is_inside_tree():
		return
	tree.paused = false
	# Out to the chase's view, to see the wall coming.
	_zoom_out()
	await _wait(0.4)
	_shake(0.8)
	boss.speed = burst_speed
	boss.catch_up_speed = burst_speed
	boss.show()
	boss.start()
	_set_door(true, true)


# --- Going on

## Parts 1 and 2: straight on to the next stage, no STAGE CLEAR.
func _on_exit_reached() -> void:
	if part == 3:
		super()
		return
	if _over:
		return
	_over = true
	boss.stop()
	_stop_play()
	player.set_physics_process(false)
	_forget_stage()
	var next := SaveGame.next_stage(stage_id)
	SaveGame.unlock(next)
	SaveGame.mark_split(stage_id)
	SaveGame.play_stage(next, _iris_focus())


# --- The endings

## The ??? potion. In the last part it ends everything; before that it's only
## another potion that does nothing to him.
func _on_struck() -> void:
	if part != 3:
		boss._no_effect()
		return
	if _ending or _doomed:
		return
	_ending = true
	_close = false
	boss.stop()
	_stop_play()
	await _wait_until_landed()
	player.set_physics_process(false)
	player.face(-1.0)
	await _zoom_to(CUTSCENE_ZOOM)
	await hud.dialogue.interrupt(PackedStringArray(ENDING_START))
	# A white-out, and he's back to his normal size: kneeling.
	var white := _flash(Color.WHITE, 1.0, 0.0)
	await _fade(white, 1.0, 0.6)
	boss.hide()
	demon_king.texture = DK_KNEELING
	demon_king.offset = DK_KNEELING_OFFSET
	demon_king.global_position = Vector2(player.global_position.x - 56.0, player.global_position.y)
	demon_king.show()
	await _wait(0.5)
	await _fade(white, 0.0, 0.9)
	white.queue_free()
	await _wait(0.4)
	await hud.dialogue.interrupt(PackedStringArray(ENDING_REST))
	# -END-
	var black := _flash(Color.BLACK, 1.0, 0.0)
	await _fade(black, 1.0, 1.0)
	var the_end := Label.new()
	the_end.text = "-END-"
	the_end.add_theme_font_override("font", FONT)
	the_end.add_theme_font_size_override("font_size", 16)
	the_end.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	the_end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	the_end.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	the_end.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	the_end.modulate.a = 0.0
	_overlay.add_child(the_end)
	await _fade(the_end, 1.0, 0.8)
	await _wait(2.5)
	var away := create_tween().set_parallel()
	away.tween_property(the_end, "modulate:a", 0.0, 0.8)
	away.tween_property(black, "modulate:a", 0.0, 0.8)
	await away.finished
	the_end.queue_free()
	black.queue_free()
	super._on_exit_reached()


## A Death potion: he dissolves. Sheldon and the knight talk, and then
## there's nowhere left to go.
func _on_killed() -> void:
	if _ending or _doomed:
		return
	_doomed = true
	_close = false
	if exit_door:
		_set_door(false)
	boss.dissolve()
	await _zoom_to(CUTSCENE_ZOOM)
	await hud.dialogue.interrupt(PackedStringArray(BAD_END), player)
	# Free to walk about again, at the running view.
	await _zoom_to(CHASE_ZOOM)


## After killing him: stuck for good.
func is_stuck() -> bool:
	return _doomed or super()


# --- Effects

## A full-screen colour over everything, starting at `alpha`, fading to
## nothing over `fade` seconds (0: stays, to be faded by hand). Returns it.
func _flash(color: Color, alpha: float, fade: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.modulate.a = alpha if fade > 0.0 else 0.0
	_overlay.add_child(rect)
	if fade > 0.0:
		var tween := rect.create_tween()
		tween.tween_property(rect, "modulate:a", 0.0, fade)
		tween.tween_callback(rect.queue_free)
	return rect


func _fade(item: CanvasItem, to: float, time: float) -> void:
	var tween := item.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(item, "modulate:a", to, time)
	await tween.finished


func _camera() -> Camera2D:
	return player.get_node("Camera") as Camera2D


## Eases the camera's zoom to `zoom` (see CHASE_ZOOM).
func _zoom_to(zoom: Vector2) -> void:
	var camera := _camera()
	if camera.zoom.is_equal_approx(zoom):
		return
	var tween := camera.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "zoom", zoom, ZOOM_TIME)
	await tween.finished


## The camera shakes for `time` seconds.
func _shake(time: float) -> void:
	var camera := player.get_node_or_null("Camera") as Camera2D
	if not camera:
		return
	var shake := camera.create_tween()
	for i in int(time / 0.04):
		var strength := 5.0 * (1.0 - float(i) * 0.04 / time)
		shake.tween_property(camera, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength) * 0.7), 0.04)
	shake.tween_property(camera, "offset", Vector2.ZERO, 0.04)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _wait_until_landed() -> void:
	var t := 0.0
	while t < 1.5 and not player.is_on_floor():
		await get_tree().physics_frame
		t += 1.0 / 60.0
