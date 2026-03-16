extends Node

## Boss Fight: "The Board Presentation"
## When week > 16, enters boss fight mode instead of immediately ending.
## Player has a limited action budget to complete objectives by interacting with NPCs.

signal boss_fight_started
signal boss_fight_ended(results: Dictionary)
signal action_used(remaining: int)
signal objective_completed(objective_id: String, quality: String)

# Boss fight state
var is_active: bool = false
var actions_remaining: int = 0
var max_actions: int = 0
var objectives: Array[Dictionary] = []
var completed_objectives: Array[String] = []
var boss_fight_results: Dictionary = {}

# UI references (set by main scene or found at runtime)
var action_label: Label
var objectives_container: VBoxContainer
var start_button: Button

# NPC positions during boss fight
var npc_positions: Dictionary = {
	"delta": Vector2(400, 120),
	"nova": Vector2(600, 400),
	"harry": Vector2(750, 100),
	"sage": Vector2(150, 150),
	"rex": Vector2(300, 400),
	"morgan": Vector2(500, 200),
	"casey": Vector2(200, 300)
}


func _ready() -> void:
	# Override the normal game_over to intercept and start boss fight
	GameState.game_over.connect(_on_game_over)


func _on_game_over(reason: String) -> void:
	if reason == "time_expired" and not is_active:
		# Intercept time expiry — start boss fight instead
		# Cancel the ending screen by blocking the signal chain
		# We need to start the boss fight sequence
		call_deferred("_start_boss_fight")


func _start_boss_fight() -> void:
	is_active = true

	# Calculate action budget
	max_actions = _calculate_action_budget()
	actions_remaining = max_actions

	# Build objectives list
	objectives = _build_objectives()

	# Set up NPCs in boss fight mode
	_setup_npcs()

	# Create boss fight UI
	_create_boss_fight_ui()

	boss_fight_started.emit()


func _calculate_action_budget() -> int:
	var actions = 5  # Baseline

	# NPCs befriended (talked to)
	for npc_id in ["sage", "delta", "nova", "harry", "rex", "morgan", "casey"]:
		if GameState.has_talked_to(npc_id):
			actions += 1

	# Key decisions
	if GameState.has_made_decision("stakeholder_roadshow"):
		actions += 1
	if GameState.has_made_decision("executive_demo"):
		actions += 1
	if GameState.has_made_decision("change_champions"):
		actions += 1

	# High scores bonuses
	if GameState.scores.get("strategy", 0) >= 15:
		actions += 1
	if GameState.scores.get("trust", 0) >= 15:
		actions += 1

	# Secrets/breakables
	if GameState.has_flag("has_server_key"):
		actions += 1
	if GameState.has_flag("data_audit_complete"):
		actions += 1

	return mini(actions, 15)  # Cap at 15


func _build_objectives() -> Array[Dictionary]:
	var objs: Array[Dictionary] = []

	objs.append({
		"id": "verify_data",
		"title": "Get Delta to verify the data pipeline",
		"npc": "delta",
		"score_key": "data",
		"available": GameState.has_talked_to("delta"),
		"description": "Run to Delta and confirm data is flowing correctly."
	})

	objs.append({
		"id": "prepare_demo",
		"title": "Ask Nova to prepare the demo",
		"npc": "nova",
		"score_key": "innovation",
		"available": GameState.has_talked_to("nova"),
		"description": "Nova's demo could wow the board... or crash spectacularly."
	})

	objs.append({
		"id": "brief_harry",
		"title": "Brief Harry on talking points",
		"npc": "harry",
		"score_key": "trust",
		"available": GameState.has_talked_to("harry"),
		"description": "Give Harry the data he needs to champion the project."
	})

	objs.append({
		"id": "confirm_uptime",
		"title": "Get Rex to confirm uptime",
		"npc": "rex",
		"score_key": "technical",
		"available": GameState.has_talked_to("rex"),
		"description": "Rex needs to guarantee the servers won't crash during the demo."
	})

	objs.append({
		"id": "rally_morgan",
		"title": "Rally Morgan's team",
		"npc": "morgan",
		"score_key": "change",
		"available": GameState.has_talked_to("morgan"),
		"description": "Morgan can handle stakeholder questions if she's prepared."
	})

	objs.append({
		"id": "review_strategy",
		"title": "Review strategy with Sage",
		"npc": "sage",
		"score_key": "strategy",
		"available": GameState.has_talked_to("sage"),
		"description": "Sage's strategic framing could make or break the pitch."
	})

	objs.append({
		"id": "activate_server",
		"title": "Activate the server room",
		"npc": "",
		"score_key": "technical",
		"available": GameState.has_flag("has_server_key"),
		"description": "Requires the server room key. Extra processing power for the demo."
	})

	objs.append({
		"id": "rehearse_pitch",
		"title": "Rehearse the pitch",
		"npc": "",
		"score_key": "strategy",
		"available": true,
		"description": "Take a moment to collect your thoughts and rehearse."
	})

	objs.append({
		"id": "casey_training",
		"title": "Get Casey to prep the team",
		"npc": "casey",
		"score_key": "talent",
		"available": GameState.has_talked_to("casey"),
		"description": "Casey can give the team a last-minute confidence boost."
	})

	return objs


