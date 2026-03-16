extends Node

## GameState - Central store for all game state (Autoload singleton)
## Persists across scenes. Single source of truth.

# Difficulty
enum Difficulty { EASY, MEDIUM, HARD }

const DIFFICULTY_SETTINGS = {
	Difficulty.EASY:   { "budget": 1000000, "weeks": 20, "label": "Easy" },
	Difficulty.MEDIUM: { "budget": 750000,  "weeks": 16, "label": "Medium" },
	Difficulty.HARD:   { "budget": 500000,  "weeks": 12, "label": "Hard" },
}

var difficulty: Difficulty = Difficulty.MEDIUM

# Signals
signal budget_changed(new_budget: int, old_budget: int)
signal week_changed(new_week: int)
signal decision_made(decision_id: String)
signal game_over(reason: String)
signal score_changed(score_name: String, change: int, new_value: int)
signal difficulty_set(diff: Difficulty)

# The Critical 7 Scores
var scores: Dictionary = {
	"strategy": 0,
	"data": 0,
	"technical": 0,
	"innovation": 0,
	"change": 0,
	"talent": 0,
	"trust": 0
}

# Budget and Timeline
var budget: int = 750000
var budget_total: int = 750000
var current_week: int = 1
var total_weeks: int = 16

# Decision tracking
var decisions_made: Array[String] = []
var decision_log: Array[Dictionary] = []  # Full records with timestamps

# Legacy/misc state
var expectations_gap: int = 0
var talked_to: Array[String] = []
var flags: Array[String] = []
var current_day: int = 1
var dialogue_history: Dictionary = {}  # Tracks last node visited per NPC


func apply_effects(effects: Dictionary) -> void:
	# Apply score changes
	for score_name in scores.keys():
		if effects.has(score_name):
			var change = effects[score_name]
			scores[score_name] += change
			score_changed.emit(score_name, change, scores[score_name])

	# Apply expectations_gap change
	if effects.has("expectations_gap"):
		expectations_gap += effects["expectations_gap"]

	# Set flags
	if effects.has("set_flags"):
		for flag in effects["set_flags"]:
			set_flag(flag)

	# Unset flags
	if effects.has("unset_flags"):
		for flag in effects["unset_flags"]:
			unset_flag(flag)


func set_flag(flag: String) -> void:
	if flag not in flags:
		flags.append(flag)


func unset_flag(flag: String) -> void:
	var idx = flags.find(flag)
	if idx >= 0:
		flags.remove_at(idx)


func has_flag(flag: String) -> bool:
	return flag in flags


func mark_talked_to(npc_id: String) -> void:
	if npc_id not in talked_to:
		talked_to.append(npc_id)


func has_talked_to(npc_id: String) -> bool:
	return npc_id in talked_to


func get_talked_to_count() -> int:
	return talked_to.size()


func check_conditions(conditions: Dictionary) -> bool:
	# talked_to: must have talked to all listed NPCs
	if conditions.has("talked_to"):
		for npc in conditions["talked_to"]:
			if not has_talked_to(npc):
				return false

	# not_talked_to: must NOT have talked to any listed NPCs
	if conditions.has("not_talked_to"):
		for npc in conditions["not_talked_to"]:
			if has_talked_to(npc):
				return false

	# flags: must have all listed flags
	if conditions.has("flags"):
		for flag in conditions["flags"]:
			if not has_flag(flag):
				return false

	# not_flags: must NOT have any listed flags
	if conditions.has("not_flags"):
		for flag in conditions["not_flags"]:
			if has_flag(flag):
				return false

	# score_min: each score must be >= value
	if conditions.has("score_min"):
		for score_name in conditions["score_min"]:
			if scores.get(score_name, 0) < conditions["score_min"][score_name]:
				return false

	# score_max: each score must be <= value
	if conditions.has("score_max"):
		for score_name in conditions["score_max"]:
			if scores.get(score_name, 0) > conditions["score_max"][score_name]:
				return false

	return true


## Budget Management

func spend_budget(amount: int) -> bool:
	if amount > budget:
		return false
	var old_budget = budget
	budget -= amount
	budget_changed.emit(budget, old_budget)
	_check_budget_game_over()
	return true


func add_budget(amount: int) -> void:
	var old_budget = budget
	budget += amount
	budget_changed.emit(budget, old_budget)


func get_budget_percent() -> float:
	return float(budget) / float(budget_total) * 100.0


func _check_budget_game_over() -> void:
	if budget <= 0:
		game_over.emit("budget_depleted")


## Timeline Management

func advance_week(weeks: int = 1) -> void:
	current_week += weeks
	week_changed.emit(current_week)
	if current_week > total_weeks:
		game_over.emit("time_expired")


func get_weeks_remaining() -> int:
	return max(0, total_weeks - current_week)


func get_timeline_percent() -> float:
	return float(current_week) / float(total_weeks) * 100.0


## Decision Tracking

func has_made_decision(decision_id: String) -> bool:
	return decision_id in decisions_made


