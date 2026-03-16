extends StaticBody2D

## Interactable door that can be opened/closed
## Supports locked doors requiring flags

@export var is_open: bool = false
@export var closed_texture: Texture2D
@export var open_texture: Texture2D
@export var required_flag: String = ""
@export var locked_message: String = "It's locked."

@onready var interaction_zone: Area2D = $InteractionZone
@onready var prompt_label: Label = $PromptLabel
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player_in_range: bool = false

func _ready() -> void:
	prompt_label.visible = false
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)
	_update_door_state()

func interact() -> void:
	if not player_in_range:
		return

	# Check lock
	if required_flag != "" and not GameState.has_flag(required_flag):
		# Show locked message via floating text
		FloatingTextManager.spawn_at(locked_message, global_position + Vector2(0, -40), Color(0.9, 0.6, 0.2))
		return

	is_open = not is_open
	_update_door_state()

func _update_door_state() -> void:
	if is_open:
		sprite.texture = open_texture
		collision_shape.disabled = true
	else:
		sprite.texture = closed_texture
		collision_shape.disabled = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt_label.visible = true
		if body.has_method("set_nearby_npc"):
			body.set_nearby_npc(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false
		if body.has_method("clear_nearby_npc"):
			body.clear_nearby_npc(self)
