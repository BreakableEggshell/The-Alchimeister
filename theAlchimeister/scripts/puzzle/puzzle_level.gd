extends Node2D
## A puzzle stage. Sets up the stage bounds, plays the intro dialogue on the
## first attempt, restarts on R or shortly after the player dies, and on
## reaching the exit unlocks the next stage and offers to go on. An iris opens
## as it starts, and closes on the knight before a restart or the next stage.
## Once the player is out of potions with no way to get more, and hasn't yet
## got past the parts that need them, a red "PRESS R" line stays up.
## Each stage starts from its own inventory; nothing carries over.
## Hints: Sheldon gives `hint_lines` when asked from the notebook (HINT). A line
## "---" splits them into parts: each ask gives the next part, looping back to
## the first. Every hint costs a level: the next one has no hints (one more
## level for each further hint; see SaveGame.lock_hints_after), and HINT warns
## about it in red before giving one. As every NUDGE_EVERY-th retry starts,
## Sheldon reminds the player that hints are there (skipped if they took one
## lately), or, where there's none to give, to try another way.
## Hints a stage cues itself (see level_2_2.gd) play as well.

## Restarts per stage this session. Static, so it survives scene reloads.
static var _restarts := {}
## Per stage: the hint part to give next, and the retry the last one was taken on.
static var _hint_part := {}
static var _hint_taken_at := {}

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
## "SPEAKER: text" lines Sheldon gives as this stage's hint; a "---" line
## starts the next part (see the top of this script).
@export var hint_lines: PackedStringArray
## The notebook's LOG and HINT buttons work. Off on the very first stage.
@export var log_and_hint_enabled := true
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
## Splits hint_lines into parts.
const HINT_BREAK := "---"
## Every this many retries, Sheldon reminds the player about hints.
const NUDGE_EVERY := 5
const NUDGE_LINE := "SHELDON: You know, you can always use the hint feature in the notebook."
const NO_HINT_NUDGE_LINE := "SHELDON (squint): If something doesn't work, why not try another way?"
const HINT_COST_ONE := "YOU WON'T BE ABLE TO USE HINTS ON THE NEXT LEVEL."
const HINT_COST_MANY := "YOU WON'T BE ABLE TO USE HINTS ON THE NEXT %d LEVELS."
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
	hud.book.set_log_and_hint_enabled(log_and_hint_enabled)
	_update_hint_state()
	hud.book.restart_requested.connect(restart)
	hud.book.set_level_label(SaveGame.stage_label(stage_id))
	hud.dialogue.set_level_label(SaveGame.stage_label(stage_id))
	hud.book.set_can_skip(SaveGame.next_stage(stage_id) != "")
	hud.book.skip_requested.connect(_skip_level)
	hud.book.hint_requested.connect(show_hint)
	hud.dialogue.started.connect(player.set_held_by_dialogue.bind(true))
	hud.dialogue.finished.connect(func() -> void:
		player.set_held_by_dialogue(false)
		player.ignore_held_jump())
	hud.book.closed.connect(player.ignore_held_jump)
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


## The next part of this stage's hint from Sheldon (queued after anything
## already playing). It locks hints on a later level.
func show_hint() -> void:
	var parts := hint_parts()
	if parts.is_empty():
		return
	var part: int = _hint_part.get(stage_id, 0) % parts.size()
	_hint_part[stage_id] = part + 1
	_hint_taken_at[stage_id] = restart_count()
	SaveGame.lock_hints_after(stage_id)
	_update_hint_state()
	hud.dialogue.play(parts[part], &"hint")


## hint_lines split at each "---" line.
func hint_parts() -> Array[PackedStringArray]:
	var parts: Array[PackedStringArray] = []
	var part := PackedStringArray()
	for line in hint_lines:
		if line.strip_edges() == HINT_BREAK:
			if not part.is_empty():
				parts.append(part)
			part = PackedStringArray()
		else:
			part.append(line)
	if not part.is_empty():
		parts.append(part)
	return parts


## Whether HINT would give one here.
func hints_available() -> bool:
	return log_and_hint_enabled and not hint_lines.is_empty() and not SaveGame.hints_locked(stage_id)


## Tells the notebook whether there's a hint, whether it's locked, and what
## one more would cost.
func _update_hint_state() -> void:
	hud.book.has_hint = log_and_hint_enabled and not hint_lines.is_empty()
	hud.book.hints_locked = SaveGame.hints_locked(stage_id)
	var cost := SaveGame.hint_cost(stage_id)
	hud.book.hint_warning = "" if cost == 0 else (HINT_COST_ONE if cost == 1 else HINT_COST_MANY % cost)


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
	_forget_stage()
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


## As every NUDGE_EVERY-th retry starts: hints are there (unless one was taken
## in the last few retries), or, with none to give, try another way.
func _offer_hint(attempt: int) -> void:
	if not is_nudge_attempt(attempt):
		return
	if not hints_available():
		hud.dialogue.play(PackedStringArray([NO_HINT_NUDGE_LINE]))
	elif attempt - _hint_taken_at.get(stage_id, -NUDGE_EVERY) >= NUDGE_EVERY:
		hud.dialogue.play(PackedStringArray([NUDGE_LINE]), &"hint")


## Whether Sheldon says something about hints as this attempt starts.
static func is_nudge_attempt(attempt: int) -> bool:
	return attempt > 0 and attempt % NUDGE_EVERY == 0


## Cleared or skipped: retries and hint parts start over next time, and hints
## locked here are free again.
func _forget_stage() -> void:
	_restarts.erase(stage_id)
	_hint_part.erase(stage_id)
	_hint_taken_at.erase(stage_id)
	SaveGame.free_hints(stage_id)


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
	_forget_stage()
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
