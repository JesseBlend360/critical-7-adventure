extends CanvasLayer

## Ending Screen - Shows final project outcome
## Displays tier, narrative, score breakdowns, and decision log

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/VBox/SubtitleLabel
@onready var narrative_label: Label = $Panel/VBox/NarrativeLabel
@onready var scores_container: VBoxContainer = $Panel/VBox/ScoresContainer
@onready var chip_label: Label = $Panel/VBox/ChipLabel
@onready var closing_label: Label = $Panel/VBox/ClosingLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var play_again_button: Button = $Panel/VBox/PlayAgainButton

var endings_data: Dictionary = {}

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
	_load_endings()
	play_again_button.pressed.connect(_on_play_again)

	# Connect to game over signal
	GameState.game_over.connect(_on_game_over)


func _load_endings() -> void:
	var file = FileAccess.open("res://data/endings.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()
		if error == OK:
			endings_data = json.get_data()
		else:
			push_error("EndingScreen: Failed to parse endings.json")


func _on_game_over(reason: String) -> void:
	# Don't show ending when boss fight will intercept time_expired
	if reason == "time_expired":
		var boss_fight = get_tree().current_scene.get_node_or_null("BossFight")
		if boss_fight:
			return  # Boss fight node exists, it will handle the sequence

	var ending = DecisionManager.calculate_ending()
	ending["reason"] = reason
	show_ending(ending)


func show_ending(ending: Dictionary) -> void:
	var tier = ending.get("tier", "mixed")
	var tier_data = endings_data.get("tiers", {}).get(tier, {})

	# Title and subtitle
	title_label.text = tier_data.get("title", "The End")
	subtitle_label.text = tier_data.get("subtitle", "")

	# Narrative text
	var narrative = tier_data.get("narrative", "")
	if tier_data.has("narratives") and ending.has("reason"):
		var narratives = tier_data["narratives"]
		narrative = narratives.get(ending["reason"], narrative)
	narrative_label.text = narrative

	# Build score summaries
	_build_score_display()

	# CHIP's final line
	chip_label.text = '"' + tier_data.get("chip_line", "...") + '"'

	# Closing text
	var closing = tier_data.get("closing", "")

	# Check for special achievements
	if tier_data.has("special"):
		var specials = tier_data["special"]
		for flag in specials:
			if GameState.has_flag(flag):
				closing = specials[flag]
				break

	closing_label.text = closing

	# Stats summary
	var stats_text = "Final Statistics:\n"
	stats_text += "Budget: $%dK spent of $%dK\n" % [
		(GameState.budget_total - GameState.budget) / 1000,
		GameState.budget_total / 1000
	]
	stats_text += "Time: Week %d of %d\n" % [
		GameState.current_week,
		GameState.total_weeks
	]
	stats_text += "Decisions Made: %d\n" % GameState.get_decision_count()
	stats_text += "Total Score: %d" % GameState.get_total_score()
	stats_label.text = stats_text

	panel.visible = true


func _build_score_display() -> void:
	# Clear existing children
	for child in scores_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	var score_summaries = endings_data.get("score_summaries", {})

	for score_id in SCORE_NAMES:
		var value = GameState.scores.get(score_id, 0)
		var display_name = SCORE_NAMES[score_id]

		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Score name and value
		var name_label = Label.new()
		name_label.text = "%s: %d" % [display_name, value]
		name_label.custom_minimum_size = Vector2(120, 0)
		hbox.add_child(name_label)

		# Score bar
		var bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(100, 15)
		bar.min_value = -20
		bar.max_value = 30
		bar.value = value
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Color based on value
		if value < 0:
			bar.modulate = Color(0.9, 0.3, 0.3)
		elif value < 10:
			bar.modulate = Color(0.9, 0.7, 0.2)
		else:
			bar.modulate = Color(0.3, 0.8, 0.3)

		hbox.add_child(bar)

		# Summary text
		if score_summaries.has(score_id):
			var summary_data = score_summaries[score_id]
			var summary_text = ""
			if value >= 15:
				summary_text = summary_data.get("high", "")
			elif value >= 5:
				summary_text = summary_data.get("medium", "")
			else:
				summary_text = summary_data.get("low", "")

			if summary_text != "":
				var summary_label = Label.new()
				summary_label.text = summary_text
				summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
				summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_child(summary_label)

		scores_container.add_child(hbox)


func _on_play_again() -> void:
	GameState.reset()
	panel.visible = false
	get_tree().reload_current_scene()