func _setup_npcs() -> void:
	var npcs_node = get_tree().current_scene.get_node_or_null("NPCs")
	if not npcs_node:
		return

	for npc_node in npcs_node.get_children():
		if npc_node.has_method("enter_boss_fight"):
			var npc_id = npc_node.npc_id
			var pos = npc_positions.get(npc_id, npc_node.global_position)
			npc_node.enter_boss_fight(pos)

			# Check if this NPC has an objective
			for obj in objectives:
				if obj["npc"] == npc_id and obj["available"]:
					npc_node.set_boss_task(true)


func _create_boss_fight_ui() -> void:
	# Create a CanvasLayer for boss fight HUD
	var canvas = CanvasLayer.new()
	canvas.name = "BossFightUI"
	canvas.layer = 12
	get_tree().current_scene.add_child(canvas)

	# Action counter (top center)
	action_label = Label.new()
	action_label.name = "ActionLabel"
	action_label.text = "Actions Remaining: %d" % actions_remaining
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.anchors_preset = Control.PRESET_CENTER_TOP
	action_label.offset_top = 70
	action_label.offset_left = -200
	action_label.offset_right = 200
	action_label.add_theme_font_size_override("font_size", 36)
	var font = load("res://assets/fonts/Jersey15-Regular.ttf")
	if font:
		action_label.add_theme_font_override("font", font)
	canvas.add_child(action_label)

	# Title label
	var title = Label.new()
	title.text = "THE BOARD PRESENTATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_CENTER_TOP
	title.offset_top = 20
	title.offset_left = -300
	title.offset_right = 300
	title.add_theme_font_size_override("font_size", 28)
	if font:
		title.add_theme_font_override("font", font)
	title.modulate = Color(1, 0.9, 0.5)
	canvas.add_child(title)

	# Objectives panel (right side)
	var panel = PanelContainer.new()
	panel.name = "ObjectivesPanel"
	panel.anchors_preset = Control.PRESET_RIGHT_WIDE
	panel.offset_left = -280
	panel.offset_top = 100
	panel.offset_right = -10
	panel.offset_bottom = -100
	canvas.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	objectives_container = VBoxContainer.new()
	objectives_container.name = "ObjectivesContainer"
	objectives_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(objectives_container)

	_refresh_objectives_ui()

	# "Start Presentation" button (bottom center)
	start_button = Button.new()
	start_button.name = "StartPresentationButton"
	start_button.text = "Start the Presentation"
	start_button.anchors_preset = Control.PRESET_CENTER_BOTTOM
	start_button.offset_left = -150
	start_button.offset_right = 150
	start_button.offset_top = -60
	start_button.offset_bottom = -20
	start_button.add_theme_font_size_override("font_size", 24)
	if font:
		start_button.add_theme_font_override("font", font)
	start_button.pressed.connect(_end_boss_fight)
	canvas.add_child(start_button)


func _refresh_objectives_ui() -> void:
	if not objectives_container:
		return

	# Clear existing
	for child in objectives_container.get_children():
		child.queue_free()

	var font = load("res://assets/fonts/Jersey15-Regular.ttf")

	for obj in objectives:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var check = Label.new()
		check.custom_minimum_size = Vector2(24, 0)
		if font:
			check.add_theme_font_override("font", font)
		check.add_theme_font_size_override("font_size", 20)

		if obj["id"] in completed_objectives:
			var quality = boss_fight_results.get(obj["id"], {}).get("quality", "okay")
			match quality:
				"great":
					check.text = "**"
					check.modulate = Color(0.3, 0.9, 0.3)
				"good":
					check.text = "*"
					check.modulate = Color(0.3, 0.8, 0.3)
				"okay":
					check.text = "~"
					check.modulate = Color(0.9, 0.7, 0.2)
				"fail":
					check.text = "X"
					check.modulate = Color(0.9, 0.3, 0.3)
		elif not obj["available"]:
			check.text = "-"
			check.modulate = Color(0.5, 0.5, 0.5)
		else:
			check.text = "o"

		hbox.add_child(check)

		var label = Label.new()
		label.text = obj["title"]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		if font:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 18)

		if obj["id"] in completed_objectives:
			label.modulate = Color(0.6, 0.6, 0.6)
		elif not obj["available"]:
			label.modulate = Color(0.4, 0.4, 0.4)

		hbox.add_child(label)
		objectives_container.add_child(hbox)


