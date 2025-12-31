extends RigidBody2D

## NPC character with interaction zone and wandering behavior

@export var npc_id: String = "sage"
@export var tile_size: float = 48.0  # 16px * 3x scale
@export var wander_speed: float = 100.0
@export var wait_time_min: float = 10.0
@export var wait_time_max: float = 30.0
@export var npc_mass: float = 3.0
@export var npc_friction: float = 5.0

@onready var interaction_zone: Area2D = $InteractionZone
@onready var prompt_label: Label = $PromptLabel

var player_in_range: bool = false
var dialogue_box: Node = null
var home_position: Vector2
var wander_timer: Timer
var wander_target: Vector2
var is_wandering_paused: bool = false
var is_moving: bool = false

func _ready() -> void:
	prompt_label.visible = false
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

	# Store starting position as home
	home_position = global_position
	wander_target = global_position

	# Configure RigidBody2D for pushable NPC
	mass = npc_mass
	gravity_scale = 0.0  # No gravity (top-down game)
	lock_rotation = true  # Don't spin when pushed
	linear_damp = npc_friction  # Friction to slow down

	# Create and start wander timer
	wander_timer = Timer.new()
	wander_timer.one_shot = true
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	add_child(wander_timer)
	_start_wander_timer()

func set_dialogue_box(box: Node) -> void:
	dialogue_box = box
	if dialogue_box:
		dialogue_box.dialogue_ended.connect(_on_dialogue_ended)

func interact() -> void:
	if dialogue_box and player_in_range:
		_pause_wandering()
		dialogue_box.start_dialogue(npc_id)

func _pause_wandering() -> void:
	is_wandering_paused = true
	is_moving = false
	wander_timer.stop()
	linear_velocity = Vector2.ZERO

func _resume_wandering() -> void:
	is_wandering_paused = false
	_start_wander_timer()

func _on_dialogue_ended() -> void:
	_resume_wandering()

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

func _start_wander_timer() -> void:
	var wait_time = randf_range(wait_time_min, wait_time_max)
	wander_timer.start(wait_time)

func _physics_process(_delta: float) -> void:
	if is_wandering_paused:
		return

	# Move toward wander target using physics
	var direction = wander_target - global_position
	var distance = direction.length()

	if distance > 5.0:
		# Apply force toward target
		is_moving = true
		var force = direction.normalized() * wander_speed * mass
		apply_central_force(force)
	else:
		# Reached target, stop and wait
		is_moving = false
		linear_velocity = linear_velocity.lerp(Vector2.ZERO, 0.2)


func _on_wander_timer_timeout() -> void:
	if is_wandering_paused:
		return

	# Pick random cardinal direction and move exactly one tile
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var dir = directions[randi() % 4]
	wander_target = global_position + dir * tile_size

	# Start next timer
	_start_wander_timer()
