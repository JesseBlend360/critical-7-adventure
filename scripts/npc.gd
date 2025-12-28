extends StaticBody2D

## NPC character with interaction zone and wandering behavior

@export var npc_id: String = "sage"
@export var wander_radius: float = 50.0
@export var wander_speed: float = 30.0
@export var wait_time_min: float = 2.0
@export var wait_time_max: float = 5.0

@onready var interaction_zone: Area2D = $InteractionZone
@onready var prompt_label: Label = $PromptLabel

var player_in_range: bool = false
var dialogue_box: Node = null
var home_position: Vector2
var wander_timer: Timer
var wander_tween: Tween
var is_wandering_paused: bool = false

func _ready() -> void:
	prompt_label.visible = false
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

	# Store starting position as home
	home_position = global_position

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
	wander_timer.stop()
	if wander_tween and wander_tween.is_valid():
		wander_tween.kill()

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

func _on_wander_timer_timeout() -> void:
	if is_wandering_paused:
		return

	# Pick random point within wander_radius of home
	var angle = randf() * TAU
	var distance = randf() * wander_radius
	var target_position = home_position + Vector2(cos(angle), sin(angle)) * distance

	# Calculate duration based on distance and speed
	var move_distance = global_position.distance_to(target_position)
	var duration = move_distance / wander_speed

	# Kill any existing tween
	if wander_tween and wander_tween.is_valid():
		wander_tween.kill()

	# Tween to target position
	wander_tween = create_tween()
	wander_tween.tween_property(self, "global_position", target_position, duration)
	wander_tween.tween_callback(_start_wander_timer)