func record_decision(decision_id: String, decision_data: Dictionary) -> void:
	if decision_id not in decisions_made:
		decisions_made.append(decision_id)

	var log_entry = {
		"id": decision_id,
		"week": current_week,
		"data": decision_data
	}
	decision_log.append(log_entry)
	decision_made.emit(decision_id)


func get_decision_count() -> int:
	return decisions_made.size()


## Check if a decision is excluded by previous decisions
func is_decision_excluded(excludes: Array) -> bool:
	for excluded_id in excludes:
		if has_made_decision(excluded_id):
			return true
	return false


## Get detailed condition check result (for showing locked choice info)
func check_conditions_detailed(conditions: Dictionary) -> Dictionary:
	var result = {
		"allowed": true,
		"failed": []
	}

	# talked_to: must have talked to all listed NPCs
	if conditions.has("talked_to"):
		for npc in conditions["talked_to"]:
			if not has_talked_to(npc):
				result["allowed"] = false
				result["failed"].append({"type": "talked_to", "npc": npc})

	# not_talked_to: must NOT have talked to any listed NPCs
	if conditions.has("not_talked_to"):
		for npc in conditions["not_talked_to"]:
			if has_talked_to(npc):
				result["allowed"] = false
				result["failed"].append({"type": "not_talked_to", "npc": npc})

	# flags: must have all listed flags
	if conditions.has("flags"):
		for flag in conditions["flags"]:
			if not has_flag(flag):
				result["allowed"] = false
				result["failed"].append({"type": "flag", "flag": flag})

	# not_flags: must NOT have any listed flags
	if conditions.has("not_flags"):
		for flag in conditions["not_flags"]:
			if has_flag(flag):
				result["allowed"] = false
				result["failed"].append({"type": "not_flag", "flag": flag})

	# min_scores: each score must be >= value (D&D style skill check)
	if conditions.has("min_scores"):
		for score_name in conditions["min_scores"]:
			var required = conditions["min_scores"][score_name]
			var current = scores.get(score_name, 0)
			if current < required:
				result["allowed"] = false
				result["failed"].append({
					"type": "min_score",
					"score": score_name,
					"required": required,
					"current": current
				})

	# max_scores: each score must be <= value
	if conditions.has("max_scores"):
		for score_name in conditions["max_scores"]:
			var required = conditions["max_scores"][score_name]
			var current = scores.get(score_name, 0)
			if current > required:
				result["allowed"] = false
				result["failed"].append({
					"type": "max_score",
					"score": score_name,
					"required": required,
					"current": current
				})

	# decisions: must have made all listed decisions
	if conditions.has("decisions"):
		for dec_id in conditions["decisions"]:
			if not has_made_decision(dec_id):
				result["allowed"] = false
				result["failed"].append({"type": "decision", "decision": dec_id})

	# not_decisions: must NOT have made any listed decisions
	if conditions.has("not_decisions"):
		for dec_id in conditions["not_decisions"]:
			if has_made_decision(dec_id):
				result["allowed"] = false
				result["failed"].append({"type": "not_decision", "decision": dec_id})

	return result


## Score helpers

func get_total_score() -> int:
	var total = 0
	for score_name in scores:
		total += scores[score_name]
	return total


func get_lowest_score() -> Dictionary:
	var lowest_name = ""
	var lowest_value = 999
	for score_name in scores:
		if scores[score_name] < lowest_value:
			lowest_value = scores[score_name]
			lowest_name = score_name
	return {"name": lowest_name, "value": lowest_value}


func get_highest_score() -> Dictionary:
	var highest_name = ""
	var highest_value = -999
	for score_name in scores:
		if scores[score_name] > highest_value:
			highest_value = scores[score_name]
			highest_name = score_name
	return {"name": highest_name, "value": highest_value}


func get_critical_failures() -> Array:
	var failures = []
	for score_name in scores:
		if scores[score_name] < -5:
			failures.append(score_name)
	return failures


## Difficulty

func set_difficulty(diff: Difficulty) -> void:
	difficulty = diff
	var settings = DIFFICULTY_SETTINGS[diff]
	budget = settings["budget"]
	budget_total = settings["budget"]
	total_weeks = settings["weeks"]
	budget_changed.emit(budget, budget)
	week_changed.emit(current_week)
	difficulty_set.emit(diff)


func get_difficulty_label() -> String:
	return DIFFICULTY_SETTINGS[difficulty]["label"]


## Reset

func reset() -> void:
	scores = {
		"strategy": 0,
		"data": 0,
		"technical": 0,
		"innovation": 0,
		"change": 0,
		"talent": 0,
		"trust": 0
	}
	var settings = DIFFICULTY_SETTINGS[difficulty]
	budget = settings["budget"]
	budget_total = settings["budget"]
	current_week = 1
	total_weeks = settings["weeks"]
	decisions_made = []
	decision_log = []
	expectations_gap = 0
	talked_to = []
	flags = []
	current_day = 1
	dialogue_history = {}
