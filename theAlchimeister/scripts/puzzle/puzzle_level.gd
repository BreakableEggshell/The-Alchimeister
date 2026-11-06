extends Node2D
## A puzzle stage. Sets up the stage bounds, plays the intro dialogue on the
## first attempt, restarts on R or shortly after the player is caught, and on
## reaching the exit unlocks the next stage and offers to go on.
## Each stage starts from its own inventory; nothing carries over.

## Restarts per stage this session. Static, so it survives scene reloads.
static var _restarts := {}

@export var stage_id := "1-1"
## Width and height of the playable area, in pixels.
@export var stage_size := Vector2(384, 216)
@export var throwing_enabled := true
## "SPEAKER: text" lines played when the stage is first entered.
@export var intro_lines: PackedStringArray
@export var player: CharacterBody2D
@export var thrower: Node2D
@export var hud: Control
@export var inventory: Inventory
@export var backdrop: Node2D
## Seconds to show "caught" before restarting.
@export var restart_delay := 1.2

var _over := false


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
	thrower.set_process_unhandled_input(throwing_enabled)
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


## Called once the stage is ready; `attempt` is 0 on the first try.
func _on_stage_start(attempt: int) -> void:
	if attempt == 0:
		hud.dialogue.play(intro_lines)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not player._dead:
		restart()
	elif _over and event.is_action_pressed("ui_accept") and SaveGame.next_stage(stage_id) != "":
		_go_next()


func _on_player_died() -> void:
	_stop_play()
	hud.show_banner("CAUGHT!", "RESTARTING...", Color(1, 0.45, 0.45))
	await get_tree().create_timer(restart_delay).timeout
	restart()


func _on_exit_reached() -> void:
	_over = true
	_stop_play()
	player.set_physics_process(false)
	_restarts.erase(stage_id)
	var next := SaveGame.next_stage(stage_id)
	SaveGame.unlock(next)
	if next != "":
		hud.show_banner("STAGE CLEAR", "", Color(0.95, 0.85, 0.55))
	else:
		hud.show_banner("TUTORIAL COMPLETE", "", Color(0.95, 0.85, 0.55))
	hud.show_end_buttons(next != "")


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
