extends CanvasLayer

## Dialogue box UI - Displays text and choices
## Responds to DialogueManager signals
## Shows locked choices with D&D-style requirement display

@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/NameLabel
@onready var text_label: Label = $Panel/TextLabel
@onready var advance_indicator: Label = $Panel/AdvanceIndicator
@onready var choices_container: VBoxContainer = $Panel/ChoicesContainer
@onready var choice_buttons: Array[Button] = [
	$Panel/ChoicesContainer/Choice1,
	$Panel/ChoicesContainer/Choice2,
	$Panel/ChoicesContainer/Choice3
]

var is_active: bool = false
var has_choices: bool = false
var current_npc_name: String = ""
var current_choices: Array = []  # Store choices for locked check

# Colors for requirement display
const COLOR_MET = Color(0.3, 0.8, 0.3)  # Green
const COLOR_UNMET = Color(0.8, 0.3, 0.3)  # Red
const COLOR_LOCKED = Color(0.5, 0.5, 0.5)  # Gray
const COLOR_COST = Color(0.9, 0.7, 0.2)  # Gold


func _ready() -> void:
	hide_dialogue()

	# Connect to DialogueManager signals
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.node_displayed.connect(_on_node_displayed)
	DialogueManager.choices_presented.connect(_on_choices_presented)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	# Connect choice button signals
	for i in range(choice_buttons.size()):
		var button = choice_buttons[i]
		button.pressed.connect(_on_choice_pressed.bind(i))


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# Handle choice selection with number keys
	if has_choices:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			# Select first choice on Space/Enter
			get_viewport().set_input_as_handled()
			_on_choice_pressed(0)
			return

		for i in range(choice_buttons.size()):
			if choice_buttons[i].visible and event is InputEventKey:
				if event.pressed and event.keycode == KEY_1 + i:
					get_viewport().set_input_as_handled()
					_on_choice_pressed(i)
					return
	else:
		# Linear dialogue - advance on Space/Enter
		if event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			DialogueManager.advance()


func _on_dialogue_started(npc_id: String) -> void:
	# Load NPC data to get display name
	var dialogue_data = DialogueManager.current_dialogue
	if dialogue_data.has("character"):
		current_npc_name = dialogue_data["character"].get("name", npc_id.capitalize())
	else:
		current_npc_name = npc_id.capitalize()

	name_label.text = current_npc_name
	show_dialogue()
	GameManager.start_dialogue()


func _on_node_displayed(node: Dictionary) -> void:
	# Show node text
	text_label.text = node.get("text", "...")

	# Update speaker name if specified
	var speaker = node.get("speaker", "npc")
	if speaker == "player":
		name_label.text = "You"
	elif speaker == "narrator":
		name_label.text = ""
	else:
		name_label.text = current_npc_name

	# Reset choice state - will be set if choices_presented fires
	has_choices = false
	hide_choices()


func _on_choices_presented(choices: Array) -> void:
	has_choices = true
	current_choices = choices
	show_choices(choices)


func _on_dialogue_ended() -> void:
	hide_dialogue()
	GameManager.end_dialogue()


func _on_choice_pressed(index: int) -> void:
	if not has_choices:
		return

	# Check if this choice is locked
	if index < current_choices.size():
		var choice = current_choices[index]
		if not choice.get("available", true):
			# Choice is locked - don't allow selection
			# TODO: Play a "locked" sound or show feedback
			return

	DialogueManager.select_choice(index)


func show_choices(choices: Array) -> void:
	# Hide all buttons first
	for button in choice_buttons:
		button.visible = false

	# Show and configure choices
	for i in range(min(choices.size(), choice_buttons.size())):
		var button = choice_buttons[i]
		var choice = choices[i]
		var is_available = choice.get("available", true)

		# Build choice text
		var choice_text = "[" + str(i + 1) + "] " + choice.get("text", "...")

		# Add cost info if this triggers a decision
		if choice.has("decision_cost"):
			var cost = choice["decision_cost"]
			var cost_parts: Array = []
			if cost.has("budget") and cost["budget"] != 0:
				cost_parts.append("$" + _format_money(cost["budget"]))
			if cost.has("time") and cost["time"] != 0:
				var weeks = cost["time"]
				cost_parts.append(str(weeks) + " week" + ("s" if weeks != 1 else ""))
			if cost_parts.size() > 0:
				choice_text += "\n    Cost: " + " | ".join(cost_parts)

		# Add requirement info for locked choices
		if not is_available and choice.has("failed_requirements"):
			var req_text = _format_requirements(choice["failed_requirements"])
			if req_text != "":
				choice_text += "\n    " + req_text

		button.text = choice_text

		# Style locked vs available choices
		if is_available:
			button.disabled = false
			button.modulate = Color.WHITE
		else:
			button.disabled = true
			button.modulate = COLOR_LOCKED

		button.visible = true

	# Show choices container, hide text label and advance indicator
	choices_container.visible = true
	text_label.visible = false
	advance_indicator.visible = false


## Format requirement failures for display (D&D style)
func _format_requirements(failures: Array) -> String:
	var parts: Array = []

	for failure in failures:
		match failure.get("type", ""):
			"min_score":
				var score_name = failure.get("score", "").capitalize()
				var required = failure.get("required", 0)
				var current = failure.get("current", 0)
				parts.append("X %s >= %d (You have: %d)" % [score_name, required, current])
			"max_score":
				var score_name = failure.get("score", "").capitalize()
				var required = failure.get("required", 0)
				var current = failure.get("current", 0)
				parts.append("X %s <= %d (You have: %d)" % [score_name, required, current])
			"flag":
				var flag = failure.get("flag", "unknown")
				parts.append("X Requires: " + flag.replace("_", " ").capitalize())
			"talked_to":
				var npc = failure.get("npc", "someone")
				parts.append("X Talk to " + npc.capitalize() + " first")
			"decision":
				var decision = failure.get("decision", "unknown")
				parts.append("X Requires: " + decision.replace("_", " ").capitalize())
			"decision_blocked":
				parts.append("X " + failure.get("reason", "Blocked"))

	return " | ".join(parts)


## Format money for display
func _format_money(amount: int) -> String:
	if amount >= 1000:
		return str(amount / 1000) + "K"
	return str(amount)


func hide_choices() -> void:
	choices_container.visible = false
	text_label.visible = true
	advance_indicator.visible = true


func show_dialogue() -> void:
	panel.visible = true
	is_active = true


func hide_dialogue() -> void:
	panel.visible = false
	is_active = false
	has_choices = false
	current_choices = []
	hide_choices()
