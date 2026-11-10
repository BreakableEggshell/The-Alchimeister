extends "res://scripts/puzzle/puzzle_level.gd"
## The last level, "The only way out": on the way to the Demon King's lair
## there's a gap to jump, but Sheldon always starts talking mid-jump (every
## attempt, LedgeTalk), and a conversation stops the knight dead in the air, so
## he drops into the pit below. That's on purpose. The pit can't be climbed
## out of (the ledges overhang it), and holds a chest of three random
## ingredients. That's the softlock, on
## purpose: the way out is to die, by setting yourself on fire with no water
## around or by brewing a Death potion (any mix that isn't a recipe). Doing
## so clears the level instead of restarting it. Being stuck any other way
## (potions wasted) still calls for a restart.
## The chest also holds the Death potion's recipe, the first time: Sheldon
## spots a note, it's shown (RecipeNote), and from then on it can be brewed.

const RECIPE_NOTE := preload("res://scripts/puzzle/recipe_note.gd")
## Seconds after dying before Sheldon speaks up.
const ESCAPE_BEAT := 1.0
const FOUND_LINES := [
	"SHELDON (squint): Of course it's just junk.",
	"SHELDON: But look, there's a mysterious note here. Is it a recipe?",
]
const AFTER_NOTE_LINES := ["SHELDON (glasses): Looks like there's a new potion we can brew."]

@export var chest: Node


func _ready() -> void:
	super()
	_fill_chest()
	chest.opened.connect(_on_chest_opened)


## Three random ingredients, always leaving a way out: an ember (fire) or at
## least two different kinds (which mix into a Death potion).
func _fill_chest() -> void:
	var picks: Array[StringName] = []
	while true:
		picks.clear()
		for i in 3:
			picks.append(PotionData.INGREDIENTS.pick_random())
		if picks.has(PotionData.EMBER) or picks.any(func(kind: StringName) -> bool: return kind != picks[0]):
			break
	chest.contents = String(picks[0])
	chest.amount = 1
	chest.extra_contents = String(picks[1])
	chest.extra_amount = 1
	chest.third_contents = String(picks[2])
	chest.third_amount = 1


## The first time (until the recipe is found): "just junk", then a note with
## the Death potion's recipe, then a new potion to brew. The game stays paused
## throughout.
func _on_chest_opened() -> void:
	if SaveGame.is_recipe_found(PotionData.DEATH):
		return
	var tree := get_tree()
	tree.paused = true
	await hud.dialogue.interrupt(PackedStringArray(FOUND_LINES), player)
	SaveGame.find_recipe(PotionData.DEATH)
	var note := RECIPE_NOTE.new()
	hud.add_child(note)
	await note.read()
	note.queue_free()
	await hud.dialogue.interrupt(PackedStringArray(AFTER_NOTE_LINES), player)
	if is_inside_tree():
		tree.paused = false


func _on_player_died(cause: StringName) -> void:
	if cause != GameOver.BURNED and cause != GameOver.DEATH_POTION:
		super(cause)
		return
	# That's the way out.
	_stop_play()
	hud.set_potions_enabled(false)
	await get_tree().create_timer(ESCAPE_BEAT).timeout
	_on_exit_reached()
