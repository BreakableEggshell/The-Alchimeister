class_name MapBackground
extends Control
## A picture (`picture`: the grassy map1.png, or the start menu's own) under a
## sky of drifting clouds, filling its parent. Behind the start menu and the
## level select. Clouds drift across the sky, each at its own pace, looping
## round: what drifts off one side comes back in on the other. With
## `new_heights`, each cloud comes back in at a different height every time
## round, somewhere above `sky_bottom`.
## Each cloud also casts a soft shadow that drifts along the grass with it.
## The shadows fall only on the picture's grass colours (GRASS_COLORS), so
## they pass behind anything standing on it, like the start menu's figures.

const BACKGROUND := preload("res://assets/map1.png")
const CLOUDS := preload("res://assets/map1_clouds.png")
## Each cloud in the cloud sheet, where it floats (its height, and where it
## starts across), and how fast it drifts in pixels per second. Smaller ones
## are further away, so they drift slower.
const CLOUD_LAYOUT: Array[Dictionary] = [
	{"region": Rect2(11, 10, 52, 25), "y": 6.0, "x": 20.0, "speed": 6.0},
	{"region": Rect2(82, 10, 59, 25), "y": 30.0, "x": 170.0, "speed": 4.5},
	{"region": Rect2(170, 16, 30, 13), "y": 50.0, "x": 300.0, "speed": 2.5},
	{"region": Rect2(234, 11, 51, 19), "y": 16.0, "x": 290.0, "speed": 3.5},
	# The same clouds again elsewhere, so no stretch of sky is left bare.
	{"region": Rect2(234, 11, 51, 19), "y": 42.0, "x": 40.0, "speed": 3.0},
	{"region": Rect2(170, 16, 30, 13), "y": 26.0, "x": 110.0, "speed": 2.0},
	{"region": Rect2(170, 16, 30, 13), "y": 58.0, "x": 200.0, "speed": 2.2},
]

## The picture's grass, the only thing cloud shadows fall on.
const GRASS_COLORS: Array[Color] = [Color8(168, 202, 89), Color8(112, 167, 66)]
## A shadow's colour (its strength is the alpha), how far right of its cloud
## it falls, and how flat it is.
const SHADOW_COLOR := Color(0.12, 0.2, 0.05, 0.28)
const SHADOW_OFFSET := 16.0
const SHADOW_SQUASH := 0.6
## Where shadows land on the grass: a cloud at the top of the sky casts its
## shadow at SHADOW_TOP, each pixel lower in the sky SHADOW_SPREAD further down.
const SHADOW_TOP := 86.0
const SHADOW_SPREAD := 1.8

## Each picture's grass mask, made once: grass opaque, everything else clear.
static var _grass_masks := {}

## What's drawn behind the clouds, stretched over the whole screen.
@export var picture: Texture2D = BACKGROUND
## Each time a cloud goes round, it comes back in at a new height.
@export var new_heights := false
## With new_heights: how low a cloud's bottom edge can go (where the sky
## meets the hills).
@export var sky_bottom := 46.0

## How far each cloud has drifted from where it starts.
var drift: Array[float] = []
## Draws the grass mask, which clips the shadows drawn by its child.
var _grass: Control
var _shadows: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cloud in CLOUD_LAYOUT:
		drift.append(0.0)
	_grass = Control.new()
	_grass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grass.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_grass.draw.connect(func() -> void: _grass.draw_texture_rect(_grass_mask(), Rect2(Vector2.ZERO, size), false))
	add_child(_grass)
	_shadows = Control.new()
	_shadows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shadows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadows.draw.connect(_draw_shadows)
	_grass.add_child(_shadows)


func _process(delta: float) -> void:
	for i in drift.size():
		drift[i] += CLOUD_LAYOUT[i].speed * delta
	queue_redraw()
	_shadows.queue_redraw()


## The map, then each cloud where it has drifted to. Whatever part of a cloud
## has gone off the right edge is already coming back in on the left. Not
## rounded to art pixels, so they glide smoothly.
func _draw() -> void:
	draw_texture_rect(picture, Rect2(Vector2.ZERO, size), false)
	var width := size.x
	for i in CLOUD_LAYOUT.size():
		var cloud: Dictionary = CLOUD_LAYOUT[i]
		var region: Rect2 = cloud.region
		var travelled: float = cloud.x + drift[i]
		var x := fposmod(travelled, width)
		# The copy leaving on the right is this time round; the one coming in
		# on the left is the next.
		var lap := floori(travelled / width)
		draw_texture_rect_region(CLOUDS, Rect2(Vector2(x, _height(i, lap)), region.size), region)
		draw_texture_rect_region(CLOUDS, Rect2(Vector2(x - width, _height(i, lap + 1)), region.size), region)


## Each cloud's shadow on the grass, drifting with it (clipped to the grass by
## its parent, so it only shows there).
func _draw_shadows() -> void:
	var width := size.x
	for i in CLOUD_LAYOUT.size():
		var cloud: Dictionary = CLOUD_LAYOUT[i]
		var region: Rect2 = cloud.region
		var travelled: float = cloud.x + drift[i] + SHADOW_OFFSET
		var x := fposmod(travelled, width)
		var lap := floori((cloud.x + drift[i]) / width)
		var shadow_size := Vector2(region.size.x, roundf(region.size.y * SHADOW_SQUASH))
		for at in [[x, lap], [x - width, lap + 1]]:
			var y := SHADOW_TOP + _height(i, at[1]) * SHADOW_SPREAD
			_shadows.draw_texture_rect_region(CLOUDS, Rect2(Vector2(at[0], y), shadow_size), region, SHADOW_COLOR)


## The picture's grass as a mask (see GRASS_COLORS), made the first time it's
## needed.
func _grass_mask() -> Texture2D:
	if _grass_masks.has(picture):
		return _grass_masks[picture]
	var source := picture.get_image()
	source.decompress()
	var mask := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x, y)
			for grass in GRASS_COLORS:
				if color.is_equal_approx(grass):
					mask.set_pixel(x, y, Color.WHITE)
					break
	var texture := ImageTexture.create_from_image(mask)
	_grass_masks[picture] = texture
	return texture


## Where cloud `i` floats on its `lap`th time across: where CLOUD_LAYOUT puts
## it, or with new_heights, a height picked for that lap (the same every time
## it's asked, so a cloud doesn't flicker).
func _height(i: int, lap: int) -> float:
	var cloud: Dictionary = CLOUD_LAYOUT[i]
	if not new_heights:
		return cloud.y
	var pick := RandomNumberGenerator.new()
	pick.seed = hash([i, lap])
	var region: Rect2 = cloud.region
	return roundf(pick.randf_range(0.0, maxf(sky_bottom - region.size.y, 0.0)))
