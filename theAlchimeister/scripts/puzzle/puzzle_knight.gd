extends "res://scripts/platformer/platformer_knight.gd"
## The platformer knight plus what the puzzle stages need: potion effects on
## the player, pushing crates, floating text above the head, and dying when
## caught.
## Fire: burns, runs much faster (PLAYER_FIRE_SPEED_BOOST, so jumps further), and dies after
## PotionData.PLAYER_BURN_TIME unless washed off in cleansing water.
## Freeze: can't move, jump or throw for PotionData.PLAYER_FREEZE_TIME.
## Knockback: flung away. Translucent: monsters pass through. Death: dies.
## Fire and freeze cancel each other; cleansing water clears them all.
## Running into ice (IcePillar) while burning melts it.

## `cause` is one of GameOver's causes; it picks the game over message.
signal died(cause: StringName)

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")

## Width of a remark above the head (see say()).
const REMARK_WIDTH := 170.0

## Speed the knight pushes crates at, in pixels per second.
@export var push_speed := 45.0

var _translucent_left := 0.0
var _burn_left := 0.0
var _freeze_left := 0.0
var _flames: CPUParticles2D
var _dead := false
var _talking := false
const FLOAT_TEXT_TIME := 0.5
## Death messages last through the iris closing.
const DEATH_TEXT_TIME := 1.5
## Screen pixels kept clear between float text and the screen's edge.
const FLOAT_MARGIN := 4.0
const SKULL_GAP := 3.0
const SKULL_ROWS: Array[String] = [
	".#######.",
	"#########",
	"##..#..##",
	"##..#..##",
	"#########",
	".###.###.",
	"..#####..",
	"..#.#.#..",
]

const BURN_FLASH_A := Color(1.5, 0.75, 0.45)
const BURN_FLASH_B := Color(1.3, 0.5, 0.3)
## Colour changes per second.
const BURN_FLASH_RATE := 12.0

var _burn_flash_clock := 0.0
var _held_by_dialogue := false
var _ignore_jump := false
var _float_label: Label
var _float_tween: Tween
## Beside the float text when it's a death message.
var _skull: Control
var _remark: RichTextLabel
var _remark_tween: Tween
var _chat_icon: Node2D
var _ice: Node2D
## max_speed before any fire boost.
var _base_max_speed := -1.0


func _ready() -> void:
	add_to_group("player")


## `power` scales knockback with how hard the potion was thrown.
func apply_potion(kind: StringName, origin: Vector2, power := 1.0) -> void:
	if _dead:
		return
	match kind:
		PotionData.KNOCKBACK:
			velocity = PotionData.knockback_velocity(global_position + Vector2(0, -8), origin, power)
		PotionData.TRANSLUCENT:
			_translucent_left = PotionData.TRANSLUCENT_TIME
		PotionData.FIRE:
			_freeze_left = 0.0
			_burn_left = PotionData.PLAYER_BURN_TIME
			float_text("[BURNING!]", PotionData.color_of(PotionData.FIRE))
		PotionData.FREEZE:
			_burn_left = 0.0
			_freeze_left = PotionData.PLAYER_FREEZE_TIME
			velocity.x = 0.0
			float_text("[FROZEN]", PotionData.color_of(PotionData.FREEZE))
		PotionData.DEATH:
			die(GameOver.DEATH_POTION)


func is_translucent() -> bool:
	return _translucent_left > 0.0


func is_burning() -> bool:
	return _burn_left > 0.0


func is_frozen() -> bool:
	return _freeze_left > 0.0


## Washes off potion effects (cleansing water).
func clear_potion_effects() -> void:
	if is_translucent() or is_burning() or is_frozen():
		_translucent_left = 0.0
		_burn_left = 0.0
		_freeze_left = 0.0
		float_text("[EFFECTS CLEARED]", Color(0.55, 0.85, 1.0))


