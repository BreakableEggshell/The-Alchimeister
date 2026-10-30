extends "res://scripts/prototype.gd"
## A puzzle stage: restarts shortly after the player is caught, and shows
## the clear banner when they reach the exit. R and Esc work as in every
## prototype.

@export var player: CharacterBody2D
@export var exit: Area2D
@export var thrower: Node2D
@export var hud: Control
## Seconds to show "caught" before restarting.
@export var restart_delay := 1.2


func _ready() -> void:
	player.died.connect(_on_player_died)
	exit.reached.connect(_on_exit_reached)


func _on_player_died() -> void:
	_stop_throwing()
	hud.show_banner("CAUGHT!", "RESTARTING...", Color(1, 0.45, 0.45))
	await get_tree().create_timer(restart_delay).timeout
	get_tree().reload_current_scene()


func _on_exit_reached() -> void:
	_stop_throwing()
	player.set_physics_process(false)
	hud.show_banner("STAGE CLEAR", "R: PLAY AGAIN   ESC: MENU", Color(0.95, 0.85, 0.55))


func _stop_throwing() -> void:
	thrower.cancel()
	thrower.set_process_unhandled_input(false)
