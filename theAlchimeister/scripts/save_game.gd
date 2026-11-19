extends Node
## Autoload "SaveGame": the level/stage structure, which stages are unlocked,
## the stage the player was last in (for Continue), potions discovered by
## brewing them, and settings. Everything
## is saved to user://save.cfg as soon as it changes.

## A key binding changed (update anything showing a key's name).
signal controls_changed

const START_MENU := "res://scenes/menu/start_menu.tscn"
const LEVEL_SELECT := "res://scenes/menu/level_select.tscn"
## Played after START, before the first level.
const INTRO_COMIC := "res://scenes/menu/intro_comic.tscn"
## The levels, on five maps (`map`: which one). The first two levels have
## stages; the rest are a single stage each (picked straight from level
## select). A level with no stages is always locked. Stage ids are only names:
## the order here is the play order.
## Map 0 (PLAYABLE_MAP) is the game for now: it ends with "14" (THE ONLY WAY
## OUT), the end of the game. Map 1 (SECRET_MAP) is for later: clearing map 0
## doesn't lead into it, so its levels only open through the debug tools
## (unlock_all_levels). Maps 2, 3 and 4 (SPECIAL_MAP, PROTOTYPE_MAP,
## EXTRA_MAP) are for trying things out: levels with mechanics set aside, new
## ones being worked on, and longer ones putting them all together. Their
## levels are always open, and they're numbered on their own ("S1", "P1",
## "X1"; see MAP_PREFIX). Which of the later maps the level select shows is a
## debug setting (shown_maps).
const LEVELS: Array[Dictionary] = [
	{"title": "TUTORIAL", "stages": ["1-1", "1-2", "1-3"], "map": 0},
	{"title": "I'M AFFECTED TOO", "stages": ["2-1", "2-2"], "map": 0},
	{"title": "THREE'S A CROWD", "stages": ["3"], "map": 0},
	{"title": "HOT FOOT", "stages": ["4"], "map": 0},
	{"title": "FALSE FLOORS", "stages": ["5"], "map": 0},
	{"title": "RETURN TO SENDER", "stages": ["6"], "map": 0},
	{"title": "THE ONLY WAY OUT", "stages": ["14"], "map": 0},
	{"title": "MELTDOWN", "stages": ["7"], "map": 1},
	{"title": "HIGH FLYERS", "stages": ["8"], "map": 1},
	{"title": "GHOST GATES", "stages": ["10"], "map": 1},
	{"title": "DOOR TO DOOR", "stages": ["11"], "map": 1},
	{"title": "BLAST RADIUS", "stages": ["13"], "map": 1},
	{"title": "SPRING LOADED", "stages": ["9"], "map": 2},
	{"title": "DON'T LOOK", "stages": ["12"], "map": 2},
	{"title": "SLOW BURN", "stages": ["P1"], "map": 3},
	{"title": "CUT THE ROPE", "stages": ["P2"], "map": 3},
	{"title": "COLD FEET", "stages": ["P3"], "map": 3},
	{"title": "SPREAD THE FIRE", "stages": ["P4"], "map": 3},
	{"title": "LET OFF STEAM", "stages": ["P5"], "map": 3},
	{"title": "SECOND WIND", "stages": ["P6"], "map": 3},
	{"title": "HOT STEPPING", "stages": ["P7"], "map": 3},
	{"title": "FIRE GOES LAST", "stages": ["P8"], "map": 3},
	{"title": "SPRING BACK", "stages": ["P9"], "map": 3},
	{"title": "BANK SHOT", "stages": ["P10"], "map": 3},
	{"title": "THE DEMON LORD", "stages": ["P11", "P12", "P13"], "map": 3},
	{"title": "SMOKE SIGNALS", "stages": ["X1"], "map": 4},
	{"title": "RICOCHET", "stages": ["X2"], "map": 4},
	{"title": "GHOST TOWN", "stages": ["X3"], "map": 4},
]
## How many maps the level select has.
const MAP_COUNT := 5
## The map that's the game for now; speedrun times only count its levels.
const PLAYABLE_MAP := 0
## The later levels players can't reach yet.
const SECRET_MAP := 1
## Levels whose mechanics were set aside.
const SPECIAL_MAP := 2
## New levels being tried out.
const PROTOTYPE_MAP := 3
## Longer levels putting everything so far together.
const EXTRA_MAP := 4
## Each map's name (level select, level preview, the debug toggles).
const MAP_NAMES: Array[String] = ["MAP 1", "SECRET LEVELS", "SPECIAL", "PROTOTYPES", "EXTRA PROTOTYPES"]
## Shorter names, for the level preview's row of section tabs.
const MAP_SHORT_NAMES: Array[String] = ["MAP 1", "SECRET", "SPECIAL", "PROTOTYPES", "EXTRA"]
## Maps numbered on their own: their stages are "S1", "S2" (and "SPECIAL 1"
## in game). Their levels are always open.
const MAP_PREFIX := {SPECIAL_MAP: "S", PROTOTYPE_MAP: "P", EXTRA_MAP: "X"}
const MAP_STAGE_NAMES := {SPECIAL_MAP: "SPECIAL", PROTOTYPE_MAP: "PROTOTYPE", EXTRA_MAP: "EXTRA"}
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
	"8": "res://scenes/levels/level_8.tscn",
	"9": "res://scenes/levels/level_9.tscn",
	"10": "res://scenes/levels/level_10.tscn",
	"11": "res://scenes/levels/level_11.tscn",
	"12": "res://scenes/levels/level_12.tscn",
	"13": "res://scenes/levels/level_13.tscn",
	"14": "res://scenes/levels/level_14.tscn",
	"P1": "res://scenes/levels/proto_1.tscn",
	"P2": "res://scenes/levels/proto_2.tscn",
	"P3": "res://scenes/levels/proto_3.tscn",
	"P4": "res://scenes/levels/proto_4.tscn",
	"P5": "res://scenes/levels/proto_5.tscn",
	"P6": "res://scenes/levels/proto_6.tscn",
	"P7": "res://scenes/levels/proto_7.tscn",
	"P8": "res://scenes/levels/proto_8.tscn",
	"P9": "res://scenes/levels/proto_9.tscn",
	"P10": "res://scenes/levels/proto_10.tscn",
	"P11": "res://scenes/levels/proto_11.tscn",
	"P12": "res://scenes/levels/proto_12.tscn",
	"P13": "res://scenes/levels/proto_13.tscn",
	"X1": "res://scenes/levels/extra_1.tscn",
	"X2": "res://scenes/levels/extra_2.tscn",
	"X3": "res://scenes/levels/extra_3.tscn",
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
## This run's splits: stage -> run_seconds when it was first cleared.
var run_splits := {}
## The pause menu's debug tools, opened with the DebugCode. Not saved: they
## last until the player goes back to the start menu.
var debug_unlocked := false
## Debug: the pause menu shows SKIP LEVEL.
var debug_skip_level := false
## Debug: the knight runs DEBUG_SPEED_BOOST times as fast.
var debug_speed_boost := false
const DEBUG_SPEED_BOOST := 2.0
## The start menu left under a black screen (CONTINUE): the level select
## slides in from the right, pushing the black off, instead of just appearing.
var slide_in_level_select := false
## The level select left under a black screen (BACK): the start menu's black
## slides off to the right and its buttons slide back in from the left.
var slide_in_start_menu := false
## Debug (the level select's own debug menu): which of the later maps the
## level select shows (map -> bool). The first map always shows. Saved; kept
## through RESET. To start with, only the secret map shows (as COMING SOON
## until its levels are unlocked).
var shown_maps := {}
const DEFAULT_SHOWN_MAPS := {SECRET_MAP: true, SPECIAL_MAP: false, PROTOTYPE_MAP: false, EXTRA_MAP: false}
## Everyone who finished a full run: [{name, seconds, splits, date}] (runs
## from before splits and dates were kept have neither). Kept through START and RESET, which only
## wipe progress.
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
	shown_maps = DEFAULT_SHOWN_MAPS.duplicate()
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
		run_splits = file.get_value("progress", "run_splits", run_splits)
		playtesters = file.get_value("playtesters", "finished", playtesters)
		shown_maps.merge(file.get_value("debug", "shown_maps", {}), true)
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
	file.set_value("progress", "run_splits", run_splits)
	file.set_value("playtesters", "finished", playtesters)
	file.set_value("debug", "shown_maps", shown_maps)
	file.set_value("settings", "music_volume", music_volume)
	file.set_value("settings", "sound_volume", sound_volume)
	file.set_value("settings", "fullscreen", fullscreen)
	file.set_value("controls", "bindings", key_bindings)
	file.save(save_path)


