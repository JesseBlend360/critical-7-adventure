extends Node2D

## CHIP Companion - In-world floating companion that follows the player
## Replaces the old HUD-based CHIP Control with a Navi-like world-space companion
## States: idle, talking, excited, alarmed

signal chip_spoke(message: String)

# Follow behavior
@export var follow_offset: Vector2 = Vector2(-30, -40)
@export var follow_speed: float = 3.0
@export var flit_radius: float = 15.0
@export var flit_interval_min: float = 2.0
@export var flit_interval_max: float = 5.0

# References
@onready var sprite: Sprite2D = $Sprite2D
@onready var bounce_animator: Node = $BounceAnimator
@onready var speech_bubble: PanelContainer = $SpeechBubble
@onready var speech_label: Label = $SpeechBubble/Label
@onready var flit_timer: Timer = $FlitTimer
@onready var hide_timer: Timer = $HideTimer
@onready var interaction_zone: Area2D = $InteractionZone

# State
enum State { IDLE, TALKING, EXCITED, ALARMED }
var current_state: State = State.IDLE
var target_offset: Vector2
var player: Node2D = null

# CHIP dialogue data
var lines_data: Dictionary = {}
var said_lines: Array[String] = []
var idle_timer: float = 0.0
const IDLE_THRESHOLD: float = 30.0

# Interaction
var player_in_range: bool = false


func _ready() -> void:
	_load_lines()
	speech_bubble.visible = false
	target_offset = follow_offset

	flit_timer.timeout.connect(_on_flit_timer_timeout)
	hide_timer.timeout.connect(_hide_speech)
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

	# Start flitting
	_start_flit_timer()

	# Connect to game signals
	GameState.budget_changed.connect(_on_budget_changed)
	GameState.week_changed.connect(_on_week_changed)
	GameState.decision_made.connect(_on_decision_made)
	DecisionManager.decision_applied.connect(_on_decision_applied)

	# Find player after scene is ready
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

	# Show intro message after a short delay
	await get_tree().create_timer(2.0).timeout
	_show_random_line("first_meeting")


