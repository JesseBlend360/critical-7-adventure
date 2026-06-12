extends Node

## DialogueManager - Manages conversation flow (Autoload singleton)
## Loads dialogue data, evaluates conditions, emits signals for UI.

signal dialogue_started(npc_id: String)
signal node_displayed(node: Dictionary)
signal choices_presented(choices: Array)  # Now includes all choices with lock info
signal dialogue_ended
signal decision_triggered(decision_id: String)  # When a choice triggers a decision

var dialogue_cache: Dictionary = {}  # Cached dialogue data per NPC
var current_npc_id: String = ""
var current_conversation_id: String = ""
var current_node_id: String = ""
var current_dialogue: Dictionary = {}
var is_active: bool = false

## v0.3: when true, the current "node" is a synthetic idle/busy line generated
## because the player has used every meaningful choice on the real node.
## In this mode the only choice is [Leave] and select_choice() just ends.
var _idle_mode: bool = false

const IDLE_LINES_PER_NPC := {
	"sage":   "Sage is mid-thought, scribbling on a notepad. \"Catch me later?\"",
	"delta":  "Delta is elbow-deep in a query plan. Doesn't look up.",
	"nova":   "Nova is muttering at a whiteboard. \"Almost… got it…\"",
	"harry":  "Harry covers his mic and mouths, \"on a call.\"",
	"rex":    "Rex is in incident mode. \"Not now, Blenda.\"",
	"morgan": "Morgan is drafting something delicate. \"One sec — actually, tomorrow?\"",
	"casey":  "Casey is wrapping a 1:1. Mouths \"catch you tomorrow?\"",
}
const IDLE_LINES_FALLBACK := [
	"Heads-down. Doesn't look up.",
	"Waves you off without looking. Busy.",
	"Mouths \"busy\" and points at the screen.",
]


func _idle_line_for(npc_id: String) -> String:
	if IDLE_LINES_PER_NPC.has(npc_id):
		return IDLE_LINES_PER_NPC[npc_id]
	return IDLE_LINES_FALLBACK[randi() % IDLE_LINES_FALLBACK.size()]


func load_dialogue(npc_id: String) -> Dictionary:
	# Return cached dialogue if available
	if dialogue_cache.has(npc_id):
		return dialogue_cache[npc_id]

	# Load from JSON file
	var path = "res://data/dialogue/" + npc_id + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open dialogue file: " + path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_text)
	if data == null:
		push_error("Failed to parse dialogue JSON: " + path)
		return {}

	dialogue_cache[npc_id] = data
	return data


func start_conversation(npc_id: String) -> void:
	current_dialogue = load_dialogue(npc_id)
	if current_dialogue.is_empty():
		push_error("No dialogue data for NPC: " + npc_id)
		return

	current_npc_id = npc_id
	is_active = true
	_idle_mode = false

	# Select which conversation to use based on state
	current_conversation_id = select_conversation(npc_id)
	if current_conversation_id.is_empty():
		push_error("No valid conversation found for NPC: " + npc_id)
		end_conversation()
		return

	var conversation = current_dialogue["conversations"][current_conversation_id]
	current_node_id = conversation["start_node"]

	# Mark NPC as talked to
	GameState.mark_talked_to(npc_id)

	dialogue_started.emit(npc_id)
	_display_current_node()


func select_conversation(npc_id: String) -> String:
	if not current_dialogue.has("conversations"):
		return ""

	var conversations = current_dialogue["conversations"]
	var default_id: String = ""

	for conv_id in conversations:
		var conv = conversations[conv_id]
		var trigger = conv.get("trigger", "default")

		# Check trigger conditions if present
		if conv.has("trigger_conditions"):
			if not GameState.check_conditions(conv["trigger_conditions"]):
				continue

		match trigger:
			"first_meeting":
				if not GameState.has_talked_to(npc_id):
					return conv_id
			"return_visit":
				if GameState.has_talked_to(npc_id):
					return conv_id
			"default":
				default_id = conv_id
			_:
				# Check for flag-based triggers like "flag:some_flag"
				if trigger.begins_with("flag:"):
					var flag_name = trigger.substr(5)
					if GameState.has_flag(flag_name):
						return conv_id

	return default_id


func get_current_node() -> Dictionary:
	if current_conversation_id.is_empty() or current_node_id.is_empty():
		return {}

	var conversation = current_dialogue["conversations"].get(current_conversation_id, {})
	var nodes = conversation.get("nodes", {})
	return nodes.get(current_node_id, {})


## Get all choices with availability info (for showing locked choices)
func get_all_choices_with_status() -> Array:
	var node = get_current_node()
	if not node.has("choices"):
		return []

	var result: Array = []
	var orig_idx: int = -1
	for choice in node["choices"]:
		orig_idx += 1
		var choice_info = choice.duplicate()
		choice_info["original_index"] = orig_idx
		choice_info["available"] = true
		choice_info["failed_requirements"] = []

		# v0.3: hide choices the player has already picked this run.
		var chosen_key := "choice:%s:%s:%d" % [current_npc_id, current_node_id, orig_idx]
		if GameState.has_chosen_choice(chosen_key):
			choice_info["hidden"] = true
			result.append(choice_info)
			continue

		# Check legacy conditions (hidden choices)
		if choice.has("conditions"):
			if not GameState.check_conditions(choice["conditions"]):
				choice_info["hidden"] = true
				result.append(choice_info)
				continue  # These choices are hidden entirely

		# Check "requires" field (visible but possibly locked)
		if choice.has("requires"):
			var check_result = GameState.check_conditions_detailed(choice["requires"])
			if not check_result["allowed"]:
				choice_info["available"] = false
				choice_info["failed_requirements"] = check_result["failed"]

		# Check if adds_decision is possible
		if choice.has("adds_decision"):
			var decision_id = choice["adds_decision"]
			var can_make = DecisionManager.can_make_decision(decision_id)
			if not can_make["allowed"]:
				choice_info["available"] = false
				# Add decision-related failures
				for reason in can_make["reasons"]:
					choice_info["failed_requirements"].append({
						"type": "decision_blocked",
						"reason": reason
					})

			# Add cost info for display
			var decision = DecisionManager.get_decision(decision_id)
			if not decision.is_empty():
				choice_info["decision_cost"] = decision.get("cost", {})
				choice_info["decision_title"] = decision.get("title", "")

		result.append(choice_info)

	return result