## START: wipes progress (not settings) and starts the secret timer.
func start_new_run() -> void:
	unlocked.assign([FIRST_STAGE])
	last_stage = ""
	discovered_potions.clear()
	found_recipes.clear()
	hint_locks.clear()
	run_active = true
	run_seconds = 0.0
	run_splits = {}
	save()


## ALL LEVELS: every stage playable, the later map's too, which players
## can't reach yet.
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


## Notes the run's time when `stage` is cleared for the first time this run.
func mark_split(stage: String) -> void:
	if run_active and not run_splits.has(stage):
		run_splits[stage] = run_seconds
		save()


## How long each playable stage (the first map's) took in a finished run:
## [[stage, seconds]] in play order, each from the clear before it (or the
## start) to its own. Runs from when the later map's levels were part of the
## game have those left out. Empty for runs from before splits were kept.
func stage_times(run: Dictionary) -> Array:
	var splits: Dictionary = run.get("splits", {})
	# In the order they were cleared, whatever order the levels are in now.
	var cleared: Array = splits.keys()
	cleared.sort_custom(func(a: String, b: String) -> bool: return splits[a] < splits[b])
	var took := {}
	var previous := 0.0
	for stage in cleared:
		took[stage] = splits[stage] - previous
		previous = splits[stage]
	var times := []
	for stage in map_stages(PLAYABLE_MAP):
		if took.has(stage):
			times.append([stage, took[stage]])
	return times