## Called when player interacts with an NPC during boss fight
func attempt_objective_for_npc(npc_id: String) -> bool:
	if not is_active or actions_remaining <= 0:
		return false

	# Find matching objective
	for obj in objectives:
		if obj["npc"] == npc_id and obj["available"] and obj["id"] not in completed_objectives:
			_complete_objective(obj)
			return true

	return false


func attempt_objective(objective_id: String) -> bool:
	if not is_active or actions_remaining <= 0:
		return false

	for obj in objectives:
		if obj["id"] == objective_id and obj["available"] and obj["id"] not in completed_objectives:
			_complete_objective(obj)
			return true

	return false


func _complete_objective(obj: Dictionary) -> void:
	actions_remaining -= 1
	completed_objectives.append(obj["id"])

	# Determine quality based on relevant score
	var score_value = GameState.scores.get(obj["score_key"], 0)
	var quality = "okay"
	if score_value >= 15:
		quality = "great"
	elif score_value >= 8:
		quality = "good"
	elif score_value >= 0:
		quality = "okay"
	else:
		quality = "fail"

	boss_fight_results[obj["id"]] = {
		"quality": quality,
		"score_key": obj["score_key"],
		"score_value": score_value
	}

	# Mark NPC task complete
	var npcs_node = get_tree().current_scene.get_node_or_null("NPCs")
	if npcs_node and obj["npc"] != "":
		for npc_node in npcs_node.get_children():
			if npc_node.has_method("complete_boss_task") and npc_node.npc_id == obj["npc"]:
				npc_node.complete_boss_task()

	# Update UI
	action_label.text = "Actions Remaining: %d" % actions_remaining
	_refresh_objectives_ui()

	# Show quality feedback
	var color = Color.WHITE
	match quality:
		"great": color = Color(0.3, 0.9, 0.3)
		"good": color = Color(0.3, 0.8, 0.3)
		"okay": color = Color(0.9, 0.7, 0.2)
		"fail": color = Color(0.9, 0.3, 0.3)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		FloatingTextManager.spawn_at(quality.capitalize() + "!", player.global_position + Vector2(0, -50), color)

	action_used.emit(actions_remaining)
	objective_completed.emit(obj["id"], quality)

	# Auto-end if no actions left
	if actions_remaining <= 0:
		await get_tree().create_timer(1.5).timeout
		_end_boss_fight()


func _end_boss_fight() -> void:
	is_active = false

	# Calculate boss fight contribution to ending
	var total_quality_score = 0
	for obj_id in completed_objectives:
		var result = boss_fight_results.get(obj_id, {})
		match result.get("quality", "okay"):
			"great": total_quality_score += 3
			"good": total_quality_score += 2
			"okay": total_quality_score += 1
			"fail": total_quality_score -= 1

	boss_fight_results["total_quality"] = total_quality_score
	boss_fight_results["objectives_completed"] = completed_objectives.size()
	boss_fight_results["objectives_available"] = objectives.filter(func(o): return o["available"]).size()

	# Apply boss fight bonus to scores
	if total_quality_score > 10:
		GameState.scores["strategy"] += 5
		GameState.scores["trust"] += 5
	elif total_quality_score > 5:
		GameState.scores["strategy"] += 2
		GameState.scores["trust"] += 2

	# Store results for ending screen
	GameState.set_flag("boss_fight_complete")
	if total_quality_score > 10:
		GameState.set_flag("boss_fight_great")
	elif total_quality_score > 5:
		GameState.set_flag("boss_fight_good")
	elif total_quality_score < 0:
		GameState.set_flag("boss_fight_poor")

	# Remove boss fight UI
	var ui = get_tree().current_scene.get_node_or_null("BossFightUI")
	if ui:
		ui.queue_free()

	boss_fight_ended.emit(boss_fight_results)

	# Trigger the actual ending
	GameState.game_over.emit("presentation_complete")
