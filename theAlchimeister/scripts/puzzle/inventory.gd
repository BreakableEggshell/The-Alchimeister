class_name Inventory
extends Node
## The player's potions and ingredients for one stage. Ingredients brew into
## potions automatically as soon as a recipe is complete.

signal changed
## Something worth telling the player (a brew, an empty slot).
signal message(text: String, color: Color)

@export var start_fire := 0
@export var start_knockback := 0
@export var start_freeze := 0
@export var start_translucent := 0

## Potion kind -> {ingredient kind: amount needed}.
var recipes := {
	PotionData.FIRE: {PotionData.EMBER: 1},
	PotionData.KNOCKBACK: {PotionData.GUST_FEATHER: 1},
	PotionData.FREEZE: {PotionData.FROST_SHARD: 1},
	PotionData.TRANSLUCENT: {PotionData.GHOST_WISP: 1},
}
var selected: StringName = PotionData.FIRE

var _potions := {}
var _ingredients := {}


func _ready() -> void:
	add_to_group("inventory")
	_potions = {
		PotionData.FIRE: start_fire,
		PotionData.KNOCKBACK: start_knockback,
		PotionData.FREEZE: start_freeze,
		PotionData.TRANSLUCENT: start_translucent,
	}
	for kind in PotionData.KINDS:
		if _potions[kind] > 0:
			selected = kind
			break


func count(kind: StringName) -> int:
	return _potions.get(kind, 0)


func ingredient_count(kind: StringName) -> int:
	return _ingredients.get(kind, 0)


func select(kind: StringName) -> void:
	selected = kind
	changed.emit()


## Uses up one of the selected potion. Returns false (and says so) if none are left.
func take_selected() -> bool:
	if count(selected) <= 0:
		message.emit("NO %s POTIONS LEFT" % PotionData.NAMES[selected], Color(1, 0.5, 0.5))
		return false
	_potions[selected] -= 1
	changed.emit()
	return true


func add_ingredient(kind: StringName) -> void:
	_ingredients[kind] = ingredient_count(kind) + 1
	message.emit("+1 %s" % PotionData.INGREDIENT_NAMES[kind], PotionData.INGREDIENT_COLORS[kind])
	_brew()
	changed.emit()


func _brew() -> void:
	for potion in recipes:
		var recipe: Dictionary = recipes[potion]
		while recipe.keys().all(func(ingredient): return ingredient_count(ingredient) >= recipe[ingredient]):
			for ingredient in recipe:
				_ingredients[ingredient] -= recipe[ingredient]
			_potions[potion] += 1
			message.emit("BREWED +1 %s POTION" % PotionData.NAMES[potion], PotionData.color_of(potion))
