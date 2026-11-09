extends Node2D
## A puzzle stage. Sets up the stage bounds, plays the intro dialogue on the
## first attempt, restarts on R or shortly after the player dies, and on
## reaching the exit unlocks the next stage and offers to go on. An iris opens
## as it starts, and closes on the knight before a restart or the next stage.
## Once the player is out of potions with no way to get more, and hasn't yet
## got past the parts that need them, a red "PRESS R" line stays up.
## Each stage starts from its own inventory; nothing carries over.
## Hints: Sheldon gives `hint_lines` when asked from the notebook (GIVE HINT),
## and by himself every SaveGame.AUTO_HINT_EVERY restarts with auto hints on.
## With them off, once the NUDGE_AT_RESTART-th retry starts he reminds the
## player (above the knight's head, not a conversation) that they can ask.
## Hints a stage cues itself (see level_2_2.gd) play as well.

## Restarts per stage this session. Static, so it survives scene reloads.
static var _restarts := {}

@export var stage_id := "1-1"
## Width and height of the playable area, in pixels.
@export var stage_size := Vector2(384, 216)
@export var throwing_enabled := true
## Shows the potion bar. Off for stages that only teach moving.
@export var show_potion_bar := true
## "SPEAKER: text" lines played when the stage is first entered.
@export var intro_lines: PackedStringArray
## What the intro teaches, so skipping it warns the player.
@export_enum("none", "hint", "tutorial") var intro_teaches := "none"
## "SPEAKER: text" lines Sheldon gives as this stage's hint.
@export var hint_lines: PackedStringArray
## "SPEAKER: text" lines played on reaching the exit, before the banner.
@export var exit_lines: PackedStringArray
@export var player: CharacterBody2D
@export var thrower: Node2D
@export var hud: Control
@export var inventory: Inventory
@export var backdrop: Node2D
## Seconds between dying and the restart's iris closing.
@export var restart_delay := 1.0
## After this many tries to throw with no potion picked, the potion slots
## blink until one is picked. 0 turns it off.
@export var highlight_slots_after_misses := 3
## Past this x (stage pixels) nothing left needs a potion, so running out
## doesn't call for a restart. 0 means NEAR_EXIT pixels before the exit.
@export var potions_needed_until_x := 0.0

const NAME_PROMPT := preload("res://scripts/puzzle/name_prompt.gd")
const NEAR_EXIT := 48.0
## With auto hints off, the retry at whose start Sheldon reminds the player
## that the notebook has hints.
const NUDGE_AT_RESTART := 11
const NUDGE_LINE := "You know, you can always ask for a hint in the notebook."
const NUDGE_TIME := 6.0
## Seconds between checks for being stuck without potions.
const STUCK_CHECK_TIME := 0.25

var _over := false
var _pick_misses := 0


func _ready() -> void:
	get_tree().paused = false
	SaveGame.set_last_stage(stage_id)
	_setup_bounds()
	player.died.connect(_on_player_died)
	var exit := get_tree().get_first_node_in_group("stage_exit")
	if exit:
		exit.reached.connect(_on_exit_reached)
	inventory.selected_changed.connect(func(kind: StringName) -> void:
		player.float_text("[%s]" % PotionData.NAMES[kind], PotionData.color_of(kind)))
	if highlight_slots_after_misses > 0:
		inventory.pick_missed.connect(_on_pick_missed)
		inventory.selected_changed.connect(func(_kind: StringName) -> void:
			_pick_misses = 0
			hud.highlight_slots(false))
	thrower.set_process_unhandled_input(throwing_enabled)
	hud.set_potions_enabled(show_potion_bar)
	if throwing_enabled:
		var stuck_check := Timer.new()
		stuck_check.wait_time = STUCK_CHECK_TIME
		stuck_check.timeout.connect(_check_stuck)
		add_child(stuck_check)
		stuck_check.start()
	hud.restart_pressed.connect(restart)
	hud.next_pressed.connect(_go_next)
	hud.levels_pressed.connect(SaveGame.go_to.bind(SaveGame.LEVEL_SELECT))
	hud.book.has_hint = not hint_lines.is_empty()
	hud.book.set_level_label(SaveGame.stage_label(stage_id))
	hud.dialogue.set_level_label(SaveGame.stage_label(stage_id))
	hud.book.set_can_skip(SaveGame.next_stage(stage_id) != "")
	hud.book.skip_requested.connect(_skip_level)
	hud.book.hint_requested.connect(show_hint)
	_begin_attempt.call_deferred(restart_count())
	_iris_out()


## Opens on the knight once the camera has settled on him.
func _iris_out() -> void:
	Iris.cover()
	await get_tree().process_frame
	if is_inside_tree():
		Iris.open(_iris_focus())


## The middle of the knight, on screen.
func _iris_focus() -> Vector2:
	return player.get_global_transform_with_canvas().origin + Vector2(0, -14)


## How many times this stage has been restarted since it was last cleared.
func restart_count() -> int:
	return _restarts.get(stage_id, 0)


## Sheldon gives this stage's hint (queued after anything already playing).
func show_hint() -> void:
	hud.dialogue.play(hint_lines, &"hint")


func restart() -> void:
	if Iris.is_closed:
		return
	_restarts[stage_id] = restart_count() + 1
	get_tree().paused = true
	await Iris.close(_iris_focus())
	if not is_inside_tree():
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


func _skip_level() -> void:
	_restarts.erase(stage_id)
	SaveGame.skip_stage(stage_id, _iris_focus())


func _on_pick_missed() -> void:
	_pick_misses += 1
	if _pick_misses >= highlight_slots_after_misses:
		hud.highlight_slots(true)


