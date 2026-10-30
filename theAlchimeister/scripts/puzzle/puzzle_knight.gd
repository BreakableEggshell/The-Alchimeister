extends "res://scripts/platformer/platformer_knight.gd"
## The platformer knight plus what the puzzle stage needs: potion effects on
## the player (knockback and translucent; fire and freeze don't affect them)
## and dying when caught.

signal died

var _translucent_left := 0.0
var _dead := false


func apply_potion(kind: StringName, origin: Vector2) -> void:
	if _dead:
		return
	match kind:
		PotionData.KNOCKBACK:
			velocity = PotionData.knockback_velocity(global_position + Vector2(0, -8), origin)
		PotionData.TRANSLUCENT:
			_translucent_left = PotionData.TRANSLUCENT_TIME


func is_translucent() -> bool:
	return _translucent_left > 0.0


func die() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	_sprite.modulate = Color(1.0, 0.35, 0.35)
	_sprite.frame = 58  # Death row of the sheet.
	died.emit()


func _process(delta: float) -> void:
	if _dead:
		return
	_translucent_left = maxf(_translucent_left - delta, 0.0)
	var alpha := 1.0
	if is_translucent():
		# Blink during the last second as a warning.
		var warning := _translucent_left < 1.0 and int(_translucent_left * 10.0) % 2 == 0
		alpha = 0.6 if warning else 0.35
	_sprite.modulate.a = alpha
