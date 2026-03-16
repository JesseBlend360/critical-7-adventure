extends StaticBody2D

## Computer terminal for sending company-wide messages
## Uses the same interaction pattern as door.gd / interactable.gd
## Messages are decisions applied via DecisionManager
## Morgan's comm plan flag determines prepared vs unprepared variant

@export var terminal_sprite_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_zone: Area2D = $InteractionZone
@onready var prompt_label: Label = $PromptLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player_in_range: bool = false
var terminal_open: bool = false

# Terminal UI nodes (created in code)
var terminal_ui: CanvasLayer
var message_buttons: Array[Button] = []
var preview_label: RichTextLabel
var status_label: Label
var send_button: Button
var back_button: Button

# Message data
var messages: Array = []
var selected_message_index: int = -1

# Font
var font: Font


func _ready() -> void:
	prompt_label.visible = false
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

	if terminal_sprite_texture:
		sprite.texture = terminal_sprite_texture

	_load_messages()
	font = load("res://assets/fonts/Jersey15-Regular.ttf")


func _load_messages() -> void:
	var file = FileAccess.open("res://data/terminal_messages.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()
		if error == OK:
			var data = json.get_data()
			if data.has("messages"):
				messages = data["messages"]
				print("Terminal: Loaded ", messages.size(), " messages")
		else:
			push_error("Terminal: Failed to parse terminal_messages.json")


func interact() -> void:
	if not player_in_range or terminal_open:
		return
	_open_terminal()


func _open_terminal() -> void:
	terminal_open = true
	GameManager.start_dialogue()
	_build_terminal_ui()


func _close_terminal() -> void:
	terminal_open = false
	if terminal_ui:
		terminal_ui.queue_free()
		terminal_ui = null
	message_buttons.clear()
	selected_message_index = -1
	GameManager.end_dialogue()


func _unhandled_input(event: InputEvent) -> void:
	if not terminal_open:
		return

	if event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_terminal()


func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_width_left = 2
	s.border_width_right = 2
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _build_terminal_ui() -> void:
	terminal_ui = CanvasLayer.new()
	terminal_ui.layer = 10
	add_child(terminal_ui)

	# Full-screen dim overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	terminal_ui.add_child(overlay)

	# Main panel - dark terminal look, larger
	var panel = PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -480
	panel.offset_right = 480
	panel.offset_top = -340
	panel.offset_bottom = 340

	# Terminal-style panel theme
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.04)
	style.border_color = Color(0.2, 0.7, 0.2, 0.9)
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	terminal_ui.add_child(panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "NEXUS DYNAMICS INTERNAL MESSAGING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	main_vbox.add_child(title)

	# Divider
	var divider = HSeparator.new()
	divider.add_theme_constant_override("separation", 8)
	divider.add_theme_color_override("separator", Color(0.2, 0.6, 0.2, 0.5))
	main_vbox.add_child(divider)

	# Content split: left (message list) + right (preview)
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 20)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# Left panel: message list
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 0.45
	content_hbox.add_child(left_vbox)

	var list_label = Label.new()
	list_label.text = "MESSAGES"
	if font:
		list_label.add_theme_font_override("font", font)
	list_label.add_theme_font_size_override("font_size", 30)
	list_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	left_vbox.add_child(list_label)

	# Message buttons — styled as proper terminal entries
	message_buttons.clear()
	for i in range(messages.size()):
		var msg = messages[i]
		var btn = Button.new()
		btn.text = msg["title"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if font:
			btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 28)
		btn.custom_minimum_size = Vector2(0, 56)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD

		var msg_state = _get_message_state(msg)
		_style_message_button(btn, msg_state)

		btn.pressed.connect(_on_message_selected.bind(i))
		btn.mouse_entered.connect(_on_message_hover.bind(i))
		btn.mouse_exited.connect(_on_message_hover_exit.bind(i))
		left_vbox.add_child(btn)
		message_buttons.append(btn)

	# Right panel: preview
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.55
	content_hbox.add_child(right_vbox)

	preview_label = RichTextLabel.new()
	preview_label.bbcode_enabled = true
	preview_label.scroll_active = true
	preview_label.fit_content = false
	preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if font:
		preview_label.add_theme_font_override("normal_font", font)
	preview_label.add_theme_font_size_override("normal_font_size", 26)
	preview_label.add_theme_color_override("default_color", Color(0.3, 0.85, 0.3))
	preview_label.text = "[center]Select a message to preview[/center]"
	right_vbox.add_child(preview_label)

	# Status label (Morgan reviewed / No comms plan)
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		status_label.add_theme_font_override("font", font)
	status_label.add_theme_font_size_override("font_size", 26)
	right_vbox.add_child(status_label)

	# Bottom buttons
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_theme_constant_override("separation", 30)
	main_vbox.add_child(bottom_hbox)

	send_button = Button.new()
	send_button.text = "SEND"
	send_button.custom_minimum_size = Vector2(160, 56)
	send_button.disabled = true
	if font:
		send_button.add_theme_font_override("font", font)
	send_button.add_theme_font_size_override("font_size", 32)
	var send_style = _make_button_style(Color(0.1, 0.3, 0.1), Color(0.2, 0.7, 0.2))
	send_button.add_theme_stylebox_override("normal", send_style)
	var send_hover = _make_button_style(Color(0.15, 0.4, 0.15), Color(0.3, 0.9, 0.3))
	send_button.add_theme_stylebox_override("hover", send_hover)
	var send_disabled = _make_button_style(Color(0.08, 0.1, 0.08), Color(0.15, 0.25, 0.15))
	send_button.add_theme_stylebox_override("disabled", send_disabled)
	send_button.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	send_button.pressed.connect(_on_send_pressed)
	bottom_hbox.add_child(send_button)

	back_button = Button.new()
	back_button.text = "BACK [Esc]"
	back_button.custom_minimum_size = Vector2(160, 56)
	if font:
		back_button.add_theme_font_override("font", font)
	back_button.add_theme_font_size_override("font_size", 32)
	var back_style = _make_button_style(Color(0.1, 0.1, 0.1), Color(0.3, 0.3, 0.3))
	back_button.add_theme_stylebox_override("normal", back_style)
	var back_hover = _make_button_style(Color(0.15, 0.15, 0.15), Color(0.5, 0.5, 0.5))
	back_button.add_theme_stylebox_override("hover", back_hover)
	back_button.pressed.connect(_close_terminal)
	bottom_hbox.add_child(back_button)