func _check_stuck() -> void:
	hud.show_restart_hint(not _over and not player._dead and is_stuck())


## Out of potions with no way to make more, short of the point where none are
## needed, and nothing still in play that could change things (a potion in
## the air, an effect still running on the player or a monster).
func is_stuck() -> bool:
	if inventory.unlimited:
		return false
	if player.global_position.x >= _no_potions_needed_x():
		return false
	if PotionData.KINDS.any(func(kind: StringName) -> bool: return inventory.count(kind) > 0):
		return false
	if PotionData.INGREDIENTS.any(func(kind: StringName) -> bool: return inventory.ingredient_count(kind) > 0):
		return false
	var tree := get_tree()
	if tree.get_node_count_in_group("potions") > 0 or tree.get_node_count_in_group("pickups") > 0:
		return false
	if tree.get_nodes_in_group("chests").any(func(chest: Node) -> bool: return not chest.is_opened()):
		return false
	if tree.get_nodes_in_group("enemies").any(func(enemy: Node) -> bool: return enemy.has_effect()):
		return false
	return not (player.is_translucent() or player.is_frozen() or player.is_burning())


func _no_potions_needed_x() -> float:
	if potions_needed_until_x > 0.0:
		return potions_needed_until_x
	var exit := get_tree().get_first_node_in_group("stage_exit") as Node2D
	return exit.global_position.x - NEAR_EXIT if exit else INF


func _begin_attempt(attempt: int) -> void:
	_on_stage_start(attempt)
	_offer_hint(attempt)


## Called once the stage is ready; `attempt` is 0 on the first try.
## Stages override this for their own cued lines; hints are offered after.
func _on_stage_start(attempt: int) -> void:
	if attempt == 0:
		hud.dialogue.play(intro_lines, _teaches(intro_teaches))


## Auto hints on: the hint every AUTO_HINT_EVERY restarts. Off: one reminder
## that the notebook has hints, as the NUDGE_AT_RESTART-th retry starts.
func _offer_hint(attempt: int) -> void:
	if attempt == 0 or hint_lines.is_empty():
		return
	if SaveGame.auto_hints:
		if attempt % SaveGame.AUTO_HINT_EVERY == 0:
			show_hint()
	elif attempt == NUDGE_AT_RESTART:
		player.say("SHELDON", NUDGE_LINE, hud.dialogue.color_of("SHELDON"), NUDGE_TIME)


## "none" / "hint" / "tutorial" (from an export) as the dialogue box wants it.
static func _teaches(kind: String) -> StringName:
	return &"" if kind == "none" else StringName(kind)


## Lines for Sheldon at the exit; stages can override to pick them on the fly.
func _exit_lines() -> PackedStringArray:
	return exit_lines


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not player._dead:
		restart()
	elif _over and event.is_action_pressed("ui_accept") and SaveGame.next_stage(stage_id) != "":
		_go_next()


func _on_player_died(cause: StringName) -> void:
	_stop_play()
	hud.set_potions_enabled(false)
	await get_tree().create_timer(restart_delay).timeout
	if is_inside_tree():
		restart()


func _on_exit_reached() -> void:
	_over = true
	_stop_play()
	player.set_physics_process(false)
	_restarts.erase(stage_id)
	var next := SaveGame.next_stage(stage_id)
	SaveGame.unlock(next)
	# The very end stops the secret timer.
	var full_run := next == "" and SaveGame.finish_run()
	var lines := _exit_lines()
	if not lines.is_empty():
		await hud.dialogue.interrupt(lines, player)
	var run_time := ""
	if full_run:
		var prompt := NAME_PROMPT.new()
		hud.add_child(prompt)
		var player_name: String = await prompt.ask()
		SaveGame.record_playtester(player_name)
		run_time = "%s - %s" % [player_name, SaveGame.format_time(SaveGame.run_seconds)]
	var level_done := SaveGame.is_last_in_level(stage_id)
	if level_done:
		var title: String = SaveGame.LEVELS[SaveGame.level_of(stage_id)].title
		hud.show_banner("%s COMPLETE" % (title if title != "" else "LEVEL"), run_time, Color(0.95, 0.85, 0.55))
	else:
		hud.show_banner("STAGE CLEAR", "", Color(0.95, 0.85, 0.55))
	hud.show_end_buttons(next != "", "NEXT LEVEL" if level_done else "NEXT STAGE")


func _go_next() -> void:
	SaveGame.play_stage(SaveGame.next_stage(stage_id), _iris_focus())


func _stop_play() -> void:
	thrower.cancel()
	thrower.set_process_unhandled_input(false)
	hud.disable_book()


## Camera limits, backdrop grid and invisible walls around the stage.
func _setup_bounds() -> void:
	var camera: Camera2D = player.get_node("Camera")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(stage_size.x)
	camera.limit_bottom = int(stage_size.y)
	backdrop.columns = ceili(stage_size.x / backdrop.cell_size)
	backdrop.rows = ceili(stage_size.y / backdrop.cell_size)
	backdrop.queue_redraw()
	var edges := StaticBody2D.new()
	edges.name = "Edges"
	for edge in [[Vector2.ZERO, Vector2.DOWN], [Vector2.ZERO, Vector2.RIGHT], [Vector2(stage_size.x, 0), Vector2.LEFT]]:
		var shape := CollisionShape2D.new()
		var boundary := WorldBoundaryShape2D.new()
		boundary.normal = edge[1]
		shape.shape = boundary
		shape.position = edge[0]
		edges.add_child(shape)
	add_child(edges)
