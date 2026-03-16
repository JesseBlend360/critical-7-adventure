extends StaticBody2D

## Generic interactable object - breakable boxes, readables, containers, switches
## Uses same interaction pattern as npc.gd/door.gd: Area2D body_entered -> player.set_nearby_npc(self)

@export_enum("breakable", "container", "readable", "switch") var object_type: String = "breakable"
@export var intact_texture: Texture2D
@export var broken_texture: Texture2D
@export var loot_flag: String = ""
@export var loot_effect: Dictionary = {}  ## e.g. {"strategy": 3}
@export var required_flag: String = ""
@export var message: String = ""
@export var one_time: bool = true
@export_multiline var readable_text: String = ""  ## For readable objects

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_zone: Area2D = $InteractionZone
@onready var prompt_label: Label = $PromptLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player_in_range: bool = false
var is_used: bool = false


func _ready() -> void:
	prompt_label.visible = false
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

	if intact_texture:
		sprite.texture = intact_texture


func interact() -> void:
	if not player_in_range:
		return
	if is_used and one_time:
		return

	# Check required flag
	if required_flag != "" and not GameState.has_flag(required_flag):
		FloatingTextManager.spawn_at("Locked", global_position + Vector2(0, -40), Color(0.9, 0.6, 0.2))
		return

	match object_type:
		"breakable":
			_break_object()
		"container":
			_open_container()
		"readable":
			_read_object()
		"switch":
			_toggle_switch()


func _break_object() -> void:
	is_used = true

	# Swap texture
	if broken_texture:
		sprite.texture = broken_texture

	# Spawn break particles
	_spawn_break_particles()

	# Disable collision
	collision_shape.set_deferred("disabled", true)

	# Apply loot
	_apply_loot()

	# Hide prompt
	prompt_label.visible = false


func _open_container() -> void:
	is_used = true

	if broken_texture:
		sprite.texture = broken_texture

	_apply_loot()

	if message != "":
		FloatingTextManager.spawn_at(message, global_position + Vector2(0, -40), Color(1, 1, 1))


func _read_object() -> void:
	is_used = true

	# Show readable text via dialogue system (short inline dialogue)
	if readable_text != "":
		# Use a simple floating text for short messages
		if readable_text.length() < 60:
			FloatingTextManager.spawn_at(readable_text, global_position + Vector2(0, -50), Color(0.8, 0.8, 0.6))
		else:
			# For longer text, trigger a simple narrator dialogue
			_show_readable_dialogue()

	_apply_loot()


func _toggle_switch() -> void:
	is_used = not is_used

	if is_used and broken_texture:
		sprite.texture = broken_texture
	elif not is_used and intact_texture:
		sprite.texture = intact_texture

	_apply_loot()

	if message != "":
		FloatingTextManager.spawn_at(message, global_position + Vector2(0, -40), Color(0.8, 0.9, 1.0))


func _apply_loot() -> void:
	# Set flag
	if loot_flag != "":
		GameState.set_flag(loot_flag)

	# Apply score effects
	if not loot_effect.is_empty():
		GameState.apply_effects(loot_effect)

	# Show floating text for score changes
	if message != "" and object_type != "readable":
		FloatingTextManager.spawn_at(message, global_position + Vector2(0, -40), Color(1, 0.9, 0.4))


func _spawn_break_particles() -> void:
	# Simple particle burst using tweened sprites
	for i in range(5):
		var particle = Sprite2D.new()
		particle.texture = intact_texture
		particle.scale = Vector2(0.5, 0.5)
		particle.position = Vector2.ZERO
		particle.modulate.a = 0.8
		add_child(particle)

		var angle = randf() * TAU
		var distance = randf_range(20, 50)
		var target = Vector2(cos(angle) * distance, sin(angle) * distance)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target, 0.4).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_property(particle, "scale", Vector2(0.1, 0.1), 0.4)
		tween.set_parallel(false)
		tween.tween_callback(particle.queue_free)


func _show_readable_dialogue() -> void:
	# Create a temporary inline dialogue via signals
	# This mimics a narrator speaking the readable text
	GameManager.start_dialogue()
	DialogueManager.is_active = true
	DialogueManager.dialogue_started.emit("narrator")
	DialogueManager.node_displayed.emit({
		"speaker": "narrator",
		"text": readable_text
	})
	# After this node, end the conversation
	# The player will press space to dismiss, which calls DialogueManager.advance()
	# Since there's no current_node_id, it will end the conversation


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if not (is_used and one_time):
			prompt_label.visible = true
		body.set_nearby_npc(self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false
		body.clear_nearby_npc(self)
