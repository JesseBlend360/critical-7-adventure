extends CanvasLayer

## Dialogue box UI - Displays text and choices
## Responds to DialogueManager signals

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
	show_choices(choices)


func _on_dialogue_ended() -> void:
	hide_dialogue()
	GameManager.end_dialogue()


func _on_choice_pressed(index: int) -> void:
	if has_choices:
		DialogueManager.select_choice(index)


func show_choices(choices: Array) -> void:
	# Hide all buttons first
	for button in choice_buttons:
		button.visible = false

	# Show and configure available choices
	for i in range(min(choices.size(), choice_buttons.size())):
		var button = choice_buttons[i]
		var choice = choices[i]
		button.text = "[" + str(i + 1) + "] " + choice.get("text", "...")
		button.visible = true

	# Show choices container, hide text label and advance indicator
	choices_container.visible = true
	text_label.visible = false
	advance_indicator.visible = false


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
	hide_choices()
