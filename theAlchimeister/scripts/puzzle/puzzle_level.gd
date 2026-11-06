extends Node2D
## A puzzle stage. Sets up the stage bounds, plays the intro dialogue on the
## first attempt, restarts on R or shortly after the player is caught, and on
## reaching the exit unlocks the next stage and offers to go on.
## Once the player is out of potions with no way to get more, and hasn't yet
## got past the parts that need them, a red "PRESS R" line stays up.
## Each stage starts from its own inventory; nothing carries over.

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
@export var player: CharacterBody2D
@export var thrower: Node2D
@export var hud: Control
@export var inventory: Inventory
@export var backdrop: Node2D
## Seconds to show "caught" before restarting.
@export var restart_delay := 1.2
## After this many tries to throw with no potion picked, the potion slots
## blink until one is picked. 0 turns it off.
@export var highlight_slots_after_misses := 3
## Past this x (stage pixels) nothing left needs a potion, so running out
## doesn't call for a restart. 0 means NEAR_EXIT pixels before the exit.
@export var potions_needed_until_x := 0.0

const NEAR_EXIT := 48.0
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
	_on_stage_start.call_deferred(restart_count())


## How many times this stage has been restarted since it was last cleared.
func restart_count() -> int:
	return _restarts.get(stage_id, 0)


func restart() -> void:
	_restarts[stage_id] = restart_count() + 1
	get_tree().paused = false
	get_tree().reload_current_scene()


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


## Called once the stage is ready; `attempt` is 0 on the first try.
func _on_stage_start(attempt: int) -> void:
	if attempt == 0:
		hud.dialogue.play(intro_lines)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not player._dead:
		restart()
	elif _over and event.is_action_pressed("ui_accept") and SaveGame.next_stage(stage_id) != "":
		_go_next()


func _on_player_died(cause: StringName) -> void:
	_stop_play()
	hud.set_potions_enabled(false)
	var message := GameOver.message_of(cause)
	var subtitle := "%s\nRESTARTING..." % message if message != "" else "RESTARTING..."
	hud.show_banner(GameOver.title_of(cause), subtitle, GameOver.COLOR)
	await get_tree().create_timer(restart_delay).timeout
	restart()


func _on_exit_reached() -> void:
	_over = true
	_stop_play()
	player.set_physics_process(false)
	_restarts.erase(stage_id)
	var next := SaveGame.next_stage(stage_id)
	SaveGame.unlock(next)
	var level_done := SaveGame.is_last_in_level(stage_id)
	if level_done:
		var title: String = SaveGame.LEVELS[SaveGame.level_of(stage_id)].title
		hud.show_banner("%s COMPLETE" % (title if title != "" else "LEVEL"), "", Color(0.95, 0.85, 0.55))
	else:
		hud.show_banner("STAGE CLEAR", "", Color(0.95, 0.85, 0.55))
	hud.show_end_buttons(next != "", "NEXT LEVEL" if level_done else "NEXT STAGE")


func _go_next() -> void:
	SaveGame.play_stage(SaveGame.next_stage(stage_id))


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
