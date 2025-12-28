extends Node2D

## Main scene setup script

@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var sage: StaticBody2D = $NPCs/Sage
@onready var delta: StaticBody2D = $NPCs/Delta
@onready var nova: StaticBody2D = $NPCs/Nova

func _ready() -> void:
	# Wire NPCs to dialogue box
	sage.set_dialogue_box(dialogue_box)
	delta.set_dialogue_box(dialogue_box)
	nova.set_dialogue_box(dialogue_box)
