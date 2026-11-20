extends "res://scripts/puzzle/puzzle_level.gd"
## FALSE FLOORS (level 8): the chest also holds the Death potion's recipe, the
## first time (until it's found): Sheldon spots a note, it's shown
## (RecipeNote), and from then on any mix that isn't a recipe brews a Death
## potion. The game stays paused throughout.

const RECIPE_NOTE := preload("res://scripts/puzzle/recipe_note.gd")
const FOUND_LINES := [
	"SHELDON: Hm? There's a note tucked in with the ingredients.",
	"SHELDON (squint): Is it a recipe?",
]
const AFTER_NOTE_LINES := ["SHELDON (glasses): Looks like there's a new potion we can brew."]

@export var chest: Node


func _ready() -> void:
	super()
	chest.opened.connect(_on_chest_opened)


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
