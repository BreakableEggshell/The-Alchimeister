extends CanvasLayer
## Autoload "Iris": the circle that closes to black ("iris in") and opens from
## black ("iris out") around a point on screen, for restarts and stage changes.

const CLOSE_TIME := 0.35
const OPEN_TIME := 0.4
const SHADER := """
shader_type canvas_item;
uniform vec2 center;
uniform float radius;
uniform vec2 screen_size;

void fragment() {
	// Measured in game pixels, so the edge is as chunky as the art.
	vec2 at = floor(UV * screen_size) + 0.5;
	COLOR = vec4(0.0, 0.0, 0.0, step(radius, distance(at, center)));
}
"""

## True from the start of a close until something opens or clears it.
var is_closed := false
var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween
var _radius := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.hide()
	add_child(_rect)


## Iris in: closes on `focus` (screen pixels; null for the middle of the screen).
## Stays black until open() or clear().
func close(focus = null) -> void:
	var at := _focus_or_center(focus)
	is_closed = true
	_show_at(at)
	if _tween:
		_tween.kill()
	else:
		_set_radius(_full_radius(at))
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_radius, _radius, 0.0, CLOSE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await _tween.finished


## Instantly black, ready to open.
func cover() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	is_closed = true
	_show_at(_focus_or_center(null))
	_set_radius(0.0)


## Iris out: opens from black around `focus`.
func open(focus = null) -> void:
	var at := _focus_or_center(focus)
	is_closed = false
	_show_at(at)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_radius, _radius, _full_radius(at), OPEN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(clear)


## No iris at all, right away.
func clear() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	is_closed = false
	_rect.hide()


func _show_at(at: Vector2) -> void:
	_rect.show()
	_material.set_shader_parameter("center", at)
	_material.set_shader_parameter("screen_size", _rect.size)


func _set_radius(radius: float) -> void:
	_radius = radius
	_material.set_shader_parameter("radius", radius)


## Far enough from `at` to clear every corner of the screen.
func _full_radius(at: Vector2) -> float:
	var far := Vector2(maxf(at.x, _rect.size.x - at.x), maxf(at.y, _rect.size.y - at.y))
	return far.length() + 1.0


func _focus_or_center(focus) -> Vector2:
	return focus if focus is Vector2 else _rect.size / 2.0
