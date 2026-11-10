extends Node
## Autoload "SaveGame": the level/stage structure, which stages are unlocked,
## the stage the player was last in (for Continue), potions discovered by
## brewing them, and settings. Everything
## is saved to user://save.cfg as soon as it changes.

## A key binding changed (update anything showing a key's name).
signal controls_changed

const START_MENU := "res://scenes/menu/start_menu.tscn"
const LEVEL_SELECT := "res://scenes/menu/level_select.tscn"
## Seven levels. Levels 1 and 2 have stages; levels 3-7 are a single stage
## each (picked straight from level select). A level with no stages is always
## locked.
const LEVELS: Array[Dictionary] = [
	{"title": "TUTORIAL", "stages": ["1-1", "1-2", "1-3"]},
	{"title": "I'M AFFECTED TOO", "stages": ["2-1", "2-2"]},
	{"title": "THREE'S A CROWD", "stages": ["3"]},
	{"title": "HOT FOOT", "stages": ["4"]},
	{"title": "FALSE FLOORS", "stages": ["5"]},
	{"title": "RETURN TO SENDER", "stages": ["6"]},
	{"title": "THE ONLY WAY OUT", "stages": ["7"]},
]
const STAGE_SCENES := {
	"1-1": "res://scenes/levels/tutorial_1.tscn",
	"1-2": "res://scenes/levels/tutorial_2.tscn",
	"1-3": "res://scenes/levels/tutorial_3.tscn",
	"2-1": "res://scenes/levels/level_2_1.tscn",
	"2-2": "res://scenes/levels/level_2_2.tscn",
	"3": "res://scenes/levels/level_3.tscn",
	"4": "res://scenes/levels/level_4.tscn",
	"5": "res://scenes/levels/level_5.tscn",
	"6": "res://scenes/levels/level_6.tscn",
	"7": "res://scenes/levels/level_7.tscn",
}
const FIRST_STAGE := "1-1"
## Debug: free play with every mechanic, outside the levels and their progress.
const SANDBOX := "res://scenes/levels/sandbox.tscn"

var save_path := "user://save.cfg"
var unlocked: Array[String] = [FIRST_STAGE]
var last_stage := ""
## Discoverable potion kinds (see PotionData.DISCOVERABLE) brewed at least once.
var discovered_potions: Array[String] = []
## Potions in PotionData.RECIPE_TO_FIND whose recipe has been found.
var found_recipes: Array[String] = []
## Stages where HINT is locked. Each hint taken locks the next stage that isn't
## already (lock_hints_after); clearing or skipping a stage frees it.
var hint_locks: Array[String] = []
var music_volume := 0.8
var sound_volume := 0.8
var fullscreen := false
## Action name -> physical keycodes, for the actions in Controls.REMAPPABLE
## (see Controls). Empty until the player remaps something.
var key_bindings := {}
## The secret timer: started by START, counts whenever the game is open, and is
## revealed at the very end. Anything that jumps ahead (skipping a level, ALL
## LEVELS, the debug tools) ends the run.
var run_active := false
var run_seconds := 0.0
## Everyone who finished a full run: [{name, seconds}]. Kept through START and
## RESET, which only wipe progress.
var playtesters: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	load_save()


func _process(delta: float) -> void:
	if run_active:
		run_seconds += delta


func _exit_tree() -> void:
	if run_active:
		save()


func load_save() -> void:
	_set_defaults()
	playtesters = []
	var file := ConfigFile.new()
	if file.load(save_path) == OK:
		var saved: Array = file.get_value("progress", "unlocked", [FIRST_STAGE])
		unlocked.assign(saved)
		if not unlocked.has(FIRST_STAGE):
			unlocked.append(FIRST_STAGE)
		last_stage = file.get_value("progress", "last_stage", "")
		var potions: Array = file.get_value("progress", "discovered_potions", [])
		discovered_potions.assign(potions)
		found_recipes.assign(file.get_value("progress", "found_recipes", []))
		hint_locks.assign(file.get_value("progress", "hint_locks", []))
		music_volume = file.get_value("settings", "music_volume", music_volume)
		sound_volume = file.get_value("settings", "sound_volume", sound_volume)
		fullscreen = file.get_value("settings", "fullscreen", fullscreen)
		key_bindings = file.get_value("controls", "bindings", key_bindings)
		run_active = file.get_value("progress", "run_active", run_active)
		run_seconds = file.get_value("progress", "run_seconds", run_seconds)
		playtesters = file.get_value("playtesters", "finished", playtesters)
	apply_settings()
	Controls.apply(key_bindings)