func die(cause: StringName = GameOver.CAUGHT) -> void:
	if _dead:
		return
	_dead = true
	if _flames:
		_flames.emitting = false
	set_physics_process(false)
	_sprite.modulate = Color(1.0, 0.35, 0.35)
	if GameOver.TEXT.has(cause):
		_show_float(GameOver.TEXT[cause], GameOver.TEXT_COLOR, DEATH_TEXT_TIME, SKULL_ROWS[0].length() + SKULL_GAP)
		_show_skull()
	died.emit(cause)


## Shows `text` just above the head; it drifts up and fades out.
func float_text(text: String, color: Color) -> void:
	# Nothing replaces a death message.
	if not _dead:
		_show_float(text, color, FLOAT_TEXT_TIME)


## `hold` is how long it stays before fading; `room_left` is space to keep clear
## to the left of the text (for the skull).
func _show_float(text: String, color: Color, hold: float, room_left := 0.0) -> void:
	if not _float_label:
		_float_label = Label.new()
		_float_label.add_theme_font_override("font", FONT)
		_float_label.add_theme_font_size_override("font_size", 8)
		_float_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
		_float_label.add_theme_constant_override("outline_size", 3)
		_float_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_float_label.size = Vector2(120, 10)
		_float_label.z_index = 10
		add_child(_float_label)
	_float_label.text = text
	_float_label.add_theme_color_override("font_color", color)
	_float_label.position = Vector2(-60.0 + _float_shift(text, room_left), -46)
	_float_label.modulate.a = 1.0
	_float_label.show()
	if _float_tween:
		_float_tween.kill()
	_float_tween = create_tween().set_parallel()
	_float_tween.tween_property(_float_label, "position:y", -44.0, 1.0).set_ease(Tween.EASE_OUT)
	_float_tween.tween_property(_float_label, "modulate:a", 0.0, 0.5).set_delay(hold)


## How far to slide the float text so it stays on screen near the edges.
func _float_shift(text: String, room_left: float) -> float:
	var half := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x / 2.0
	var to_world := get_canvas_transform().affine_inverse()
	var left: float = (to_world * Vector2(FLOAT_MARGIN, 0)).x
	var right: float = (to_world * Vector2(get_viewport_rect().size.x - FLOAT_MARGIN, 0)).x
	var x := global_position.x
	return minf(right - (x + half), maxf(left - (x - half - room_left), 0.0))