func _load_lines() -> void:
	var file = FileAccess.open("res://data/chip_lines.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()
		if error == OK:
			lines_data = json.get_data()
		else:
			push_error("CHIP: Failed to parse chip_lines.json")


func _process(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	# Follow player with lerp
	var target_pos = player.global_position + target_offset
	global_position = global_position.lerp(target_pos, follow_speed * delta)

	# Idle hint timer
	if not DialogueManager.is_active:
		idle_timer += delta
		if idle_timer >= IDLE_THRESHOLD:
			_check_idle_hint()
			idle_timer = 0.0

	# State-based behavior
	match current_state:
		State.EXCITED:
			# Faster bounce handled by modifying BounceAnimator properties
			pass
		State.ALARMED:
			# Shake effect
			sprite.position.x = sin(Time.get_ticks_msec() * 0.03) * 2.0


func interact() -> void:
	_show_contextual_advice()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		body.set_nearby_npc(self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		body.clear_nearby_npc(self)


func _start_flit_timer() -> void:
	flit_timer.start(randf_range(flit_interval_min, flit_interval_max))


func _on_flit_timer_timeout() -> void:
	if current_state == State.TALKING:
		_start_flit_timer()
		return

	# Pick a new random offset within radius of base offset
	var random_offset = Vector2(
		randf_range(-flit_radius, flit_radius),
		randf_range(-flit_radius, flit_radius)
	)
	target_offset = follow_offset + random_offset
	_start_flit_timer()


## State management

func set_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			sprite.position = Vector2.ZERO
			if bounce_animator:
				bounce_animator.idle_bob_px = 1.0
				bounce_animator.idle_bob_period = 1.0
		State.TALKING:
			target_offset = follow_offset  # Hold still
			sprite.position = Vector2.ZERO
			if bounce_animator:
				bounce_animator.idle_bob_px = 0.5
				bounce_animator.idle_bob_period = 1.5
		State.EXCITED:
			if bounce_animator:
				bounce_animator.idle_bob_px = 3.0
				bounce_animator.idle_bob_period = 0.3
		State.ALARMED:
			if bounce_animator:
				bounce_animator.idle_bob_px = 1.0
				bounce_animator.idle_bob_period = 0.5


## Contextual advice (same logic as old chip.gd)

func _check_idle_hint() -> void:
	if randf() < 0.3:
		_show_random_line("idle")


func _show_contextual_advice() -> void:
	# Check for critical situations first
	var critical_failures = GameState.get_critical_failures()
	if critical_failures.size() > 0:
		_show_score_line("score_critical", critical_failures[0])
		return

	# Check budget
	var budget_pct = GameState.get_budget_percent()
	if budget_pct < 15:
		_show_random_line("budget_critical")
		return
	if budget_pct < 30:
		_show_random_line("budget_low")
		return

	# Check for low scores
	var lowest = GameState.get_lowest_score()
	if lowest["value"] < 0:
		_show_score_line("score_low", lowest["name"])
		return

	# Check time pressure
	var weeks_left = GameState.get_weeks_remaining()
	if weeks_left <= 4:
		_show_time_line(weeks_left)
		return

	# Give NPC hint or random fact
	if randf() < 0.5:
		_show_npc_hint()
	else:
		_show_random_line("random_facts")


func _show_random_line(category: String) -> void:
	if not lines_data.has(category):
		return

	var lines = lines_data[category]
	if lines is Array and lines.size() > 0:
		# Try to pick a line we haven't said recently
		var available = lines.filter(func(line): return line not in said_lines)
		if available.is_empty():
			said_lines.clear()
			available = lines

		var line = available[randi() % available.size()]
		_show_message(line)
		said_lines.append(line)


func _show_score_line(category: String, score_name: String) -> void:
	if not lines_data.has(category):
		return

	var lines = lines_data[category]
	if lines is Array and lines.size() > 0:
		var line = lines[randi() % lines.size()]
		line = line.replace("{score}", score_name.capitalize())
		_show_message(line)


func _show_time_line(weeks_left: int) -> void:
	if not lines_data.has("time_pressure"):
		return

	var lines = lines_data["time_pressure"]
	if lines is Array and lines.size() > 0:
		var line = lines[randi() % lines.size()]
		line = line.replace("{weeks}", str(weeks_left))
		_show_message(line)


func _show_npc_hint() -> void:
	if not lines_data.has("npc_hint"):
		return

	var hints = lines_data["npc_hint"]
	var npc_ids = ["sage", "delta", "nova", "harry", "rex", "morgan", "casey"]
	# Prioritize NPCs we haven't talked to
	for npc_id in npc_ids:
		if not GameState.has_talked_to(npc_id) and hints.has(npc_id):
			_show_message(hints[npc_id])
			return

	# Otherwise random NPC hint
	var available_npcs = hints.keys()
	if available_npcs.size() > 0:
		var npc = available_npcs[randi() % available_npcs.size()]
		_show_message(hints[npc])


func _show_message(text: String) -> void:
	speech_label.text = text
	speech_bubble.visible = true
	speech_bubble.modulate.a = 1.0
	hide_timer.start(8.0)
	set_state(State.TALKING)
	chip_spoke.emit(text)
	idle_timer = 0.0


func _hide_speech() -> void:
	# Fade out
	var tween = create_tween()
	tween.tween_property(speech_bubble, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		speech_bubble.visible = false
		set_state(State.IDLE)
	)


## Signal handlers

func _on_budget_changed(new_budget: int, _old_budget: int) -> void:
	var pct = float(new_budget) / float(GameState.budget_total) * 100.0
	if pct < 15 and randf() < 0.5:
		set_state(State.ALARMED)
		_show_random_line("budget_critical")
	elif pct < 30 and randf() < 0.3:
		_show_random_line("budget_low")


func _on_week_changed(new_week: int) -> void:
	# Check for milestone weeks
	var milestone_key = str(new_week)
	if lines_data.has("week_milestone"):
		var milestones = lines_data["week_milestone"]
		if milestones.has(milestone_key):
			_show_message(milestones[milestone_key])
			return

	# Random time pressure comment
	var weeks_left = GameState.total_weeks - new_week
	if weeks_left <= 4 and randf() < 0.4:
		set_state(State.ALARMED)
		_show_time_line(weeks_left)


func _on_decision_made(_decision_id: String) -> void:
	idle_timer = 0.0


func _on_decision_applied(decision_id: String, decision_data: Dictionary) -> void:
	# Terminal message reactions
	if decision_id.begins_with("terminal_"):
		if decision_id.ends_with("_prepared"):
			_show_random_line("terminal_sent_prepared")
			set_state(State.EXCITED)
		elif decision_id.ends_with("_unprepared"):
			_show_random_line("terminal_sent_unprepared")
			set_state(State.ALARMED)
		return

	if decision_data.has("impact"):
		var total_impact = 0
		for score in decision_data["impact"]:
			total_impact += decision_data["impact"][score]

		if total_impact > 15 and randf() < 0.6:
			set_state(State.EXCITED)
			_show_random_line("good_decision")
		elif total_impact < -10 and randf() < 0.6:
			set_state(State.ALARMED)
			_show_random_line("bad_decision")


## Public method to show a locked choice message
func show_locked_message(requirement: String) -> void:
	if not lines_data.has("locked_option"):
		return

	var lines = lines_data["locked_option"]
	if lines is Array and lines.size() > 0:
		var line = lines[randi() % lines.size()]
		line = line.replace("{requirement}", requirement)
		_show_message(line)
