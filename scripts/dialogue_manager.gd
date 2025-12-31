extends Node

## DialogueManager - Manages conversation flow (Autoload singleton)
## Loads dialogue data, evaluates conditions, emits signals for UI.

signal dialogue_started(npc_id: String)
signal node_displayed(node: Dictionary)
signal choices_presented(choices: Array)
signal dialogue_ended

var dialogue_cache: Dictionary = {}  # Cached dialogue data per NPC
var current_npc_id: String = ""
var current_conversation_id: String = ""
var current_node_id: String = ""
var current_dialogue: Dictionary = {}
var is_active: bool = false


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


func get_available_choices() -> Array:
	var node = get_current_node()
	if not node.has("choices"):
		return []

	var available: Array = []
	for choice in node["choices"]:
		# Check conditions for this choice
		if choice.has("conditions"):
			if not GameState.check_conditions(choice["conditions"]):
				continue
		available.append(choice)

	return available


func select_choice(index: int) -> void:
	var choices = get_available_choices()
	if index < 0 or index >= choices.size():
		push_error("Invalid choice index: " + str(index))
		return

	var choice = choices[index]

	# Apply effects from choice
	if choice.has("effects"):
		GameState.apply_effects(choice["effects"])

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

	# Apply effects from node
	if node.has("effects"):
		GameState.apply_effects(node["effects"])

	# Apply flags from node
	if node.has("flags"):
		if node["flags"].has("set"):
			for flag in node["flags"]["set"]:
				GameState.set_flag(flag)
		if node["flags"].has("unset"):
			for flag in node["flags"]["unset"]:
				GameState.unset_flag(flag)

	# Emit node display signal
	node_displayed.emit(node)

	# Check for choices
	var choices = get_available_choices()
	if choices.size() > 0:
		choices_presented.emit(choices)