func save() -> void:
	var file := ConfigFile.new()
	file.set_value("progress", "unlocked", unlocked)
	file.set_value("progress", "last_stage", last_stage)
	file.set_value("progress", "discovered_potions", discovered_potions)
	file.set_value("progress", "found_recipes", found_recipes)
	file.set_value("progress", "hint_locks", hint_locks)
	file.set_value("progress", "run_active", run_active)
	file.set_value("progress", "run_seconds", run_seconds)
	file.set_value("playtesters", "finished", playtesters)
	file.set_value("settings", "music_volume", music_volume)
	file.set_value("settings", "sound_volume", sound_volume)
	file.set_value("settings", "fullscreen", fullscreen)
	file.set_value("controls", "bindings", key_bindings)
	file.save(save_path)


## Whether START would lose anything.
func has_progress() -> bool:
	return unlocked.size() > 1 or last_stage != "" or not discovered_potions.is_empty() or not found_recipes.is_empty()


## START: wipes progress (not settings) and starts the secret timer.
func start_new_run() -> void:
	unlocked.assign([FIRST_STAGE])
	last_stage = ""
	discovered_potions.clear()
	found_recipes.clear()
	hint_locks.clear()
	run_active = true
	run_seconds = 0.0
	save()


## ALL LEVELS: every stage playable.
func unlock_all_levels() -> void:
	unlocked.assign(STAGE_SCENES.keys())
	run_active = false
	save()


## Moves on from `stage` without clearing it. That run no longer counts.
func skip_stage(stage: String, focus = null) -> void:
	var next := next_stage(stage)
	if next == "":
		return
	run_active = false
	unlock(next)
	save()
	play_stage(next, focus)


## Stops the secret timer at the end of the game. False if no run was going.
func finish_run() -> bool:
	if not run_active:
		return false
	run_active = false
	save()
	return true


## Saves who finished the run that just ended, and their time.
func record_playtester(player_name: String) -> void:
	playtesters.append({"name": player_name, "seconds": run_seconds})
	save()


func format_time(seconds: float) -> String:
	var total := int(seconds)
	if total >= 3600:
		return "%d:%02d:%02d" % [total / 3600, total / 60 % 60, total % 60]
	return "%d:%02d" % [total / 60, total % 60]


## Debug: every stage playable, every recipe found and every potion discovered.
func unlock_all() -> void:
	unlocked.assign(STAGE_SCENES.keys())
	run_active = false
	for kind in PotionData.DISCOVERABLE:
		if not is_potion_discovered(kind):
			discovered_potions.append(String(kind))
	for kind in PotionData.RECIPE_TO_FIND:
		if not found_recipes.has(String(kind)):
			found_recipes.append(String(kind))
	save()


## Wipes progress and settings.
func reset_all() -> void:
	_set_defaults()
	save()
	apply_settings()
	Controls.apply(key_bindings)
	controls_changed.emit()


# --- Progress

func is_unlocked(stage: String) -> bool:
	return unlocked.has(stage)


func unlock(stage: String) -> void:
	if stage != "" and not unlocked.has(stage):
		unlocked.append(stage)
		save()


func is_potion_discovered(kind: StringName) -> bool:
	return discovered_potions.has(String(kind))


## False for a discoverable potion the player hasn't brewed yet.
func is_potion_known(kind: StringName) -> bool:
	return not PotionData.DISCOVERABLE.has(kind) or is_potion_discovered(kind)


## Returns true if this was the first time.
func discover_potion(kind: StringName) -> bool:
	if is_potion_discovered(kind):
		return false
	discovered_potions.append(String(kind))
	save()
	return true


## Whether `kind` can be brewed: its recipe needn't be found, has been, or it
## was brewed before (older saves).
func is_recipe_found(kind: StringName) -> bool:
	return not PotionData.RECIPE_TO_FIND.has(kind) or found_recipes.has(String(kind)) or is_potion_discovered(kind)


## Returns true if this was the first time.
func find_recipe(kind: StringName) -> bool:
	if found_recipes.has(String(kind)):
		return false
	found_recipes.append(String(kind))
	save()
	return true


# --- Hint locks

func hints_locked(stage: String) -> bool:
	return hint_locks.has(stage)


## A hint was taken on `stage`: the first stage after it that isn't locked yet
## loses its hints.
func lock_hints_after(stage: String) -> void:
	for later in _stages_after(stage):
		if not hint_locks.has(later):
			hint_locks.append(later)
			save()
			return