## A little skull to the left of the float text (a child, so it fades with it).
func _show_skull() -> void:
	if not _skull:
		_skull = Control.new()
		_skull.draw.connect(_draw_skull)
		_float_label.add_child(_skull)
	var text_width := FONT.get_string_size(_float_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_skull.position = Vector2(roundf((_float_label.size.x - text_width) / 2.0) - SKULL_ROWS[0].length() - SKULL_GAP, 0.0)


func _draw_skull() -> void:
	# The outline first, then the bone on top of it.
	for margin in [1.0, 0.0]:
		for y in SKULL_ROWS.size():
			for x in SKULL_ROWS[y].length():
				if SKULL_ROWS[y][x] == "#":
					var color := Color(0.05, 0.05, 0.08) if margin > 0.0 else Color(0.95, 0.92, 0.82)
					_skull.draw_rect(Rect2(x, y, 1, 1).grow(margin), color)


## A remark (not a conversation) above the head for `seconds`: "SPEAKER:" in
## `color`, then `text`, wrapped. The game carries on meanwhile.
func say(speaker: String, text: String, color: Color, seconds := 5.0) -> void:
	if not _remark:
		_remark = RichTextLabel.new()
		_remark.bbcode_enabled = true
		_remark.fit_content = true
		_remark.scroll_active = false
		_remark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_remark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_remark.add_theme_font_override("normal_font", FONT)
		_remark.add_theme_font_size_override("normal_font_size", 8)
		_remark.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
		_remark.add_theme_constant_override("outline_size", 3)
		_remark.z_index = 10
		add_child(_remark)
	_remark.text = "[center][color=#%s]%s:[/color] %s[/center]" % [color.to_html(false), speaker, text]
	_remark.size = Vector2(REMARK_WIDTH, 0)
	_remark.modulate.a = 1.0
	_remark.show()
	# Sit it just above the head once its height is known.
	await get_tree().process_frame
	if not is_instance_valid(_remark):
		return
	_remark.position = Vector2(-REMARK_WIDTH / 2.0, -40.0 - _remark.get_content_height())
	_keep_remark_on_screen()
	if _remark_tween:
		_remark_tween.kill()
	_remark_tween = create_tween()
	_remark_tween.tween_interval(seconds)
	_remark_tween.tween_property(_remark, "modulate:a", 0.0, 0.5)
	_remark_tween.tween_callback(_remark.hide)


## Slides the remark sideways so it stays inside the screen near its edges.
func _keep_remark_on_screen() -> void:
	var to_world := get_viewport().get_canvas_transform().affine_inverse()
	var left := (to_world * Vector2(4, 0)).x
	var right := (to_world * Vector2(get_viewport_rect().size.x - 4, 0)).x
	var x := clampf(global_position.x - REMARK_WIDTH / 2.0, left, right - REMARK_WIDTH)
	_remark.position.x = x - global_position.x


## Holds the knight still with a speech bubble over its head (during a chat).
## Potion effects on the knight now, for the HUD: [{kind, left}], in seconds.
func active_effects() -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for effect in [[PotionData.FIRE, _burn_left], [PotionData.FREEZE, _freeze_left], [PotionData.TRANSLUCENT, _translucent_left]]:
		if effect[1] > 0.0:
			effects.append({"kind": effect[0], "left": effect[1]})
	return effects


## A conversation froze the game. The knight stays in it, but still falls: no
## control and no potion timers, only gravity. (Runs while the game is paused.)
func set_held_by_dialogue(held: bool) -> void:
	_held_by_dialogue = held
	process_mode = Node.PROCESS_MODE_ALWAYS if held else Node.PROCESS_MODE_INHERIT


## A jump key still held from closing a conversation or the book doesn't count.
func ignore_held_jump() -> void:
	_ignore_jump = true
	_jump_buffer_timer = 0.0


func _jump_pressed() -> bool:
	if _ignore_jump:
		if not Input.is_action_pressed("jump"):
			_ignore_jump = false
		return false
	return super()


func set_talking(talking: bool) -> void:
	_talking = talking
	if not _chat_icon:
		_chat_icon = Node2D.new()
		_chat_icon.position = Vector2(0, -38)
		_chat_icon.z_index = 10
		_chat_icon.draw.connect(_draw_chat_icon)
		add_child(_chat_icon)
	_chat_icon.visible = talking


func _draw_chat_icon() -> void:
	var bubble := Color.WHITE
	_chat_icon.draw_rect(Rect2(-7, -9, 14, 8), bubble)
	_chat_icon.draw_colored_polygon(PackedVector2Array([Vector2(-3, -1), Vector2(1, -1), Vector2(-3, 2)]), bubble)
	for x in [-4.0, 0.0, 4.0]:
		_chat_icon.draw_rect(Rect2(x - 1, -6, 2, 2), Color(0.1, 0.09, 0.14))


func _physics_process(delta: float) -> void:
	if _held_by_dialogue:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		_slide()
		return
	if is_burning():
		_burn_left -= delta
		if _burn_left <= 0.0:
			_burn_left = 0.0
			die(GameOver.BURNED)
			return
	if is_frozen():
		# Stuck in place: no running or jumping, but still falls.
		_freeze_left = maxf(_freeze_left - delta, 0.0)
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		_slide()
		return
	if _base_max_speed < 0.0:
		_base_max_speed = max_speed
	max_speed = _base_max_speed * (PotionData.PLAYER_FIRE_SPEED_BOOST if is_burning() else 1.0)
	super(delta)
	_push_crates()


## Moves, then bounces off any jelly that was hit hard enough: the push back
## is the speed going into it (so falling from higher bounces higher) times
## the jelly's strength, minus a little so bounces die down on green jelly.
func _slide() -> void:
	var incoming := velocity
	move_and_slide()
	var bounced := false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if is_burning() and collision.get_collider() is IcePillar:
			collision.get_collider().melt()
		var jelly := collision.get_collider() as Jelly
		if not jelly or bounced:
			continue
		var normal := collision.get_normal()
		var into := -incoming.dot(normal)
		# Walking into a jelly wall just stops you; only a fast hit (a fall,
		# a knockback, a burning sprint) bounces.
		var needed := Jelly.MIN_BOUNCE_SPEED if absf(normal.y) > 0.5 else Jelly.MIN_SIDE_BOUNCE_SPEED
		if into < needed:
			continue
		var out := minf(into * Jelly.KEEP * jelly.strength, Jelly.MAX_BOUNCE_SPEED)
		# Swap the part of the velocity going into the jelly for the bounce.
		velocity = incoming + normal * (into + out)
		jelly.wobble()
		bounced = true


## Pushes anything with a push() method that the knight walked into sideways.
func _push_crates() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()
		var side := -collision.get_normal().x
		if body and body.has_method("push") and absf(side) > 0.7 and signf(Input.get_axis("move_left", "move_right")) == signf(side):
			body.push(side * push_speed)
			# Keep leaning into the crate so contact isn't lost next frame.
			velocity.x = side * push_speed


func _process(delta: float) -> void:
	if _remark and _remark.visible:
		_keep_remark_on_screen()
	if _dead or _held_by_dialogue:
		return
	_translucent_left = maxf(_translucent_left - delta, 0.0)
	if not _flames:
		_flames = _make_flames()
		# Freezes with the game even while the knight is held by dialogue.
		_flames.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(_flames)
	_flames.emitting = is_burning()
	if not _ice:
		# An ice cube in front of the knight while frozen, like frozen monsters.
		_ice = Node2D.new()
		_ice.draw.connect(func() -> void:
			var cube := Rect2(-8, -22, 16, 22)
			_ice.draw_rect(cube, Color(0.6, 0.9, 1.0, 0.3))
			_ice.draw_rect(cube, Color(0.8, 0.95, 1.0, 0.8), false))
		add_child(_ice)
	_ice.visible = is_frozen()
	var tint := Color.WHITE
	if is_frozen():
		tint = Color(0.6, 0.85, 1.0)
	elif is_burning():
		# The same hurt flash as a burning slime.
		_burn_flash_clock += delta
		tint = BURN_FLASH_A if int(_burn_flash_clock * BURN_FLASH_RATE) % 2 == 0 else BURN_FLASH_B
	_sprite.modulate = tint
	var alpha := 1.0
	if is_translucent():
		# Blink during the last second as a warning.
		var warning := _translucent_left < 1.0 and int(_translucent_left * 10.0) % 2 == 0
		alpha = 0.6 if warning else 0.35
	_sprite.modulate.a = alpha


func _make_flames() -> CPUParticles2D:
	var flames := CPUParticles2D.new()
	flames.emitting = false
	flames.amount = 12
	flames.lifetime = 0.45
	flames.position = Vector2(0, -14)
	flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flames.emission_rect_extents = Vector2(6, 13)
	flames.direction = Vector2.UP
	flames.spread = 20.0
	flames.gravity = Vector2(0, -60)
	flames.initial_velocity_min = 8.0
	flames.initial_velocity_max = 18.0
	flames.scale_amount_min = 1.0
	flames.scale_amount_max = 2.0
	flames.color = PotionData.color_of(PotionData.FIRE)
	return flames
