extends Node
## Root script for every movement prototype scene: R restarts it, Esc returns
## to the start menu.

const START_MENU := "res://scenes/menu/start_menu.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(START_MENU)