## How many stages in a row after `stage` would be without hints if one more
## were taken there. 0 if every later stage is locked already (or none left).
func hint_cost(stage: String) -> int:
	var later := _stages_after(stage)
	if later.all(func(other: String) -> bool: return hint_locks.has(other)):
		return 0
	var run := 0
	var added := false
	for other in later:
		if hint_locks.has(other):
			run += 1
		elif not added:
			added = true
			run += 1
		else:
			break
	return run


## `stage` was cleared or skipped: hints there are free again.
func free_hints(stage: String) -> void:
	if hint_locks.has(stage):
		hint_locks.erase(stage)
		save()


func _stages_after(stage: String) -> Array[String]:
	var stages := all_stages()
	var at := stages.find(stage)
	var later: Array[String] = []
	if at >= 0:
		later.assign(stages.slice(at + 1))
	return later


func set_last_stage(stage: String) -> void:
	if STAGE_SCENES.has(stage) and last_stage != stage:
		last_stage = stage
		save()


func has_last_stage() -> bool:
	return STAGE_SCENES.has(last_stage)


## The stage after `stage`: the next one in its level, or the first stage of
## the next level that has any. "" after the very last stage.
func next_stage(stage: String) -> String:
	var level := level_of(stage)
	if level < 0:
		return ""
	var stages: Array = LEVELS[level].stages
	var i := stages.find(stage)
	if i + 1 < stages.size():
		return stages[i + 1]
	for later in range(level + 1, LEVELS.size()):
		if not LEVELS[later].stages.is_empty():
			return LEVELS[later].stages[0]
	return ""


## Index into LEVELS of the level holding `stage`, or -1.
func level_of(stage: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i].stages.has(stage):
			return i
	return -1


## Whether `stage` is the last one in its level.
func is_last_in_level(stage: String) -> bool:
	var level := level_of(stage)
	return level >= 0 and LEVELS[level].stages.back() == stage


func is_level_unlocked(level_index: int) -> bool:
	var stages: Array = LEVELS[level_index].stages
	return not stages.is_empty() and is_unlocked(stages[0])


## Every stage in play order.
func all_stages() -> Array[String]:
	var stages: Array[String] = []
	for level in LEVELS:
		stages.append_array(level.stages)
	return stages


## "1 - 2": which group of levels a stage is in, and its place in that group.
func stage_code(stage: String) -> String:
	var level := level_of(stage)
	return "%d - %d" % [level + 1, LEVELS[level].stages.find(stage) + 1] if level >= 0 else ""


## How the notebook and dialogue name a stage: "LEVEL 5 (2 - 2)".
func stage_label(stage: String) -> String:
	var number := stage_number(stage)
	return "LEVEL %d (%s)" % [number, stage_code(stage)] if number > 0 else "SANDBOX"


## The number the player knows a stage by (1 for the first, and so on).
func stage_number(stage: String) -> int:
	return all_stages().find(stage) + 1


## Iris in on `focus` (screen pixels; null for the middle), then the stage,
## which opens with an iris out when it starts.
func play_stage(stage: String, focus = null) -> void:
	_enter_scene(STAGE_SCENES[stage], focus)


func play_sandbox() -> void:
	_enter_scene(SANDBOX, null)


func _enter_scene(path: String, focus) -> void:
	if Iris.is_closed:
		return
	save()
	get_tree().paused = true
	await Iris.close(focus)
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func go_to(scene_path: String) -> void:
	Iris.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)


# --- Settings

func set_music_volume(value: float) -> void:
	music_volume = value
	apply_settings()
	save()


func set_sound_volume(value: float) -> void:
	sound_volume = value
	apply_settings()
	save()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_settings()
	save()


## Binds `action` to `key` and saves (see Controls.rebind).
func rebind(action: StringName, key: int) -> void:
	Controls.rebind(action, key)
	key_bindings = Controls.current()
	save()
	controls_changed.emit()


func reset_controls() -> void:
	key_bindings = {}
	Controls.apply(key_bindings)
	save()
	controls_changed.emit()


func apply_settings() -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sound_volume)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _set_bus_volume(bus: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
		AudioServer.set_bus_mute(index, value <= 0.0)


func _set_defaults() -> void:
	unlocked.assign([FIRST_STAGE])
	last_stage = ""
	discovered_potions.clear()
	found_recipes.clear()
	hint_locks.clear()
	music_volume = 0.8
	sound_volume = 0.8
	fullscreen = false
	key_bindings = {}
	run_active = false
	run_seconds = 0.0