enum MessageState { AVAILABLE, LOCKED, SENT }

func _get_message_state(msg: Dictionary) -> MessageState:
	# Already sent?
	if GameState.has_flag(msg["sent_flag"]):
		return MessageState.SENT

	# Check unlock prerequisite
	if not GameState.has_flag(msg["unlock_flag"]):
		return MessageState.LOCKED

	return MessageState.AVAILABLE


func _style_message_button(btn: Button, state: MessageState) -> void:
	match state:
		MessageState.AVAILABLE:
			btn.disabled = false
			btn.modulate = Color.WHITE
			var normal = _make_button_style(Color(0.08, 0.15, 0.08), Color(0.2, 0.6, 0.2))
			btn.add_theme_stylebox_override("normal", normal)
			var hover = _make_button_style(Color(0.12, 0.25, 0.12), Color(0.3, 0.9, 0.3))
			btn.add_theme_stylebox_override("hover", hover)
			var focus = _make_button_style(Color(0.12, 0.25, 0.12), Color(0.4, 1.0, 0.4))
			btn.add_theme_stylebox_override("focus", focus)
			btn.add_theme_color_override("font_color", Color(0.4, 0.95, 0.4))
			btn.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 0.5))
			btn.text = "> " + btn.text
		MessageState.LOCKED:
			btn.disabled = true
			btn.modulate = Color.WHITE
			var locked = _make_button_style(Color(0.06, 0.06, 0.06), Color(0.15, 0.15, 0.15))
			btn.add_theme_stylebox_override("disabled", locked)
			btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
			btn.text = btn.text + "  [LOCKED]"
		MessageState.SENT:
			btn.disabled = true
			btn.modulate = Color.WHITE
			var sent = _make_button_style(Color(0.05, 0.08, 0.05), Color(0.1, 0.2, 0.1))
			btn.add_theme_stylebox_override("disabled", sent)
			btn.add_theme_color_override("font_disabled_color", Color(0.2, 0.35, 0.2))
			btn.text = btn.text + "  [SENT]"


