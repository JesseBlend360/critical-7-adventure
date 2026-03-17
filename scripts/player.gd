extends CharacterBody2D

## Player character with 8-direction movement

@export var speed: float = 200.0
@export var push_force: float = 300.0

var can_move: bool = true
var nearby_npc: Node = null
var nearby_chip: Node = null
@onready var _char_animator: CharacterAnimator = $CharacterAnimator

func _ready() -> void:
	# Connect to DialogueManager signals for movement control
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		return

	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	velocity = input_dir * speed
	move_and_slide()

	# Update character animation
	if _char_animator:
		_char_animator.set_moving(input_dir.length() > 0.1)
		if input_dir.length() > 0.1:
			_char_animator.set_direction(input_dir)

	# Push any RigidBody2D objects we collide with (only when actively moving)
	if input_dir.length() > 0.1:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider is RigidBody2D:
				# Use player's movement direction, not collision normal
				collider.apply_central_force(input_dir.normalized() * push_force)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_move and nearby_npc:
		nearby_npc.interact()

func _is_chip(node: Node) -> bool:
	return node is Node2D and node.has_method("show_locked_message")

func set_nearby_npc(npc: Node) -> void:
	if _is_chip(npc):
		nearby_chip = npc
		if nearby_npc == null:
			nearby_npc = npc
	else:
		nearby_npc = npc

func clear_nearby_npc(npc: Node) -> void:
	if _is_chip(npc):
		nearby_chip = null
	if nearby_npc == npc:
		# Fall back to CHIP if it's still in range
		nearby_npc = nearby_chip

func _on_dialogue_started(_npc_id: String) -> void:
	can_move = false
	if _char_animator:
		_char_animator.set_moving(false)

func _on_dialogue_ended() -> void:
	can_move = true
