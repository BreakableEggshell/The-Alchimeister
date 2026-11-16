class_name DialogueSpeaker
extends Resource
## A character who can talk in the dialogue box. Lines name them by `id`
## ("SHELDON: hello"). Make one .tres per character and add it to the
## dialogue box's `speakers` list.
## Expressions: a line can name one, "SHELDON (happy): hello". The portrait
## for it comes from `expressions`, or else from
## `portrait_folder`/`portrait_prefix`happy.png (e.g. knight_happy.png),
## so new expressions only need the image dropped into the character's
## folder. Unknown or no expression: `portrait` (the default). Keep every
## expression the same size as the default, so they line up.

enum Side { LEFT, RIGHT }

## The name lines use, e.g. "SHELDON". Matched case-insensitively.
@export var id := ""
## Shown above the text. Empty: the id.
@export var display_name := ""
@export var name_color := Color.WHITE
## The default portrait (no expression named).
@export var portrait: Texture2D
## Expression name (lowercase) -> portrait, for ones not in portrait_folder.
@export var expressions: Dictionary[String, Texture2D] = {}
## A folder of "<expression>.png" portraits, e.g. res://assets/portraits/sheldon.
@export_dir var portrait_folder := ""
## Put before the expression in file names, e.g. "knight_" for knight_happy.png.
@export var portrait_prefix := ""
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


## The portrait for `expression` ("" for the default).
func portrait_for(expression: String) -> Texture2D:
	expression = expression.strip_edges().to_lower()
	if expression == "" or expression == "default":
		return portrait
	if expressions.has(expression):
		return expressions[expression]
	if portrait_folder != "":
		var path := portrait_folder.path_join(portrait_prefix + expression + ".png")
		if ResourceLoader.exists(path):
			return load(path)
	push_warning("%s has no \"%s\" expression; using the default portrait." % [id, expression])
	return portrait
