extends Node
## Autoload "SaveGame": the level/stage structure, which stages are unlocked,
## the stage the player was last in (for Continue), potions discovered by
## brewing them, and settings (including auto hints). Everything
## is saved to user://save.cfg as soon as it changes.

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
## Restarts between automatic hints (when auto_hints is on).
const AUTO_HINT_EVERY := 5

var save_path := "user://save.cfg"
var unlocked: Array[String] = [FIRST_STAGE]
var last_stage := ""
## Discoverable potion kinds (see PotionData.DISCOVERABLE) brewed at least once.
var discovered_potions: Array[String] = []
var music_volume := 0.8
var sound_volume := 0.8
var fullscreen := false
## Sheldon gives the stage's hint by himself after every
## AUTO_HINT_EVERY restarts.
var auto_hints := false


func _ready() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	load_save()


func load_save() -> void:
	_set_defaults()
	var file := ConfigFile.new()
	if file.load(save_path) == OK:
		var saved: Array = file.get_value("progress", "unlocked", [FIRST_STAGE])
		unlocked.assign(saved)
		if not unlocked.has(FIRST_STAGE):
			unlocked.append(FIRST_STAGE)
		last_stage = file.get_value("progress", "last_stage", "")
		var potions: Array = file.get_value("progress", "discovered_potions", [])
		discovered_potions.assign(potions)
		music_volume = file.get_value("settings", "music_volume", music_volume)
		sound_volume = file.get_value("settings", "sound_volume", sound_volume)
		fullscreen = file.get_value("settings", "fullscreen", fullscreen)
		auto_hints = file.get_value("settings", "auto_hints", auto_hints)
	apply_settings()


func save() -> void:
	var file := ConfigFile.new()
	file.set_value("progress", "unlocked", unlocked)
	file.set_value("progress", "last_stage", last_stage)
	file.set_value("progress", "discovered_potions", discovered_potions)
	file.set_value("settings", "music_volume", music_volume)
	file.set_value("settings", "sound_volume", sound_volume)
	file.set_value("settings", "fullscreen", fullscreen)
	file.set_value("settings", "auto_hints", auto_hints)
	file.save(save_path)


## Wipes progress and settings.
func reset_all() -> void:
	_set_defaults()
	save()
	apply_settings()


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


func set_last_stage(stage: String) -> void:
	if last_stage != stage:
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


func play_stage(stage: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(STAGE_SCENES[stage])


func go_to(scene_path: String) -> void:
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


func set_auto_hints(value: bool) -> void:
	auto_hints = value
	save()


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
	music_volume = 0.8
	sound_volume = 0.8
	fullscreen = false
	auto_hints = false