## A finished run's time over the playable levels only: its stage_times added
## up, or its whole time if it has no splits to go by.
func playable_seconds(run: Dictionary) -> float:
	var times := stage_times(run)
	if times.is_empty():
		return run.seconds
	var total := 0.0
	for entry in times:
		total += entry[1]
	return total


## Stops the secret timer at the end of the game. False if no run was going.
func finish_run() -> bool:
	if not run_active:
		return false
	run_active = false
	save()
	return true


## Saves who finished the run that just ended, and their time.
func record_playtester(player_name: String) -> void:
	playtesters.append({"name": player_name, "seconds": run_seconds, "splits": run_splits.duplicate(), "date": Time.get_date_string_from_system()})
	save()


## Gives a finished run a new name.
func rename_playtester(run: Dictionary, player_name: String) -> void:
	run.name = player_name
	save()


## Removes one finished run from the list for good.
func delete_playtester(run: Dictionary) -> void:
	playtesters.erase(run)
	save()


func format_time(seconds: float) -> String:
	var total := int(seconds)
	if total >= 3600:
		return "%d:%02d:%02d" % [total / 3600, total / 60 % 60, total % 60]
	return "%d:%02d" % [total / 60, total % 60]


## Debug: everything a player could reach unlocked, as if they'd played
## through: every stage on the playable map, every recipe found and every
## potion discovered. (The later map stays shut; that's ALL LEVELS.)
func unlock_all() -> void:
	for stage in map_stages(PLAYABLE_MAP):
		unlock(stage)
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
	return unlocked.has(stage) or MAP_PREFIX.has(map_of(stage))


## Whether the level select shows `map` (see shown_maps).
func is_map_shown(map: int) -> bool:
	return map == PLAYABLE_MAP or shown_maps.get(map, false)


func set_map_shown(map: int, shown: bool) -> void:
	shown_maps[map] = shown
	save()


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


## The stages after `stage` on its map, in play order.
func _stages_after(stage: String) -> Array[String]:
	var stages := map_stages(map_of(stage))
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


## Whether CONTINUE has anywhere to go: a level has been played, or more than
## the first one is open (as after the debug unlocks).
func can_continue() -> bool:
	return has_last_stage() or unlocked.size() > 1


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
	# On to the next level of the same map; a map's last stage leads nowhere.
	for later in range(level + 1, LEVELS.size()):
		if LEVELS[later].map != LEVELS[level].map:
			break
		if not LEVELS[later].stages.is_empty():
			return LEVELS[later].stages[0]
	return ""


## Which map `stage` is on (0 for the first), or -1.
func map_of(stage: String) -> int:
	var level := level_of(stage)
	return LEVELS[level].map if level >= 0 else -1


## Every stage on `map`, in play order.
func map_stages(map: int) -> Array[String]:
	var stages: Array[String] = []
	for level in LEVELS:
		if level.map == map:
			stages.append_array(level.stages)
	return stages


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


## How the notebook and dialogue name a stage: "LEVEL 5 (2 - 2)", or
## "PROTOTYPE 2" on a map numbered on its own.
func stage_label(stage: String) -> String:
	var number := stage_number(stage)
	if number <= 0:
		return "SANDBOX"
	var map := map_of(stage)
	if MAP_PREFIX.has(map):
		return "%s %d" % [MAP_STAGE_NAMES[map], number]
	return "LEVEL %d (%s)" % [number, stage_code(stage)]


## The number the player knows a stage by (1 for the first, and so on). The
## first two maps count on from each other; the others count from 1 each.
func stage_number(stage: String) -> int:
	var map := map_of(stage)
	if MAP_PREFIX.has(map):
		return map_stages(map).find(stage) + 1
	var stages := map_stages(PLAYABLE_MAP)
	stages.append_array(map_stages(SECRET_MAP))
	return stages.find(stage) + 1


## What a stage's level-select node says: "5", or "P2".
func stage_tag(stage: String) -> String:
	return MAP_PREFIX.get(map_of(stage), "") + str(stage_number(stage))


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


## Leaves for a menu behind an iris closing on `focus` (screen pixels; null
## for the middle). The menu opens it again (see StartMenu._ready).
func go_to_with_iris(scene_path: String, focus = null) -> void:
	_enter_scene(scene_path, focus)


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
	run_splits = {}
