extends CanvasLayer

## HUD - Minimal always-visible game status
## Shows budget, week, and CHIP companion

@onready var budget_bar: ProgressBar = $TopBar/BudgetContainer/BudgetBar
@onready var budget_label: Label = $TopBar/BudgetContainer/BudgetLabel
@onready var week_label: Label = $TopBar/WeekContainer/WeekLabel


func _ready() -> void:
	# Connect to GameState signals
	GameState.budget_changed.connect(_on_budget_changed)
	GameState.week_changed.connect(_on_week_changed)

	# Initial update
	_update_budget_display()
	_update_week_display()


func _on_budget_changed(_new_budget: int, _old_budget: int) -> void:
	_update_budget_display()


func _on_week_changed(_new_week: int) -> void:
	_update_week_display()


func _update_budget_display() -> void:
	var budget = GameState.budget
	var total = GameState.budget_total
	var percent = GameState.get_budget_percent()

	budget_bar.value = percent
	budget_label.text = "$%sK / $%sK" % [budget / 1000, total / 1000]

	# Color code based on budget health
	if percent < 20:
		budget_bar.modulate = Color(0.9, 0.3, 0.3)  # Red
	elif percent < 40:
		budget_bar.modulate = Color(0.9, 0.7, 0.2)  # Yellow
	else:
		budget_bar.modulate = Color(0.3, 0.8, 0.3)  # Green


func _update_week_display() -> void:
	var current = GameState.current_week
	var total = GameState.total_weeks
	week_label.text = "Week %d / %d" % [current, total]

	# Color code based on time pressure
	var percent = GameState.get_timeline_percent()
	if percent > 90:
		week_label.modulate = Color(0.9, 0.3, 0.3)  # Red
	elif percent > 75:
		week_label.modulate = Color(0.9, 0.7, 0.2)  # Yellow
	else:
		week_label.modulate = Color.WHITE


