extends Node

## Global game state manager (Autoload singleton)

signal dialogue_started
signal dialogue_ended

var dialogue_active: bool = false

func start_dialogue() -> void:
	dialogue_active = true
	dialogue_started.emit()

func end_dialogue() -> void:
	dialogue_active = false
	dialogue_ended.emit()
