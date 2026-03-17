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


func _ready() -> void:
	panel_tex = load("res://assets/ui/panel_small.png")
	font = load("res://assets/fonts/Jersey15-Regular.ttf")

	# Style the progress bar to match pixel art palette
	_style_budget_bar()

	# Build the 7 score indicators
	_build_score_indicators()

	# Connect to GameState signals
	GameState.budget_changed.connect(_on_budget_changed)
	GameState.week_changed.connect(_on_week_changed)
	GameState.score_changed.connect(_on_score_changed)

	# Initial update
	_update_budget_display()
	_update_week_display()
	_update_all_scores()


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
