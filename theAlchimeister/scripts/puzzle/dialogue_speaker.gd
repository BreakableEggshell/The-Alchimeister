class_name DialogueSpeaker
extends Resource
## A character who can talk in the dialogue box. Lines name them by `id`
## ("SHELDON: hello"). Make one .tres per character and add it to the
## dialogue box's `speakers` list.

enum Side { LEFT, RIGHT }

## The name lines use, e.g. "SHELDON". Matched case-insensitively.
@export var id := ""
## Shown above the text. Empty: the id.
@export var display_name := ""
@export var name_color := Color.WHITE
@export var portrait: Texture2D
## Mirrors the portrait, e.g. to face the other side of the screen.
@export var flip_h := false
## Which side of the screen they stand on.
@export var side := Side.LEFT
@export var portrait_scale := 1.0
## Where the portrait's centre sits, measured from the bottom corner of its
## side: x inwards from the screen edge, y upwards from the bottom. Values
## that push it past the edge crop it, which suits half-drawn sprites.
@export var portrait_center := Vector2(60, 60)
## Stands in every conversation, even ones where they don't speak
## (the player character, listening).
@export var always_on_stage := false


func shown_name() -> String:
	return display_name if display_name != "" else id
