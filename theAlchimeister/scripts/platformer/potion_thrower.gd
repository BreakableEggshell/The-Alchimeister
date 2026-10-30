extends Node2D
## Slingshot-style potion throwing. Press anywhere on screen, drag to pull back,
## release to throw the potion the opposite way. Releasing over the cancel
## zone (top right) cancels the throw. Touch works through mouse emulation.
## With an inventory, throws its selected potion and only while any are left;
## without one, throws unlimited plain potions.

@export var thrower: CharacterBody2D
@export var cancel_zone: Control
@export var inventory: Inventory
## Where the potion leaves from, relative to the thrower's feet.
@export var hand_offset := Vector2(0, -14)
## Drag distance (screen pixels) that gives full power.
@export var max_pull := 60.0
## Drags shorter than this count as a tap and throw nothing.
@export var min_pull := 6.0
@export var max_launch_speed := 340.0
@export var potion_gravity := 400.0
## Seconds of flight shown by the dotted aim preview.
@export var preview_time := 0.6
@export var band_color := Color(0.95, 0.85, 0.55, 0.6)
@export var dot_color := Color(1, 1, 1, 0.9)

var _aiming := false
## Where the press started, in viewport (screen) space, so a scrolling camera
## doesn't drag the anchor along with the world.
var _anchor_screen := Vector2.ZERO
## Latest pointer position from input events, in viewport (screen) space.
var _pointer_screen := Vector2.ZERO
var _preview := PackedVector2Array()


func _ready() -> void:
	cancel_zone.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer_screen = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_screen = event.position
		if event.pressed:
			if inventory and inventory.count(inventory.selected) <= 0:
				inventory.take_selected()  # Reports "none left".
				return
			_aiming = true
			_anchor_screen = _pointer_screen
			cancel_zone.show()
		elif _aiming:
			_release()


## Drops any aim in progress without throwing.
func cancel() -> void:
	_aiming = false
	_preview.clear()
	cancel_zone.hide()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	_preview.clear()
	if not _aiming:
		return
	var over_cancel := _over_cancel_zone()
	cancel_zone.modulate.a = 1.0 if over_cancel else 0.5
	if over_cancel or _pull().length() < min_pull:
		queue_redraw()
		return
	var launch := _launch_velocity()
	thrower.face(launch.x)
	# Step the same simulation the real potion uses so the preview is exact.
	var space := get_world_2d().direct_space_state
	var position_now := _hand_position()
	var velocity_now := launch
	var dt := 1.0 / Engine.physics_ticks_per_second
	for i in int(preview_time / dt):
		var result := Potion.step(space, position_now, velocity_now, potion_gravity, dt, [thrower.get_rid()], PotionData.POTION_HIT_MASK)
		position_now = result.position
		velocity_now = result.velocity
		_preview.append(position_now)
		if result.hit:
			break
	queue_redraw()


func _draw() -> void:
	if not _aiming:
		return
	var to_world := get_canvas_transform().affine_inverse()
	var anchor := to_local(to_world * _anchor_screen)
	draw_circle(anchor, 2.0, band_color)
	draw_line(anchor, anchor - _pull(), band_color)
	var color := PotionData.color_of(inventory.selected) if inventory else dot_color
	for i in range(1, _preview.size(), 3):
		var fade := 1.0 - 0.7 * float(i) / _preview.size()
		draw_circle(to_local(_preview[i]), 1.5, Color(color, dot_color.a * fade))


## Vector from the pointer back to the press point, capped at max_pull.
## This is the direction the potion flies.
func _pull() -> Vector2:
	return (_anchor_screen - _pointer_screen).limit_length(max_pull)


func _launch_velocity() -> Vector2:
	return _pull() * (max_launch_speed / max_pull)


func _hand_position() -> Vector2:
	return thrower.global_position + hand_offset


func _over_cancel_zone() -> bool:
	return cancel_zone.get_global_rect().has_point(_pointer_screen)


func _release() -> void:
	var cancelled := _over_cancel_zone() or _pull().length() < min_pull
	var launch := _launch_velocity()
	cancel()
	if cancelled:
		return
	var potion := Potion.new()
	if inventory:
		if not inventory.take_selected():
			return
		potion.kind = inventory.selected
	potion.velocity = launch
	potion.gravity = potion_gravity
	potion.exclude = [thrower.get_rid()]
	get_parent().add_child(potion)
	potion.global_position = _hand_position()