func _on_message_hover(index: int) -> void:
	# Hover only shows preview text — doesn't change selection or send state
	_show_preview_only(index)


func _on_message_hover_exit(_index: int) -> void:
	# When mouse leaves a button, restore the selected message preview
	if selected_message_index >= 0:
		_show_preview_only(selected_message_index)
		_update_send_state(selected_message_index)
	else:
		preview_label.text = "[center]Select a message to preview[/center]"
		status_label.text = ""
		send_button.disabled = true


func _on_message_selected(index: int) -> void:
	# Click selects the message — updates preview AND send button
	selected_message_index = index
	_show_preview_only(index)
	_update_send_state(index)


func _show_preview_only(index: int) -> void:
	if index < 0 or index >= messages.size():
		return

	var msg = messages[index]
	var state = _get_message_state(msg)

	if state == MessageState.LOCKED:
		var flag_name = msg["unlock_flag"].replace("_", " ").capitalize()
		preview_label.text = "[color=#666666]This message is locked.\n\nRequires: " + flag_name + "[/color]"
		status_label.text = ""
		return

	if state == MessageState.SENT:
		preview_label.text = "[color=#336633]This message has already been sent.[/color]"
		status_label.text = ""
		return

	# Show preview text
	preview_label.text = msg["preview_text"]

	# Show Morgan status
	var is_prepared = GameState.has_flag("morgan_comm_plan")
	if is_prepared:
		status_label.text = "Morgan reviewed"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	else:
		status_label.text = "No comms plan!"
		status_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))


func _update_send_state(index: int) -> void:
	if index < 0 or index >= messages.size():
		send_button.disabled = true
		return

	var msg = messages[index]
	var state = _get_message_state(msg)

	if state != MessageState.AVAILABLE:
		send_button.disabled = true
		return

	var decision_id = _get_decision_id(msg)
	var can_make = DecisionManager.can_make_decision(decision_id)
	send_button.disabled = not can_make["allowed"]

	if not can_make["allowed"]:
		status_label.text = ", ".join(can_make["reasons"])
		status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _get_decision_id(msg: Dictionary) -> String:
	if GameState.has_flag("morgan_comm_plan"):
		return msg["prepared_decision"]
	else:
		return msg["unprepared_decision"]


func _on_send_pressed() -> void:
	if selected_message_index < 0 or selected_message_index >= messages.size():
		return

	var msg = messages[selected_message_index]
	var state = _get_message_state(msg)
	if state != MessageState.AVAILABLE:
		return

	var decision_id = _get_decision_id(msg)
	var success = DecisionManager.make_decision(decision_id)

	if success:
		# Show confirmation flavor text
		var is_prepared = GameState.has_flag("morgan_comm_plan")
		var flavor = ""
		if is_prepared:
			flavor = msg.get("flavor_sent_prepared", "Message sent.")
		else:
			flavor = msg.get("flavor_sent_unprepared", "Message sent.")

		preview_label.text = "[center]" + flavor + "[/center]"
		status_label.text = "SENT"
		status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		send_button.disabled = true

		# Update button state
		if selected_message_index < message_buttons.size():
			var btn = message_buttons[selected_message_index]
			# Reset text (remove old suffix if any) and add SENT
			btn.text = msg["title"] + " [SENT]"
			btn.modulate = Color(0.3, 0.5, 0.3, 0.6)
			btn.disabled = true

		# Show floating text feedback
		FloatingTextManager.spawn_at("Message Sent!", global_position + Vector2(0, -50), Color(0.3, 0.9, 0.3))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt_label.visible = true
		if body.has_method("set_nearby_npc"):
			body.set_nearby_npc(self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false
		if body.has_method("clear_nearby_npc"):
			body.clear_nearby_npc(self)
