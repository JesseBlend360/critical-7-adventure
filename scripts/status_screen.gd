extends CanvasLayer

## Status Screen - Full project status display
## Shows Critical 7 scores, budget, timeline, trajectory, decision count

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var scores_container: VBoxContainer = $Panel/VBox/ScoresContainer
@onready var budget_label: Label = $Panel/VBox/ResourcesContainer/BudgetLabel
@onready var week_label: Label = $Panel/VBox/ResourcesContainer/WeekLabel
@onready var trajectory_label: Label = $Panel/VBox/TrajectoryLabel
@onready var decision_count_label: Label = $Panel/VBox/DecisionCountLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

var is_visible: bool = false

# Score bar nodes (created dynamically)
var score_bars: Dictionary = {}

const SCORE_NAMES = {
	"strategy": "Strategy",
	"data": "Data",
	"technical": "Technical",
	"innovation": "Innovation",
	"change": "Change",
	"talent": "Talent",
	"trust": "Trust"
}


func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(_on_close_pressed)
	_create_score_bars()


func _unhandled_input(event: InputEvent) -> void:
	# Cancel action closes the screen
	if (event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel")) and is_visible:
		hide_screen()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
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
	panel.visible = true
	is_visible = true


func hide_screen() -> void:
	panel.visible = false
	is_visible = false


func _on_close_pressed() -> void:
	hide_screen()


func _create_score_bars() -> void:
	# Create score display rows dynamically
	for score_id in SCORE_NAMES:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label = Label.new()
		name_label.text = SCORE_NAMES[score_id]
		name_label.custom_minimum_size = Vector2(100, 0)
		hbox.add_child(name_label)

		var bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(150, 20)
		bar.min_value = -20
		bar.max_value = 30
		bar.value = 0
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(bar)

		var value_label = Label.new()
		value_label.text = "0"
		value_label.custom_minimum_size = Vector2(40, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(value_label)

		scores_container.add_child(hbox)
		score_bars[score_id] = {"bar": bar, "label": value_label}


func _update_display() -> void:
	# Update scores
	for score_id in SCORE_NAMES:
		var value = GameState.scores.get(score_id, 0)
		score_bars[score_id]["bar"].value = value
		score_bars[score_id]["label"].text = str(value)

		# Color code based on value
		var bar = score_bars[score_id]["bar"]
		if value < 0:
			bar.modulate = Color(0.9, 0.3, 0.3)  # Red
		elif value < 10:
			bar.modulate = Color(0.9, 0.7, 0.2)  # Yellow
		else:
			bar.modulate = Color(0.3, 0.8, 0.3)  # Green

	# Update resources
	budget_label.text = "Budget: $%sK / $%sK" % [
		GameState.budget / 1000,
		GameState.budget_total / 1000
	]
	week_label.text = "Week: %d / %d" % [
		GameState.current_week,
		GameState.total_weeks
	]

	# Update trajectory
	trajectory_label.text = DecisionManager.get_trajectory_text()

	# Update decision count
	decision_count_label.text = "Decisions Made: %d" % GameState.get_decision_count()
