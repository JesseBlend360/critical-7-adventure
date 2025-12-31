extends Node

## DecisionManager - Handles decision logic and application (Autoload singleton)
## Loads decisions.json, validates prerequisites, applies costs and effects

# Signals
signal decision_applied(decision_id: String, decision_data: Dictionary)
signal decision_failed(decision_id: String, reason: String)

# All decisions loaded from JSON
var decisions: Dictionary = {}

# Score display names for UI
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
	_load_decisions()


func _load_decisions() -> void:
	var file = FileAccess.open("res://data/decisions.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()
		if error == OK:
			var data = json.get_data()
			if data.has("decisions"):
				for decision in data["decisions"]:
					decisions[decision["id"]] = decision
				print("DecisionManager: Loaded ", decisions.size(), " decisions")
		else:
			push_error("DecisionManager: Failed to parse decisions.json")
	else:
		push_warning("DecisionManager: decisions.json not found, no decisions loaded")


func get_decision(decision_id: String) -> Dictionary:
	return decisions.get(decision_id, {})


## Check if a decision can be made
## Returns { "allowed": bool, "reasons": Array }
func can_make_decision(decision_id: String) -> Dictionary:
	var result = {"allowed": true, "reasons": []}
	var decision = get_decision(decision_id)

	if decision.is_empty():
		result["allowed"] = false
		result["reasons"].append("Decision not found: " + decision_id)
		return result

	# Already made this decision?
	if GameState.has_made_decision(decision_id):
		result["allowed"] = false
		result["reasons"].append("Already made this decision")
		return result

	# Check excludes (mutually exclusive decisions)
	if decision.has("excludes"):
		for excluded_id in decision["excludes"]:
			if GameState.has_made_decision(excluded_id):
				result["allowed"] = false
				var excluded_decision = get_decision(excluded_id)
				var title = excluded_decision.get("title", excluded_id)
				result["reasons"].append("Excluded by: " + title)

	# Check prerequisites
	if decision.has("prerequisites"):
		var prereqs = decision["prerequisites"]

		# Check flag prerequisites
		if prereqs.has("flags"):
			for flag in prereqs["flags"]:
				if not GameState.has_flag(flag):
					result["allowed"] = false
					result["reasons"].append("Requires flag: " + flag)

		# Check decision prerequisites
		if prereqs.has("decisions"):
			for req_decision_id in prereqs["decisions"]:
				if not GameState.has_made_decision(req_decision_id):
					result["allowed"] = false
					var req_decision = get_decision(req_decision_id)
					var title = req_decision.get("title", req_decision_id)
					result["reasons"].append("Requires: " + title)

		# Check score prerequisites
		if prereqs.has("min_scores"):
			for score_name in prereqs["min_scores"]:
				var required = prereqs["min_scores"][score_name]
				var current = GameState.scores.get(score_name, 0)
				if current < required:
					result["allowed"] = false
					var display_name = SCORE_NAMES.get(score_name, score_name)
					result["reasons"].append("%s >= %d (You have: %d)" % [display_name, required, current])

	# Check budget
	if decision.has("cost") and decision["cost"].has("budget"):
		var cost = decision["cost"]["budget"]
		if cost > GameState.budget:
			result["allowed"] = false
			result["reasons"].append("Insufficient budget ($%s needed)" % _format_money(cost))

	return result


## Make a decision - apply costs and effects
func make_decision(decision_id: String) -> bool:
	var can_make = can_make_decision(decision_id)
	if not can_make["allowed"]:
		var reason = ", ".join(can_make["reasons"])
		decision_failed.emit(decision_id, reason)
		return false

	var decision = get_decision(decision_id)

	# Apply budget cost
	if decision.has("cost") and decision["cost"].has("budget"):
		GameState.spend_budget(decision["cost"]["budget"])

	# Apply time cost
	if decision.has("cost") and decision["cost"].has("time"):
		GameState.advance_week(decision["cost"]["time"])

	# Apply score impacts
	if decision.has("impact"):
		for score_name in decision["impact"]:
			if GameState.scores.has(score_name):
				GameState.scores[score_name] += decision["impact"][score_name]

	# Set any unlock flags
	if decision.has("unlocks"):
		for flag in decision["unlocks"]:
			GameState.set_flag(flag)

	# Record the decision
	GameState.record_decision(decision_id, decision)

	decision_applied.emit(decision_id, decision)
	return true


## Get trajectory summary text based on current state
func get_trajectory_text() -> String:
	var budget_pct = GameState.get_budget_percent()
	var week_pct = GameState.get_timeline_percent()
	var total_score = GameState.get_total_score()
	var lowest = GameState.get_lowest_score()
	var critical = GameState.get_critical_failures()

	# Critical failures
	if critical.size() > 0:
		var score_name = SCORE_NAMES.get(critical[0], critical[0])
		return "CRITICAL: %s has collapsed. The project is in serious trouble." % score_name

	# Budget problems
	if budget_pct < 20:
		return "URGENT: Budget nearly depleted. Every decision counts now."
	if budget_pct < 40:
		return "CAUTION: Budget running low. Time to be strategic about spending."

	# Time pressure
	if week_pct > 80 and total_score < 30:
		return "PRESSURE: Deadline approaching and progress is behind. Focus on quick wins."
	if week_pct > 90:
		return "FINAL STRETCH: The deadline is almost here. Make it count."

	# Score-based assessments
	if lowest["value"] < 0:
		var score_name = SCORE_NAMES.get(lowest["name"], lowest["name"])
		return "WARNING: %s is suffering. Consider addressing this weakness." % score_name

	if total_score > 50:
		return "STRONG: The project is on track. Keep building on this momentum."
	if total_score > 25:
		return "CAUTIOUSLY OPTIMISTIC: Good progress, but there's work to do."
	if total_score > 0:
		return "DEVELOPING: Early days. The project could go either way."

	return "UNCERTAIN: The path forward isn't clear yet."


## Get a snarky trajectory summary (for CHIP)
func get_trajectory_snark() -> String:
	var budget_pct = GameState.get_budget_percent()
	var lowest = GameState.get_lowest_score()
	var critical = GameState.get_critical_failures()

	if critical.size() > 0:
		return "I've run the numbers. They're... not great. Have you considered interpretive dance as a career?"

	if budget_pct < 20:
		return "Fun fact: We're almost out of money. The vending machine doesn't accept 'good intentions.'"

	if lowest["value"] < -3:
		var score_name = SCORE_NAMES.get(lowest["name"], lowest["name"])
		return "Your %s score is... concerning. And by 'concerning' I mean 'actively on fire.'" % score_name.to_lower()

	if GameState.get_total_score() > 40:
		return "Against all odds, things are going well. I've updated my probability models. Twice."

	return "Everything is proceeding within normal parameters. For a project, I mean. The bar is low."


## Get ending tier based on final state
func calculate_ending() -> Dictionary:
	var total_score = GameState.get_total_score()
	var critical = GameState.get_critical_failures()
	var budget_depleted = GameState.budget <= 0
	var time_expired = GameState.current_week > GameState.total_weeks

	var result = {
		"tier": "mixed",
		"title": "Mixed Results",
		"score": total_score,
		"critical_failures": critical
	}

	# Catastrophic
	if budget_depleted:
		result["tier"] = "catastrophic"
		result["title"] = "Budget Depleted"
		result["reason"] = "budget"
		return result

	if time_expired and total_score < 20:
		result["tier"] = "catastrophic"
		result["title"] = "Project Abandoned"
		result["reason"] = "time"
		return result

	if critical.size() >= 2:
		result["tier"] = "catastrophic"
		result["title"] = "Critical Failures"
		result["reason"] = "scores"
		return result

	# Partial failure
	if total_score < 15 or critical.size() >= 1:
		result["tier"] = "partial_failure"
		result["title"] = "Partial Failure"
		return result

	# Mixed
	if total_score < 40:
		result["tier"] = "mixed"
		result["title"] = "Mixed Results"
		return result

	# Success
	if total_score < 70:
		result["tier"] = "success"
		result["title"] = "Success"
		return result

	# Exceptional
	result["tier"] = "exceptional"
	result["title"] = "Exceptional Success"

	# Check for special achievements
	if GameState.has_flag("harry_champion"):
		result["special"] = "CEO Champion"

	return result


## Format money for display
func _format_money(amount: int) -> String:
	if amount >= 1000:
		return "%dK" % (amount / 1000)
	return str(amount)


## Format a decision for display
func format_decision_summary(decision_id: String) -> Dictionary:
	var decision = get_decision(decision_id)
	if decision.is_empty():
		return {}

	var summary = {
		"id": decision_id,
		"title": decision.get("title", decision_id),
		"description": decision.get("description", ""),
		"category": decision.get("category", ""),
		"cost_text": "",
		"flavor_text": decision.get("flavor_text", "")
	}

	# Format cost
	var costs = []
	if decision.has("cost"):
		if decision["cost"].has("budget") and decision["cost"]["budget"] != 0:
			costs.append("$" + _format_money(decision["cost"]["budget"]))
		if decision["cost"].has("time") and decision["cost"]["time"] != 0:
			var weeks = decision["cost"]["time"]
			costs.append("%d week%s" % [weeks, "s" if weeks != 1 else ""])

	summary["cost_text"] = " | ".join(costs) if costs.size() > 0 else "Free"

	return summary
