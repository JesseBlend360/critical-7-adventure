extends CanvasLayer

## Dialogue box UI - Displays text and choices
## Two panels: DialoguePanel (bottom) and ChoicesPanel (popup)
## Escape toggles between choices and dialogue, or closes dialogue

@onready var dialogue_panel: NinePatchRect = $DialoguePanel
@onready var name_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/NameLabel
@onready var text_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/TextLabel
@onready var advance_indicator: Label = $DialoguePanel/MarginContainer/VBoxContainer/AdvanceIndicator

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var choices_panel: NinePatchRect = $ChoicesPanel
@onready var effects_panel: NinePatchRect = $EffectsPanel
@onready var effects_label: RichTextLabel = $EffectsPanel/MarginContainer/EffectsLabel
@onready var choices_title: Label = $ChoicesPanel/MarginContainer/VBoxContainer/ChoicesTitle
@onready var choices_container: VBoxContainer = $ChoicesPanel/MarginContainer/VBoxContainer/ChoicesContainer
@onready var choice_buttons: Array[Button] = [
	$ChoicesPanel/MarginContainer/VBoxContainer/ChoicesContainer/Choice1,
	$ChoicesPanel/MarginContainer/VBoxContainer/ChoicesContainer/Choice2,
	$ChoicesPanel/MarginContainer/VBoxContainer/ChoicesContainer/Choice3
]

var is_active: bool = false
var has_choices: bool = false
var showing_choices: bool = false
var current_npc_name: String = ""
var current_choices: Array = []
var selected_choice_index: int = 0

# Colors for requirement display
const COLOR_LOCKED = Color(0.5, 0.5, 0.5)
const DIM_OPACITY = 0.6
const DIM_FADE_DURATION = 0.2

var dim_tween: Tween


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
		button.focus_entered.connect(_on_choice_focus_entered.bind(i))
		button.mouse_entered.connect(_on_choice_mouse_entered.bind(i))


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# Handle Escape/Cancel (both our custom action and built-in ui_cancel)
	if event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_handle_cancel()
		return

	# Handle input based on current view
	if showing_choices:
		_handle_choices_input(event)
	else:
		_handle_dialogue_input(event)


func _handle_cancel() -> void:
	if showing_choices:
		# Go back to dialogue view
		_hide_choices_panel()
	else:
		# Close the dialogue entirely (whether or not there are pending choices)
		DialogueManager.end_conversation()


func _handle_dialogue_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if has_choices:
			# Show the choices panel
			_show_choices_panel()
		else:
			# Advance dialogue
			DialogueManager.advance()


func _handle_choices_input(event: InputEvent) -> void:
	# Number keys to select choice
	for i in range(choice_buttons.size()):
		if choice_buttons[i].visible and event is InputEventKey:
			if event.pressed and event.keycode == KEY_1 + i:
				get_viewport().set_input_as_handled()
				_on_choice_pressed(i)
				return

	# Arrow keys to navigate choices
	if event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_move_choice_selection(-1)
		return
	if event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_move_choice_selection(1)
		return

	# Space/Enter selects currently highlighted choice
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_choice_pressed(selected_choice_index)
		return


func _on_dialogue_started(npc_id: String) -> void:
	var dialogue_data = DialogueManager.current_dialogue
	if dialogue_data.has("character"):
		current_npc_name = dialogue_data["character"].get("name", npc_id.capitalize())
	else:
		current_npc_name = npc_id.capitalize()

	name_label.text = current_npc_name
	show_dialogue()
	GameManager.start_dialogue()


func _on_node_displayed(node: Dictionary) -> void:
	text_label.text = node.get("text", "...")

	# Update speaker name
	var speaker = node.get("speaker", "npc")
	if speaker == "player":
		name_label.text = "You"
	elif speaker == "narrator":
		name_label.text = ""
	else:
		name_label.text = current_npc_name

	# Reset choice state
	has_choices = false
	showing_choices = false
	_hide_choices_panel()
	_update_advance_indicator()


func _on_choices_presented(choices: Array) -> void:
	has_choices = true
	current_choices = choices
	_populate_choices(choices)
	_update_advance_indicator()
	# Don't show choices panel yet - wait for user to advance


func _on_dialogue_ended() -> void:
	hide_dialogue()
	GameManager.end_dialogue()


func _on_choice_pressed(index: int) -> void:
	if not has_choices or not showing_choices:
		return

	# Check if choice is locked
	if index < current_choices.size():
		var choice = current_choices[index]
		if not choice.get("available", true):
			# TODO: Play locked sound
			return

	_hide_choices_panel()
	DialogueManager.select_choice(index)


func _on_choice_focus_entered(index: int) -> void:
	if showing_choices:
		_set_selected_choice(index)


func _on_choice_mouse_entered(index: int) -> void:
	if showing_choices and choice_buttons[index].visible:
		_set_selected_choice(index)


