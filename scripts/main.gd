extends Node2D

## Main scene setup script
## Shows difficulty picker at game start

var difficulty_ui: CanvasLayer


func _ready() -> void:
	_show_difficulty_picker()


func _show_difficulty_picker() -> void:
	# Pause gameplay until difficulty is chosen
	get_tree().paused = true

	difficulty_ui = CanvasLayer.new()
	difficulty_ui.layer = 25
	difficulty_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(difficulty_ui)

	# Dim background
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	difficulty_ui.add_child(overlay)

	# Center panel
	var panel = PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -200
	panel.offset_bottom = 200
	difficulty_ui.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var font = load("res://assets/fonts/Jersey15-Regular.ttf")

	# Title
	var title = Label.new()
	title.text = "CRITICAL 7"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Choose your difficulty"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		subtitle.add_theme_font_override("font", font)
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Difficulty buttons
	var difficulties = [
		{
			"diff": GameState.Difficulty.EASY,
			"label": "Easy",
			"desc": "$1M budget  |  20 weeks",
			"color": Color(0.3, 0.8, 0.3)
		},
		{
			"diff": GameState.Difficulty.MEDIUM,
			"label": "Medium",
			"desc": "$750K budget  |  16 weeks",
			"color": Color(0.9, 0.7, 0.2)
		},
		{
			"diff": GameState.Difficulty.HARD,
			"label": "Hard",
			"desc": "$500K budget  |  12 weeks",
			"color": Color(0.9, 0.3, 0.3)
		},
	]

	for d in difficulties:
		var btn = Button.new()
		btn.text = "%s\n%s" % [d["label"], d["desc"]]
		btn.custom_minimum_size = Vector2(400, 60)
		if font:
			btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(_on_difficulty_selected.bind(d["diff"]))
		vbox.add_child(btn)


func _on_difficulty_selected(diff: GameState.Difficulty) -> void:
	GameState.set_difficulty(diff)
	difficulty_ui.queue_free()
	get_tree().paused = false
