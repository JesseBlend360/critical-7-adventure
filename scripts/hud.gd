extends CanvasLayer

## HUD - Pixel art styled game status bar
## Shows budget with coin icon, week with hourglass, and Critical 7 score indicators

@onready var budget_bar: ProgressBar = $TopBar/BudgetPanel/Margin/HBox/VBox/BudgetBar
@onready var budget_label: Label = $TopBar/BudgetPanel/Margin/HBox/VBox/BudgetLabel
@onready var week_label: Label = $TopBar/WeekPanel/Margin/HBox/WeekLabel
@onready var score_container: HBoxContainer = $TopBar/ScorePanel/Margin/ScoreContainer

const SCORE_ORDER = ["strategy", "data", "technical", "innovation", "change", "talent", "trust"]
const SCORE_ABBREV = {
	"strategy": "S", "data": "D", "technical": "T", "innovation": "I",
	"change": "C", "talent": "Ta", "trust": "Tr",
}

var panel_tex: Texture2D
var font: Font
var score_indicators: Dictionary = {}
var clock_label: Label  # v0.3 day timer — created in _ready

# v0.3 toast: announce when new terminal options unlock.
var toast_panel: PanelContainer
var toast_label: Label
var toast_tween: Tween
# Map of unlock_flag -> message title, loaded from data/terminal_messages.json.
var _terminal_unlocks: Dictionary = {}


func _ready() -> void:
	panel_tex = load("res://assets/ui/panel_small.png")
	font = load("res://assets/fonts/Jersey15-Regular.ttf")

	# Style the progress bar to match pixel art palette
	_style_budget_bar()

	# Build the 7 score indicators
	_build_score_indicators()

	# v0.3: add the day clock readout next to the week label.
	_build_clock_label()

	# Connect to GameState signals
	GameState.budget_changed.connect(_on_budget_changed)
	GameState.week_changed.connect(_on_week_changed)
	GameState.score_changed.connect(_on_score_changed)

	# Day clock signals — use hour_changed (fires only when the displayed
	# tick advances) instead of tick (which fires every frame).
	DayClock.hour_changed.connect(_on_clock_hour_changed)
	DayClock.day_ending_soon.connect(_on_clock_ending_soon)
	DayClock.day_ended.connect(_on_clock_ended)
	DayClock.pause_state_changed.connect(_on_clock_pause_changed)
	DayClock.qbr_started.connect(_on_qbr_started)

	# v0.3 terminal notifications: build the toast and subscribe to flag events.
	_load_terminal_unlocks()
	_build_toast()
	GameState.flag_set.connect(_on_flag_set)
	DecisionManager.decision_applied.connect(_on_decision_applied)

	# Initial update
	_update_budget_display()
	_update_week_display()
	_update_all_scores()
	_update_clock_display()


func _build_clock_label() -> void:
	# Sibling of WeekLabel inside the existing WeekPanel HBox.
	var hbox := week_label.get_parent()
	if hbox == null:
		return
	clock_label = Label.new()
	clock_label.name = "ClockLabel"
	clock_label.text = "Mon 8:00 AM"
	if font:
		clock_label.add_theme_font_override("font", font)
	clock_label.add_theme_font_size_override("font_size", 26)
	clock_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	clock_label.add_theme_constant_override("outline_size", 0)
	hbox.add_child(clock_label)


func _update_clock_display() -> void:
	if clock_label == null:
		return
	clock_label.text = DayClock.format_virtual_time()
	# Dim when paused so the player feels the rule.
	if DayClock.is_paused() or not DayClock.is_running():
		clock_label.modulate = Color(1, 1, 1, 0.45)
	else:
		clock_label.modulate = Color(1, 1, 1, 1.0)


func _on_clock_hour_changed(_day_index: int, _hour24: int) -> void:
	_update_clock_display()


func _on_clock_ending_soon() -> void:
	if clock_label:
		clock_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3))


func _on_clock_ended() -> void:
	if clock_label:
		clock_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2))
		clock_label.text = "Fri 5:00 PM"


func _on_clock_pause_changed(_is_paused_now: bool) -> void:
	if GameState.is_qbr_pending:
		return  # QBR overrides — don't repaint with "Fri 5:00 PM"
	_update_clock_display()


func _on_qbr_started() -> void:
	if clock_label:
		clock_label.text = "🎤 QBR"
		clock_label.add_theme_color_override("font_color", Color(0.95, 0.6, 0.2))
		clock_label.modulate = Color(1, 1, 1, 1)
	_update_week_display()  # repaint "Wk X / Y" → "QBR Week"
	show_toast("Head to the conference room.", Color(0.95, 0.6, 0.2))


func _style_budget_bar() -> void:
	# Create pixel-art styled progress bar using StyleBoxFlat
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.25, 0.2, 0.18)
	bg.border_color = Color(0.15, 0.12, 0.1)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(0)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.75, 0.4)
	fill.set_corner_radius_all(0)

	budget_bar.add_theme_stylebox_override("background", bg)
	budget_bar.add_theme_stylebox_override("fill", fill)