## Get only available choices (legacy compatibility)
func get_available_choices() -> Array:
	var all_choices = get_all_choices_with_status()
	var available: Array = []
	for choice in all_choices:
		if choice.get("available", true) and not choice.get("hidden", false):
			available.append(choice)
	return available


## Select a choice by index from all visible choices
func select_choice(index: int) -> void:
	# v0.3: idle mode = synthetic "NPC is busy" line, only choice is [Leave].
	if _idle_mode:
		end_conversation()
		return

	var all_choices = get_all_choices_with_status()

	# Filter to visible choices only (not hidden)
	var visible_choices: Array = []
	for choice in all_choices:
		if not choice.get("hidden", false):
			visible_choices.append(choice)

	if index < 0 or index >= visible_choices.size():
		push_error("Invalid choice index: " + str(index))
		return

	var choice = visible_choices[index]

	# Check if choice is locked
	if not choice.get("available", true):
		push_warning("Attempted to select locked choice")
		return

	# v0.3: stable per-choice key — original_index survives hide-filtering.
	var orig_index: int = int(choice.get("original_index", index))
	var key := "choice:%s:%s:%d" % [current_npc_id, current_node_id, orig_index]

	# Mark this choice as used so it disappears on subsequent visits.
	GameState.mark_choice_chosen(key)

	# Apply decision if this choice triggers one
	if choice.has("adds_decision"):
		var decision_id = choice["adds_decision"]
		if DecisionManager.make_decision(decision_id):
			decision_triggered.emit(decision_id)

	# Apply effects from choice — once per run, keyed by NPC/node/choice index.
	# Prevents score-grinding by repeatedly picking the same choice.
	if choice.has("effects"):
		GameState.apply_effects_once(key, choice["effects"])

	# Apply flags from choice
	if choice.has("flags"):
		if choice["flags"].has("set"):
			for flag in choice["flags"]["set"]:
				GameState.set_flag(flag)
		if choice["flags"].has("unset"):
			for flag in choice["flags"]["unset"]:
				GameState.unset_flag(flag)

	# Go to next node
	var next_node = choice.get("next")
	if next_node == null or next_node == "":
		end_conversation()
	else:
		current_node_id = next_node
		_display_current_node()


func advance() -> void:
	var node = get_current_node()
	var next_node = node.get("next")

	if next_node == null or next_node == "":
		end_conversation()
	else:
		current_node_id = next_node
		_display_current_node()


func end_conversation() -> void:
	# Store last visited node for this NPC
	if not current_npc_id.is_empty() and not current_node_id.is_empty():
		GameState.dialogue_history[current_npc_id] = current_node_id

	current_npc_id = ""
	current_conversation_id = ""
	current_node_id = ""
	current_dialogue = {}
	is_active = false

	dialogue_ended.emit()


func _display_current_node() -> void:
	var node = get_current_node()
	if node.is_empty():
		end_conversation()
		return

	# Check node conditions
	if node.has("conditions"):
		if not GameState.check_conditions(node["conditions"]):
			# Try fallback or end
			var fallback = node.get("fallback")
			if fallback:
				current_node_id = fallback
				_display_current_node()
				return
			else:
				end_conversation()
				return

	# Apply effects from node — once per run, keyed by NPC/node id.
	# Prevents score-grinding by re-entering the conversation.
	if node.has("effects"):
		var key := "node:%s:%s" % [current_npc_id, current_node_id]
		GameState.apply_effects_once(key, node["effects"])

	# Apply flags from node
	if node.has("flags"):
		if node["flags"].has("set"):
			for flag in node["flags"]["set"]:
				GameState.set_flag(flag)
		if node["flags"].has("unset"):
			for flag in node["flags"]["unset"]:
				GameState.unset_flag(flag)

	# v0.3: if every choice on this node is hidden (chosen already or
	# condition-locked away), substitute a synthetic "NPC is busy" line so
	# the player always sees *something* and can dismiss with [Leave].
	if node.has("choices"):
		var all_choices = get_all_choices_with_status()
		var visible_choices: Array = []
		for choice in all_choices:
			if not choice.get("hidden", false):
				visible_choices.append(choice)

		if visible_choices.is_empty():
			_emit_idle_node()
			return

		# Normal flow.
		node_displayed.emit(node)
		choices_presented.emit(visible_choices)
		return

	# Node has no choices block at all (linear node) — fall through to display.
	node_displayed.emit(node)


## v0.3: build and emit a synthetic single-line "busy" node + a [Leave] choice.
func _emit_idle_node() -> void:
	_idle_mode = true
	var npc_name: String = current_npc_id.capitalize()
	var idle_node := {
		"speaker": npc_name,
		"text": _idle_line_for(current_npc_id),
		"npc_id": current_npc_id,
		"_synthetic_idle": true,
	}
	node_displayed.emit(idle_node)
	choices_presented.emit([
		{"text": "[Leave]", "available": true, "failed_requirements": []}
	])
