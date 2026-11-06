class_name PotionData
extends RefCounted
## Shared facts about potion kinds: names, colours, effect tuning, and the
## procedural icons used for potions and ingredients.

const FIRE := &"fire"
const KNOCKBACK := &"knockback"
const FREEZE := &"freeze"
const TRANSLUCENT := &"translucent"
const KINDS: Array[StringName] = [FIRE, KNOCKBACK, FREEZE, TRANSLUCENT]

const NAMES := {
	FIRE: "FIRE",
	KNOCKBACK: "KNOCKBACK",
	FREEZE: "FREEZE",
	TRANSLUCENT: "TRANSLUCENT",
}
const COLORS := {
	FIRE: Color(1.0, 0.45, 0.15),
	KNOCKBACK: Color(0.55, 0.95, 0.45),
	FREEZE: Color(0.45, 0.85, 1.0),
	TRANSLUCENT: Color(0.85, 0.75, 1.0, 0.75),
}
## Colour for a potion with no kind (the plain prototype potion).
const PLAIN_COLOR := Color(0.55, 0.95, 0.45)

## Ingredient kinds, their names and colours.
const EMBER := &"ember"
const GUST_FEATHER := &"gust_feather"
const FROST_SHARD := &"frost_shard"
const GHOST_WISP := &"ghost_wisp"
const INGREDIENT_NAMES := {
	EMBER: "EMBER",
	GUST_FEATHER: "GUST FEATHER",
	FROST_SHARD: "FROST SHARD",
	GHOST_WISP: "GHOST WISP",
}
const INGREDIENT_COLORS := {
	EMBER: Color(1.0, 0.55, 0.2),
	GUST_FEATHER: Color(0.75, 1.0, 0.7),
	FROST_SHARD: Color(0.6, 0.9, 1.0),
	GHOST_WISP: Color(0.85, 0.8, 1.0),
}

## Effect tuning.
const SPLASH_RADIUS := 22.0
const BURN_TIME := 3.0
const FREEZE_TIME := 6.0
const TRANSLUCENT_TIME := 6.0
## Seconds a monster is dazed (still and harmless) after a knockback hit.
const STUN_TIME := 3.0
const KNOCKBACK_SPEED := 230.0
const KNOCKBACK_LIFT := 120.0

## Physics layers (bit values), named in project settings.
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMIES := 4
const LAYER_PROPS := 8
## Areas around enemies, larger than their bodies, that only potions hit.
const LAYER_POTION_TARGETS := 16
## What a flying potion shatters on.
const POTION_HIT_MASK := LAYER_WORLD | LAYER_ENEMIES | LAYER_PROPS | LAYER_POTION_TARGETS
## What a splash affects.
const SPLASH_MASK := LAYER_PLAYER | LAYER_ENEMIES | LAYER_PROPS


static func color_of(kind: StringName) -> Color:
	return COLORS.get(kind, PLAIN_COLOR)


## Velocity to give a body hit by a knockback splash centred at `origin`.
static func knockback_velocity(body_center: Vector2, origin: Vector2, strength := 1.0) -> Vector2:
	var away := body_center - origin
	var side := signf(away.x) if absf(away.x) > 0.5 else 1.0
	return Vector2(side * KNOCKBACK_SPEED, -KNOCKBACK_LIFT) * strength


## Draws a small potion flask centred at `at`.
static func draw_potion(canvas: CanvasItem, kind: StringName, at: Vector2) -> void:
	canvas.draw_rect(Rect2(at + Vector2(-1, -6), Vector2(2, 1)), Color(0.6, 0.4, 0.25))
	canvas.draw_rect(Rect2(at + Vector2(-1, -5), Vector2(2, 2)), Color(0.85, 0.9, 1.0))
	canvas.draw_circle(at, 3.0, Color(0.85, 0.9, 1.0))
	canvas.draw_circle(at + Vector2(0, 0.5), 2.2, color_of(kind))


## Draws a closed book (the recipe book button) centred at `at`.
static func draw_book_icon(canvas: CanvasItem, at: Vector2) -> void:
	canvas.draw_rect(Rect2(at + Vector2(-6, -6), Vector2(12, 12)), Color(0.55, 0.25, 0.17))
	canvas.draw_rect(Rect2(at + Vector2(-6, -6), Vector2(2, 12)), Color(0.38, 0.16, 0.11))
	canvas.draw_rect(Rect2(at + Vector2(-4, 5), Vector2(10, 1)), Color(0.94, 0.88, 0.74))
	canvas.draw_rect(Rect2(at + Vector2(-1, -3), Vector2(5, 1)), Color(0.95, 0.8, 0.35))
	canvas.draw_rect(Rect2(at + Vector2(3, -6), Vector2(2, 5)), Color(0.85, 0.25, 0.25))


## Draws a small padlock centred at `at`.
static func draw_lock_icon(canvas: CanvasItem, at: Vector2, color: Color) -> void:
	canvas.draw_arc(at + Vector2(0, -2), 3.0, PI, TAU, 8, color, 1.5)
	canvas.draw_rect(Rect2(at + Vector2(-4, -2), Vector2(8, 6)), color)
	canvas.draw_rect(Rect2(at + Vector2(-0.5, 0), Vector2(1, 2)), Color(0, 0, 0, 0.5))


## Draws a small ingredient icon centred at `at`.
static func draw_ingredient(canvas: CanvasItem, kind: StringName, at: Vector2) -> void:
	var color: Color = INGREDIENT_COLORS.get(kind, Color.WHITE)
	match kind:
		EMBER:
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -5), at + Vector2(3, 1), at + Vector2(0, 3), at + Vector2(-3, 1)]), color)
			canvas.draw_circle(at + Vector2(0, 1), 1.2, Color(1, 0.9, 0.4))
		GUST_FEATHER:
			canvas.draw_line(at + Vector2(-3, 4), at + Vector2(3, -4), color, 2.0)
			canvas.draw_line(at + Vector2(-3, 4), at + Vector2(-1, 1), Color.WHITE)
		FROST_SHARD:
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -5), at + Vector2(3, 0), at + Vector2(0, 5), at + Vector2(-3, 0)]), color)
			canvas.draw_line(at + Vector2(0, -4), at + Vector2(0, 4), Color.WHITE)
		GHOST_WISP:
			canvas.draw_circle(at + Vector2(0, -1), 3.0, color)
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-3, -1), at + Vector2(3, -1), at + Vector2(1, 5), at + Vector2(0, 2), at + Vector2(-1, 5)]), color)
			canvas.draw_rect(Rect2(at + Vector2(-2, -2), Vector2(1, 1)), Color(0.2, 0.15, 0.3))
			canvas.draw_rect(Rect2(at + Vector2(1, -2), Vector2(1, 1)), Color(0.2, 0.15, 0.3))
