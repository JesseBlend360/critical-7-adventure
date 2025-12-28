extends StaticBody2D

## NPC character with interaction zone

@export var npc_id: String = "sage"

@onready var interaction_zone: Area2D = $InteractionZone
@onready var prompt_label: Label = $PromptLabel

var player_in_range: bool = false
var dialogue_box: Node = null

func _ready() -> void:
	prompt_label.visible = false
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

func set_dialogue_box(box: Node) -> void:
	dialogue_box = box

func interact() -> void:
	if dialogue_box and player_in_range:
		dialogue_box.start_dialogue(npc_id)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt_label.visible = true
		body.set_nearby_npc(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false
		body.clear_nearby_npc(self)
