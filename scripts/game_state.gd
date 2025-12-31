extends Node

## GameState - Central store for all game state (Autoload singleton)
## Persists across scenes. Single source of truth.

# Scores
var scores: Dictionary = {
	"strategy": 0,
	"data": 0,
	"technical": 0,
	"innovation": 0,
	"change": 0,
	"talent": 0,
	"trust": 0
}

var expectations_gap: int = 0
var talked_to: Array[String] = []
var flags: Array[String] = []
var current_day: int = 1
var dialogue_history: Dictionary = {}  # Tracks last node visited per NPC


func apply_effects(effects: Dictionary) -> void:
	# Apply score changes
	for score_name in scores.keys():
		if effects.has(score_name):
			scores[score_name] += effects[score_name]

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
	expectations_gap = 0
	talked_to = []
	flags = []
	current_day = 1
	dialogue_history = {}
