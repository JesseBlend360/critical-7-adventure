extends Node2D

## Main scene setup script

@onready var dialogue_box: CanvasLayer = $DialogueBox
@onready var sage: RigidBody2D = $NPCs/Sage
@onready var delta: RigidBody2D = $NPCs/Delta
@onready var nova: RigidBody2D = $NPCs/Nova

func _ready() -> void:
	# Wire NPCs to dialogue box
	sage.set_dialogue_box(dialogue_box)
	delta.set_dialogue_box(dialogue_box)
	nova.set_dialogue_box(dialogue_box)
