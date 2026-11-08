class_name Inventory
extends Node
## The player's potions and ingredients for one stage. Nothing carries over
## between stages. Ingredients are brewed into potions by hand in the book.

signal changed
signal selected_changed(kind: StringName)
## Something worth telling the player (a pickup, an empty slot).
signal message(text: String, color: Color)
## Tried to throw with no potion picked.
signal pick_missed

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
## Empty until the player picks a potion; nothing is selected at stage start.
var selected: StringName = &""
## Ingredient kinds in the order they were first picked up, so storage boxes
## keep their places.
var ingredient_order: Array[StringName] = []

var _potions := {}
var _ingredients := {}


func _ready() -> void:
	add_to_group("inventory")
	_potions = {
		PotionData.FIRE: start_fire,
		PotionData.KNOCKBACK: start_knockback,
		PotionData.FREEZE: start_freeze,
		PotionData.TRANSLUCENT: start_translucent,
		PotionData.DEATH: 0,
	}


func count(kind: StringName) -> int:
	return _potions.get(kind, 0)


## Whether the potion bar and the book's potion counts list this kind.
## Discoverable potions (Death) only appear while you hold at least one.
func is_shown(kind: StringName) -> bool:
	return not PotionData.DISCOVERABLE.has(kind) or count(kind) > 0


func ingredient_count(kind: StringName) -> int:
	return _ingredients.get(kind, 0)


func select(kind: StringName) -> void:
	selected = kind
	changed.emit()
	selected_changed.emit(kind)


## Uses up one of the selected potion. Returns false (and says why) if it can't.
func take_selected() -> bool:
	if selected == &"":
		message.emit("PICK A POTION FIRST", Color(1, 0.5, 0.5))
		pick_missed.emit()
		return false
	if count(selected) <= 0:
		message.emit("NO %s POTIONS LEFT" % PotionData.NAMES[selected], Color(1, 0.5, 0.5))
		return false
	_potions[selected] -= 1
	# The last one of a potion that vanishes from the bar can't stay selected.
	if not is_shown(selected):
		selected = &""
	changed.emit()
	return true


func add_ingredient(kind: StringName, amount := 1) -> void:
	for i in amount:
		_store(kind)
	Sfx.play(Sfx.PICKUP, self)
	message.emit("+%d %s" % [amount, PotionData.INGREDIENT_NAMES[kind]], PotionData.INGREDIENT_COLORS[kind])
	changed.emit()


## Takes one ingredient out of storage (onto the crafting table).
func take_ingredient(kind: StringName) -> bool:
	if ingredient_count(kind) <= 0:
		return false
	_ingredients[kind] -= 1
	changed.emit()
	return true


## Puts one ingredient back into storage (off the crafting table).
func return_ingredient(kind: StringName) -> void:
	_store(kind)
	changed.emit()


## What these table ingredients brew into, ignoring order and empty entries:
## {potion, amount}. A table holding k copies of a recipe makes k potions, so
## 3 Frost Shards make 3 Freeze potions. Any other mix makes one Death
## potion, except one of every ingredient: that is the secret recipe, which
## can't be brewed yet (PotionData.SECRET, amount 0). Empty table: empty potion.
func match_recipe(kinds: Array) -> Dictionary:
	var tally := {}
	for kind in kinds:
		if kind != &"":
			tally[kind] = tally.get(kind, 0) + 1
	if not tally.is_empty():
		for potion in recipes:
			var recipe: Dictionary = recipes[potion]
			if recipe.size() != tally.size():
				continue
			var first: StringName = recipe.keys()[0]
			var copies: int = tally.get(first, 0) / recipe[first]
			if copies >= 1 and recipe.keys().all(func(ingredient) -> bool: return tally.get(ingredient, 0) == recipe[ingredient] * copies):
				return {"potion": potion, "amount": copies}
		if tally.size() == PotionData.INGREDIENTS.size() and PotionData.INGREDIENTS.all(func(ingredient) -> bool: return tally.get(ingredient, 0) == 1):
			return {"potion": PotionData.SECRET, "amount": 0}
		return {"potion": PotionData.DEATH, "amount": 1}
	return {"potion": &"", "amount": 0}


## Adds brewed potions. The ingredients were already taken onto the table.
func brew(potion: StringName, amount := 1) -> void:
	_potions[potion] += amount
	changed.emit()


func _store(kind: StringName) -> void:
	if not ingredient_order.has(kind):
		ingredient_order.append(kind)
	_ingredients[kind] = ingredient_count(kind) + 1
