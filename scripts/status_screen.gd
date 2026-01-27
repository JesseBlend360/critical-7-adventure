extends CanvasLayer

## Critical 7 Status Screen - Full-screen pause menu
## Shows the 7 AI strategy dimensions with scores and advice
## Pauses the game while open

@onready var background: ColorRect = $Background
@onready var content: MarginContainer = $Content
@onready var left_scores: VBoxContainer = $Content/VBox/MainContent/LeftScores
@onready var right_scores: VBoxContainer = $Content/VBox/MainContent/RightScores
@onready var budget_label: Label = $Content/VBox/BottomInfo/BudgetLabel
@onready var week_label: Label = $Content/VBox/BottomInfo/WeekLabel
@onready var decision_count_label: Label = $Content/VBox/BottomInfo/DecisionCountLabel
@onready var trajectory_label: Label = $Content/VBox/TrajectoryLabel

var is_visible: bool = false

# Score display order: left side, then right side
const LEFT_SCORES = ["strategy", "trust", "talent"]
const RIGHT_SCORES = ["data", "change", "technical", "innovation"]

const SCORE_DISPLAY = {
	"strategy": {"name": "STRATEGY", "subtitle": "Integrate Business Strategies"},
	"trust": {"name": "TRUST", "subtitle": "Create Trust & Ethics"},
	"talent": {"name": "TALENT", "subtitle": "Grow AI Talent"},
	"data": {"name": "DATA", "subtitle": "Build Strong Data Foundations"},
	"change": {"name": "CHANGE", "subtitle": "Enable Change Management"},
	"technical": {"name": "TECHNICAL", "subtitle": "Develop Technical Approach"},
	"innovation": {"name": "INNOVATION", "subtitle": "Accelerate Innovation"},
}

const ADVICE = {
	"strategy": {
		"critical": "Strategic alignment has failed. Talk to Sage urgently.",
		"low": "Consult Sage about aligning AI with business goals.",
		"medium": "Strategy is developing. Keep stakeholders engaged.",
		"high": "Strong alignment. Business value is clear.",
	},
	"trust": {
		"critical": "Trust has collapsed. Rebuild with Harry immediately.",
		"low": "Build trust with Harry and key stakeholders.",
		"medium": "Trust is building. Keep promises realistic.",
		"high": "Stakeholder confidence is strong.",
	},
	"talent": {
		"critical": "Team is overwhelmed. Address workload now.",
		"low": "Invest in team development and training.",
		"medium": "Team is holding steady. Watch for burnout.",
		"high": "Team is thriving and growing.",
	},
	"data": {
		"critical": "Data foundations are broken. See Delta now.",
		"low": "Work with Delta on data quality issues.",
		"medium": "Data quality improving. Continue refinement.",
		"high": "Data foundations are solid.",
	},
	"change": {
		"critical": "Resistance is too high. Revisit your approach.",
		"low": "Focus on adoption and change management.",
		"medium": "Change is happening. Stay persistent.",
		"high": "Organization is adapting well.",
	},
	"technical": {
		"critical": "Technical approach is failing. Consult Nova.",
		"low": "Review technical decisions with Nova.",
		"medium": "Architecture is sound. Monitor tech debt.",
		"high": "Technical foundation is excellent.",
	},
	"innovation": {
		"critical": "Innovation has stalled. Take calculated risks.",
		"low": "Encourage experimentation and prototyping.",
		"medium": "Innovation is steady. Seek breakthroughs.",
		"high": "Team is innovating effectively.",
	},
}

# Score items keyed by score_id
var score_items: Dictionary = {}

# Preload font for dynamic labels
var font: Font


func _ready() -> void:
	font = load("res://assets/fonts/Jersey15-Regular.ttf")
	background.visible = false
	content.visible = false
	_build_score_displays()


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel")) and is_visible:
		hide_screen()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB and not DialogueManager.is_active:
			toggle_screen()
			get_viewport().set_input_as_handled()


func toggle_screen() -> void:
	if is_visible:
		hide_screen()
	else:
		show_screen()


func show_screen() -> void:
	_update_display()
	background.visible = true
	content.visible = true
	is_visible = true
	get_tree().paused = true


func hide_screen() -> void:
	background.visible = false
	content.visible = false
	is_visible = false
	get_tree().paused = false


func _build_score_displays() -> void:
	for score_id in LEFT_SCORES:
		var item = _create_score_item(score_id)
		left_scores.add_child(item)

	for score_id in RIGHT_SCORES:
		var item = _create_score_item(score_id)
		right_scores.add_child(item)


func _create_score_item(score_id: String) -> VBoxContainer:
	var info = SCORE_DISPLAY[score_id]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	# Dimension name + score value
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	var name_label = Label.new()
	name_label.text = info["name"]
	name_label.add_theme_font_override("font", font)
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(0, 0.9, 0.9, 1))
	header.add_child(name_label)

	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "0"
	score_label.add_theme_font_override("font", font)
	score_label.add_theme_font_size_override("font_size", 28)
	header.add_child(score_label)

	vbox.add_child(header)

	# Subtitle
	var subtitle_label = Label.new()
	subtitle_label.text = info["subtitle"]
	subtitle_label.add_theme_font_override("font", font)
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 1))
	vbox.add_child(subtitle_label)

	# Advice
	var advice_label = Label.new()
	advice_label.name = "AdviceLabel"
	advice_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	advice_label.add_theme_font_override("font", font)
	advice_label.add_theme_font_size_override("font_size", 20)
	advice_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 1))
	vbox.add_child(advice_label)

	score_items[score_id] = {
		"container": vbox,
		"score_label": score_label,
		"advice_label": advice_label,
	}

	return vbox


func _update_display() -> void:
	# Update scores and advice
	for score_id in score_items:
		var value = GameState.scores.get(score_id, 0)
		var item = score_items[score_id]

		# Score value with sign
		var score_label: Label = item["score_label"]
		if value > 0:
			score_label.text = "+%d" % value
		else:
			score_label.text = str(value)

		# Color code
		if value < 0:
			score_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		elif value < 10:
			score_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		else:
			score_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))

		# Advice
		var advice_label: Label = item["advice_label"]
		advice_label.text = _get_advice(score_id, value)

	# Resources
	budget_label.text = "Budget: $%dK / $%dK" % [
		GameState.budget / 1000,
		GameState.budget_total / 1000,
	]
	week_label.text = "Week: %d / %d" % [
		GameState.current_week,
		GameState.total_weeks,
	]
	decision_count_label.text = "Decisions: %d" % GameState.get_decision_count()

	# Trajectory
	trajectory_label.text = DecisionManager.get_trajectory_text()


func _get_advice(score_id: String, value: int) -> String:
	var tier = "medium"
	if value < -5:
		tier = "critical"
	elif value < 5:
		tier = "low"
	elif value >= 15:
		tier = "high"

	return ADVICE.get(score_id, {}).get(tier, "Keep working on this area.")
