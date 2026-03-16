extends RigidBody2D

## NPC character with interaction zone and wandering behavior
## Supports unique sprites per instance and bounded wandering

@export var npc_id: String = "sage"
@export var display_name: String = ""
@export var tile_size: float = 48.0  # 16px * 3x scale
@export var wander_speed: float = 100.0
@export var wait_time_min: float = 10.0
@export var wait_time_max: float = 30.0
@export var npc_mass: float = 3.0
@export var npc_friction: float = 5.0
@export var npc_sprite: Texture2D  ## Per-NPC sprite override
@export var wander_bounds: Rect2 = Rect2()  ## If non-zero, constrain wandering to this area

@onready var interaction_zone: Area2D = $InteractionZone
@onready var prompt_label: Label = $PromptLabel

var player_in_range: bool = false
var home_position: Vector2
var wander_timer: Timer
var wander_target: Vector2
var is_wandering_paused: bool = false
var is_moving: bool = false

# Boss fight mode
var boss_fight_mode: bool = false
var boss_fight_position: Vector2
var has_boss_task: bool = false
var boss_task_complete: bool = false

func _ready() -> void:
	prompt_label.visible = false
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

	# Apply custom sprite if set
	if npc_sprite:
		$Sprite2D.texture = npc_sprite

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

	# Connect to DialogueManager signals
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func interact() -> void:
	if not player_in_range:
		return

	# During boss fight, route through boss fight system
	if boss_fight_mode and has_boss_task and not boss_task_complete:
		var boss_fight = get_tree().current_scene.get_node_or_null("BossFight")
		if boss_fight and boss_fight.attempt_objective_for_npc(npc_id):
			return

	_pause_wandering()
	DialogueManager.start_conversation(npc_id)

func _pause_wandering() -> void:
	is_wandering_paused = true
	is_moving = false
	wander_timer.stop()
	linear_velocity = Vector2.ZERO

func _resume_wandering() -> void:
	if boss_fight_mode:
		return  # Don't resume wandering during boss fight
	is_wandering_paused = false
	_start_wander_timer()

func _on_dialogue_ended() -> void:
	_resume_wandering()

func _get_display_name() -> String:
	if display_name != "":
		return display_name
	return npc_id.capitalize()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt_label.text = _get_display_name()
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

	# Clamp to wander bounds if set (non-zero rect)
	if wander_bounds.size != Vector2.ZERO:
		wander_target.x = clampf(wander_target.x, wander_bounds.position.x, wander_bounds.position.x + wander_bounds.size.x)
		wander_target.y = clampf(wander_target.y, wander_bounds.position.y, wander_bounds.position.y + wander_bounds.size.y)

	# Start next timer
	_start_wander_timer()


## Boss fight support

func enter_boss_fight(fixed_position: Vector2) -> void:
	boss_fight_mode = true
	boss_fight_position = fixed_position
	_pause_wandering()
	# Tween to fixed position
	var tween = create_tween()
	tween.tween_property(self, "global_position", fixed_position, 0.5)

func set_boss_task(has_task: bool) -> void:
	has_boss_task = has_task
	# Show "!" indicator above NPC if they have a pending task
	if has_task and not boss_task_complete:
		prompt_label.text = "!"
		prompt_label.visible = true
	else:
		prompt_label.text = _get_display_name()
		prompt_label.visible = false

func complete_boss_task() -> void:
	boss_task_complete = true
	prompt_label.text = ""
	prompt_label.visible = false