func _build_score_indicators() -> void:
	for score_id in SCORE_ORDER:
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 0)
		vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		# Panel icon (modulated by score health)
		var icon := TextureRect.new()
		icon.texture = panel_tex
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(20, 20)
		vbox.add_child(icon)

		# Abbreviation label
		var label := Label.new()
		label.text = SCORE_ABBREV[score_id]
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)

		score_container.add_child(vbox)
		score_indicators[score_id] = icon

	_update_all_scores()


func _on_budget_changed(_new_budget: int, _old_budget: int) -> void:
	_update_budget_display()


func _on_week_changed(_new_week: int) -> void:
	_update_week_display()


func _on_score_changed(score_name: String, _change: int, _new_value: int) -> void:
	_update_score_indicator(score_name)


func _update_budget_display() -> void:
	var budget = GameState.budget
	var total = GameState.budget_total
	var percent = GameState.get_budget_percent()

	budget_bar.value = percent
	budget_label.text = "$%sK / $%sK" % [budget / 1000, total / 1000]

	# Update fill color based on budget health
	var fill: StyleBoxFlat = budget_bar.get_theme_stylebox("fill")
	if percent < 20:
		fill.bg_color = Color(0.85, 0.25, 0.2)
	elif percent < 40:
		fill.bg_color = Color(0.85, 0.65, 0.15)
	else:
		fill.bg_color = Color(0.3, 0.75, 0.4)


func _update_week_display() -> void:
	# v0.3: in QBR pending mode the in-game week has crossed past total_weeks.
	# Display the readout as "QBR Week" instead of the nonsensical "Wk 17 / 16".
	if GameState.is_qbr_pending:
		week_label.text = "QBR Week"
		week_label.add_theme_color_override("font_color", Color(0.95, 0.6, 0.2))
		return

	var current = GameState.current_week
	var total = GameState.total_weeks
	week_label.text = "Wk %d / %d" % [current, total]

	var percent = GameState.get_timeline_percent()
	if percent > 90:
		week_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	elif percent > 75:
		week_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	else:
		week_label.remove_theme_color_override("font_color")


func _update_all_scores() -> void:
	for score_id in SCORE_ORDER:
		_update_score_indicator(score_id)


func _update_score_indicator(score_id: String) -> void:
	if score_id not in score_indicators:
		return
	var icon: TextureRect = score_indicators[score_id]
	var value: int = GameState.scores.get(score_id, 0)

	# Color code: red (critical) -> yellow (low) -> green (good) -> bright green (high)
	if value < -5:
		icon.modulate = Color(0.9, 0.25, 0.2)
	elif value < 5:
		icon.modulate = Color(0.9, 0.7, 0.2)
	elif value < 15:
		icon.modulate = Color(0.4, 0.8, 0.4)
	else:
		icon.modulate = Color(0.3, 0.95, 0.5)


# ────────────────────────────────────────────────────────────────────────────
# v0.3: terminal notifications
#
# Whenever a new flag is set, check whether that flag is an `unlock_flag` for a
# terminal message. If so, show a brief toast telling the player a new option
# is waiting at the terminal. Also fires when a decision is applied so we
# can announce post-send option changes.

func _load_terminal_unlocks() -> void:
	var file = FileAccess.open("res://data/terminal_messages.json", FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return
	var data = json.get_data()
	if not (data is Dictionary) or not data.has("messages"):
		return
	for msg in data["messages"]:
		if msg.has("unlock_flag"):
			_terminal_unlocks[msg["unlock_flag"]] = msg.get("title", msg.get("id", ""))


func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.name = "TerminalToast"
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toast_panel.offset_left = -440
	toast_panel.offset_right = -24
	toast_panel.offset_top = 96
	toast_panel.offset_bottom = 148
	toast_panel.modulate = Color(1, 1, 1, 0)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.20, 0.16, 0.92)
	sb.border_color = Color(0.45, 0.85, 0.55)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	toast_panel.add_theme_stylebox_override("panel", sb)

	toast_label = Label.new()
	toast_label.text = ""
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if font:
		toast_label.add_theme_font_override("font", font)
	toast_label.add_theme_font_size_override("font_size", 22)
	toast_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	toast_panel.add_child(toast_label)

	add_child(toast_panel)


## Public-ish: anyone can call this to surface a notification.
func show_toast(text: String, accent: Color = Color(0.45, 0.85, 0.55)) -> void:
	if toast_panel == null or toast_label == null:
		return
	toast_label.text = text

	# Re-tint the border to match the accent color.
	var sb: StyleBoxFlat = toast_panel.get_theme_stylebox("panel")
	if sb:
		sb.border_color = accent

	# Kill in-flight tween so back-to-back toasts don't fight each other.
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()

	toast_tween = create_tween()
	toast_tween.set_trans(Tween.TRANS_SINE)
	toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.25)
	toast_tween.tween_interval(3.0)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)


func _on_flag_set(flag: String) -> void:
	if _terminal_unlocks.has(flag):
		var title: String = _terminal_unlocks[flag]
		show_toast("📨  New terminal option: %s" % title)


func _on_decision_applied(decision_id: String, _decision_data: Dictionary) -> void:
	# Only nudge for terminal-sourced decisions (e.g. "terminal_announce_prepared").
	# Dialogue-driven decisions don't change the terminal directly and would
	# show this mid-conversation, which is confusing.
	if decision_id.begins_with("terminal_"):
		show_toast("Terminal options updated.", Color(0.55, 0.70, 0.95))
