extends CharacterBody2D

## Player character with 8-direction movement

@export var speed: float = 200.0
@export var push_force: float = 300.0

var can_move: bool = true
var nearby_npc: Node = null

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

func set_nearby_npc(npc: Node) -> void:
	nearby_npc = npc

func clear_nearby_npc(npc: Node) -> void:
	if nearby_npc == npc:
		nearby_npc = null

func _on_dialogue_started(_npc_id: String) -> void:
	can_move = false

func _on_dialogue_ended() -> void:
	can_move = true
