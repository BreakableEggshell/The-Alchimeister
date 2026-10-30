extends CharacterBody2D
## Side-on platforming: run left/right, fixed-height jump, walks up ramps.
## A little coyote time and jump buffering keep jumps from being eaten.

# Frame ranges in the 8x8 knight sheet. The sheet has no jump pose, so
# airborne uses single run frames.
const IDLE_FIRST_FRAME := 0
const IDLE_FRAME_COUNT := 4
const RUN_FIRST_FRAME := 16
const RUN_FRAME_COUNT := 16
const RISING_FRAME := 18
const FALLING_FRAME := 22

## Top running speed in pixels per second.
@export var max_speed := 85.0
@export var ground_acceleration := 1000.0
## Lower than ground so mid-air steering is a bit softer.
@export var air_acceleration := 700.0
@export var friction := 1200.0
@export var gravity := 800.0
## How high a jump goes, in pixels (the knight is about 19px tall).
@export var jump_height := 50.0
@export var max_fall_speed := 300.0
## Seconds after walking off a ledge that a jump still works.
@export var coyote_time := 0.08
## Seconds a jump press is remembered before landing.
@export var jump_buffer_time := 0.1
@export var idle_fps := 4.0
@export var run_fps := 12.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _anim_clock := 0.0

@onready var _sprite: Sprite2D = $Sprite


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()

	var acceleration := ground_acceleration if on_floor else air_acceleration
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, (friction if on_floor else air_acceleration) * delta)

	if on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = -sqrt(2.0 * gravity * jump_height)
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	move_and_slide()
	_animate(delta, direction)


## Turns the knight left (negative) or right (positive); zero keeps its facing.
func face(direction_x: float) -> void:
	if direction_x != 0.0:
		_sprite.flip_h = direction_x < 0.0


func _animate(delta: float, direction: float) -> void:
	face(direction)
	_anim_clock += delta
	if not is_on_floor():
		_sprite.frame = RISING_FRAME if velocity.y < 0.0 else FALLING_FRAME
	elif absf(velocity.x) > 5.0:
		_sprite.frame = RUN_FIRST_FRAME + int(_anim_clock * run_fps) % RUN_FRAME_COUNT
	else:
		_sprite.frame = IDLE_FIRST_FRAME + int(_anim_clock * idle_fps) % IDLE_FRAME_COUNT
