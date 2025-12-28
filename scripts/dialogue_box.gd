extends CanvasLayer

## Dialogue box UI for displaying NPC conversations

signal dialogue_started
signal dialogue_ended

@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/NameLabel
@onready var text_label: Label = $Panel/TextLabel
@onready var advance_indicator: Label = $Panel/AdvanceIndicator

var dialogue_data: Dictionary = {}
var current_lines: Array = []
var current_line_index: int = 0
var is_active: bool = false

func _ready() -> void:
	_load_dialogue_data()
	hide_dialogue()

func _load_dialogue_data() -> void:
	var file := FileAccess.open("res://data/dialogue.json", FileAccess.READ)
	if file:
		var json_text := file.get_as_text()
		file.close()
		dialogue_data = JSON.parse_string(json_text)
		if dialogue_data == null:
			dialogue_data = {}
			push_error("Failed to parse dialogue.json")
	else:
		push_error("Could not open dialogue.json")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and is_active:
		get_viewport().set_input_as_handled()
		advance()

func start_dialogue(npc_id: String) -> void:
	if not dialogue_data.has(npc_id):
		push_error("No dialogue found for NPC: " + npc_id)
		return

	var npc_data: Dictionary = dialogue_data[npc_id]
	current_lines = npc_data.get("lines", [])
	current_line_index = 0

	if current_lines.is_empty():
		return

	name_label.text = npc_data.get("name", "???")
	_show_current_line()
	show_dialogue()
	GameManager.start_dialogue()
	dialogue_started.emit()

func advance() -> void:
	current_line_index += 1
	if current_line_index >= current_lines.size():
		end_dialogue()
	else:
		_show_current_line()

func end_dialogue() -> void:
	hide_dialogue()
	current_lines = []
	current_line_index = 0
	GameManager.end_dialogue()
	dialogue_ended.emit()

func _show_current_line() -> void:
	if current_line_index < current_lines.size():
		text_label.text = current_lines[current_line_index]

func show_dialogue() -> void:
	panel.visible = true
	is_active = true

func hide_dialogue() -> void:
	panel.visible = false
	is_active = false