func _populate_choices(choices: Array) -> void:
	# Hide all buttons first
	for button in choice_buttons:
		button.visible = false

	# Configure visible choices
	for i in range(min(choices.size(), choice_buttons.size())):
		var button = choice_buttons[i]
		var choice = choices[i]
		var is_available = choice.get("available", true)

		# Build choice text
		var choice_text = "[" + str(i + 1) + "] " + choice.get("text", "...")

		# Add cost info
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

		# Style locked vs available
		if is_available:
			button.disabled = false
			button.modulate = Color.WHITE
		else:
			button.disabled = true
			button.modulate = COLOR_LOCKED

		button.visible = true


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


func _format_money(amount: int) -> String:
	if amount >= 1000:
		return str(amount / 1000) + "K"
	return str(amount)


func _show_choices_panel() -> void:
	showing_choices = true
	choices_panel.visible = true
	advance_indicator.text = "[Esc] Back"
	# Fade in the dim overlay
	_fade_dim_overlay(DIM_OPACITY)
	# Select first available choice
	_select_first_available_choice()


func _fade_dim_overlay(target_alpha: float) -> void:
	if dim_tween:
		dim_tween.kill()
	dim_overlay.visible = true
	dim_tween = create_tween()
	dim_tween.tween_property(dim_overlay, "color:a", target_alpha, DIM_FADE_DURATION)
	if target_alpha == 0.0:
		dim_tween.tween_callback(func(): dim_overlay.visible = false)


func _select_first_available_choice() -> void:
	for i in range(current_choices.size()):
		if current_choices[i].get("available", true):
			_set_selected_choice(i)
			return
	# If no available choices, select first one anyway
	if current_choices.size() > 0:
		_set_selected_choice(0)


func _move_choice_selection(direction: int) -> void:
	var visible_count = min(current_choices.size(), choice_buttons.size())
	if visible_count == 0:
		return

	var new_index = selected_choice_index + direction

	# Wrap around
	if new_index < 0:
		new_index = visible_count - 1
	elif new_index >= visible_count:
		new_index = 0

	_set_selected_choice(new_index)


func _set_selected_choice(index: int) -> void:
	selected_choice_index = index
	# Update button focus/highlight
	for i in range(choice_buttons.size()):
		if i == index and choice_buttons[i].visible:
			choice_buttons[i].grab_focus()
		elif choice_buttons[i].visible:
			choice_buttons[i].release_focus()
	# Update effects panel
	_update_effects_panel(index)


func _update_effects_panel(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		effects_panel.visible = false
		return

	var choice = current_choices[index]
	if not choice.has("effects") or choice["effects"].is_empty():
		effects_panel.visible = false
		return

	var effects_text = _format_effects(choice["effects"])
	if effects_text.is_empty():
		effects_panel.visible = false
		return

	effects_label.text = effects_text
	effects_panel.visible = true

	# Position the effects panel at the same Y as the selected button
	# Use call_deferred to ensure button layout is complete
	_position_effects_panel.call_deferred(index)


func _position_effects_panel(index: int) -> void:
	if index < 0 or index >= choice_buttons.size():
		return
	var button = choice_buttons[index]
	if not button.visible:
		return
	# Get button's global Y position
	var button_y = button.global_position.y
	# Calculate required height based on label content + margins
	var label_height = effects_label.get_content_height()
	var panel_height = label_height + 24 + 64  # margins (12*2) + nine-patch padding
	# Position effects panel Y to align with button
	effects_panel.offset_top = button_y
	effects_panel.offset_bottom = button_y + panel_height


func _format_effects(effects: Dictionary) -> String:
	var lines: Array = []

	for key in effects.keys():
		var value = effects[key]
		if value is int or value is float:
			var score_name = key.capitalize()
			if value > 0:
				lines.append("[color=#228b22]+%d %s[/color]" % [value, score_name])
			elif value < 0:
				lines.append("[color=red]%d %s[/color]" % [value, score_name])

	return "\n".join(lines)


func _hide_choices_panel() -> void:
	showing_choices = false
	choices_panel.visible = false
	effects_panel.visible = false
	_fade_dim_overlay(0.0)
	_update_advance_indicator()


func _update_advance_indicator() -> void:
	if has_choices:
		advance_indicator.text = "[Space] Choose ▶"
	else:
		advance_indicator.text = "[Space] ▼"


func show_dialogue() -> void:
	dialogue_panel.visible = true
	is_active = true


func hide_dialogue() -> void:
	dialogue_panel.visible = false
	if dim_tween:
		dim_tween.kill()
	dim_overlay.visible = false
	dim_overlay.color.a = 0.0
	choices_panel.visible = false
	effects_panel.visible = false
	is_active = false
	has_choices = false
	showing_choices = false
	current_choices = []
