extends Control

## CHIP - Collaborative Heuristic Intelligence Partner
## A helpful (and snarky) AI companion that offers contextual advice

signal chip_spoke(message: String)

@onready var icon_button: TextureButton = $IconButton
@onready var speech_bubble: Panel = $SpeechBubble
@onready var speech_label: Label = $SpeechBubble/Label
@onready var bounce_timer: Timer = $BounceTimer
@onready var hide_timer: Timer = $HideTimer

var lines_data: Dictionary = {}
var has_pending_message: bool = false
var is_bouncing: bool = false
var bounce_tween: Tween

# Track what we've already said to avoid repetition
var said_lines: Array[String] = []
var idle_timer: float = 0.0
const IDLE_THRESHOLD: float = 30.0


func _ready() -> void:
	_load_lines()
	speech_bubble.visible = false

	icon_button.pressed.connect(_on_icon_pressed)
	hide_timer.timeout.connect(_hide_speech)
	bounce_timer.timeout.connect(_do_bounce)

	# Connect to game signals
	GameState.budget_changed.connect(_on_budget_changed)
	GameState.week_changed.connect(_on_week_changed)
	GameState.decision_made.connect(_on_decision_made)
	DecisionManager.decision_applied.connect(_on_decision_applied)

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
			print("CHIP: Loaded dialogue data")
		else:
			push_error("CHIP: Failed to parse chip_lines.json")


func _process(delta: float) -> void:
	if not DialogueManager.is_active:
		idle_timer += delta
		if idle_timer >= IDLE_THRESHOLD:
			_check_idle_hint()
			idle_timer = 0.0


func _check_idle_hint() -> void:
	# Random chance to say something when idle
	if randf() < 0.3:
		_show_random_line("idle")


func _on_icon_pressed() -> void:
	if speech_bubble.visible:
		_hide_speech()
	else:
		# Give contextual advice based on current state
		_show_contextual_advice()


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
	var npc_ids = ["sage", "delta", "nova"]
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
	hide_timer.start(8.0)  # Hide after 8 seconds
	chip_spoke.emit(text)
	idle_timer = 0.0  # Reset idle timer


func _hide_speech() -> void:
	speech_bubble.visible = false


func _on_budget_changed(new_budget: int, _old_budget: int) -> void:
	var pct = float(new_budget) / float(GameState.budget_total) * 100.0
	if pct < 15 and randf() < 0.5:
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
		_show_time_line(weeks_left)


func _on_decision_made(_decision_id: String) -> void:
	idle_timer = 0.0  # Reset idle timer on any decision


func _on_decision_applied(decision_id: String, decision_data: Dictionary) -> void:
	# Comment on decisions based on their impact
	if decision_data.has("impact"):
		var total_impact = 0
		for score in decision_data["impact"]:
			total_impact += decision_data["impact"][score]

		if total_impact > 15 and randf() < 0.6:
			_show_random_line("good_decision")
		elif total_impact < -10 and randf() < 0.6:
			_show_random_line("bad_decision")


func _start_bounce() -> void:
	if is_bouncing:
		return
	is_bouncing = true
	has_pending_message = true
	bounce_timer.start(0.5)


func _do_bounce() -> void:
	if not has_pending_message:
		is_bouncing = false
		bounce_timer.stop()
		return

	# Simple bounce animation
	if bounce_tween and bounce_tween.is_running():
		bounce_tween.kill()

	bounce_tween = create_tween()
	bounce_tween.tween_property(icon_button, "scale", Vector2(1.2, 0.9), 0.1)
	bounce_tween.tween_property(icon_button, "scale", Vector2(0.9, 1.1), 0.1)
	bounce_tween.tween_property(icon_button, "scale", Vector2(1.0, 1.0), 0.1)


## Public method to show a locked choice message
func show_locked_message(requirement: String) -> void:
	if not lines_data.has("locked_option"):
		return

	var lines = lines_data["locked_option"]
	if lines is Array and lines.size() > 0:
		var line = lines[randi() % lines.size()]
		line = line.replace("{requirement}", requirement)
		_show_message(line)
