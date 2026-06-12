extends Node

## DayClock - Real-time day timer (Autoload singleton)
##
## v0.3 reorientation: each day has a real-time clock that runs only while
## the player has world movement. Dialogue, menus, terminal, and the
## fade-to-next-day cinematic all pause it via a reason stack.
##
## ANYONE can pause/resume the clock by calling:
##   DayClock.pause("dialogue")
##   DayClock.resume("dialogue")
## Each label is independent — opening a status screen during dialogue is
## two pause reasons, both must clear before the clock runs again.
##
## The clock is wired by default to:
##   - GameManager.dialogue_started / dialogue_ended
##   - DayCycle.day_ending / day_started
##   - GameState.difficulty_set (starts the very first day)
##
## Signals:
##   tick(seconds_left)        — every frame the clock ticks down
##   day_ending_soon            — once when time_remaining ≤ WARN_AT_SECONDS
##   day_ended                  — once when time hits 0 in the world

signal tick(seconds_left: float)
signal hour_changed(day_index: int, hour24: int)  ## fires when the displayed tick advances
signal day_ending_soon
signal day_ended
signal pause_state_changed(is_paused_now: bool)  ## fires when pause set toggles
signal qbr_started                                ## clock stops, HUD swaps to "QBR"

# Real-time length of one in-game work-week per difficulty (seconds).
# One session = Mon 8AM → Fri 5PM, scaled to fit this many real seconds.
const DAY_LENGTH := {
	GameState.Difficulty.EASY: 300.0,    # 5:00
	GameState.Difficulty.MEDIUM: 210.0,  # 3:30
	GameState.Difficulty.HARD: 150.0,    # 2:30
	GameState.Difficulty.DEBUG: 90.0,    # 1:30 — fast-roll testing
}
const WARN_AT_SECONDS := 30.0

# Virtual office clock — what the player sees on the HUD.
# Mon 8AM, 9AM, … 4PM = 9 hourly ticks per day; 5 days Mon–Fri = 45 ticks total.
# At tick 45 the timer expires and the week auto-ends.
const HOURS_PER_DAY := 9      # displayed hours: 8AM, 9AM, … 4PM
const DAYS_PER_WEEK := 5      # Mon, Tue, Wed, Thu, Fri
const TICKS_PER_WEEK := HOURS_PER_DAY * DAYS_PER_WEEK  # 45
const START_HOUR := 8         # 8AM is hour-index 0
const END_HOUR := 17          # 5PM = end-of-week marker, never a "current" hour
const DAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri"]

# QBR walk-up trigger: the conference room is at the top of the long hallway.
# When QBR is pending, we poll the player every frame; once they cross above
# this world-y threshold, the boss-fight game_over fires. Tunable — if it
# triggers too early (in the hallway) push it more negative; if too late
# (player walks into the room and nothing happens) bring it closer to 0.
const QBR_TRIGGER_Y := -1700.0

var day_total: float = 210.0
var time_remaining: float = 210.0
var _running: bool = false
var _pause_reasons: Array[String] = []
var _warned: bool = false
var _expired: bool = false
var _last_tick_in_week: int = -1  # for hour_changed dedupe
var _qbr_trigger_fired: bool = false  # one-shot guard for the walk-up


func _ready() -> void:
	set_process(true)

	# Difficulty selection starts the very first day.
	GameState.difficulty_set.connect(_on_difficulty_set)

	# Pause during dialogue / terminal (GameManager is the umbrella event).
	GameManager.dialogue_started.connect(_on_dialogue_started)
	GameManager.dialogue_ended.connect(_on_dialogue_ended)

	# Pause during the fade-to-next-day; reset & restart on new morning.
	DayCycle.day_ending.connect(_on_day_ending)
	DayCycle.day_started.connect(_on_day_started)

	# v0.3: end of the run — week N+1 = QBR. Stop the clock, hand control to
	# the player to walk to the conference room.
	GameState.qbr_pending.connect(_on_qbr_pending)


# ────────────────────────────────────────────────────────────────────────────
# Public API

func start_day() -> void:
	_apply_difficulty()
	time_remaining = day_total
	_warned = false
	_expired = false
	_running = true
	_last_tick_in_week = -1
	# Emit an initial hour_changed so listeners paint the starting time.
	hour_changed.emit(current_day_in_week(), START_HOUR + current_tick_in_day())
	_last_tick_in_week = current_tick_in_week()


func stop() -> void:
	_running = false


func pause(reason: String) -> void:
	if reason == "":
		return
	if reason in _pause_reasons:
		return
	var was_paused: bool = is_paused()
	_pause_reasons.append(reason)
	if not was_paused:
		pause_state_changed.emit(true)


func resume(reason: String) -> void:
	if reason not in _pause_reasons:
		return
	_pause_reasons.erase(reason)
	if not is_paused():
		pause_state_changed.emit(false)


func is_paused() -> bool:
	return _pause_reasons.size() > 0


func is_running() -> bool:
	return _running and not is_paused() and not _expired


## Virtual hour-of-day, 0..HOURS_PER_DAY-1 (8AM=0, 9AM=1, …, 4PM=8).
## Returns HOURS_PER_DAY (=9) only at the exact instant the week ends — used
## by formatters to render the final "5 PM" frame before fade-out.
func current_tick_in_day() -> int:
	var tick: int = current_tick_in_week()
	return tick % HOURS_PER_DAY


## Virtual day-of-week, 0..DAYS_PER_WEEK-1 (Mon=0, … Fri=4).
func current_day_in_week() -> int:
	var tick: int = current_tick_in_week()
	# Clamp so the final frame at expiry stays on Friday.
	return clampi(tick / HOURS_PER_DAY, 0, DAYS_PER_WEEK - 1)


## Tick index across the whole week, 0..TICKS_PER_WEEK.
## TICKS_PER_WEEK (45) is the "5 PM Friday" end-of-week marker.
func current_tick_in_week() -> int:
	if day_total <= 0.0:
		return 0
	var elapsed: float = day_total - time_remaining
	var progress: float = clampf(elapsed / day_total, 0.0, 1.0)
	return clampi(int(floor(progress * float(TICKS_PER_WEEK))), 0, TICKS_PER_WEEK)


## Display string for the HUD, e.g. "Mon 8:00 AM" or "Fri 4:00 PM".
## At expiry returns "Fri 5:00 PM".
func format_virtual_time() -> String:
	var tick: int = current_tick_in_week()
	if tick >= TICKS_PER_WEEK:
		return "Fri %s" % _format_hour(END_HOUR)
	var day: int = clampi(tick / HOURS_PER_DAY, 0, DAYS_PER_WEEK - 1)
	var hour24: int = START_HOUR + (tick % HOURS_PER_DAY)
	return "%s %s" % [DAY_NAMES[day], _format_hour(hour24)]


func _format_hour(hour24: int) -> String:
	var suffix: String = "AM" if hour24 < 12 else "PM"
	var h12: int = hour24 % 12
	if h12 == 0:
		h12 = 12
	return "%d:00 %s" % [h12, suffix]


## Legacy MM:SS formatter — kept in case anything still wants it.
func format_remaining() -> String:
	var secs: int = int(ceil(time_remaining))
	var m: int = secs / 60
	var s: int = secs % 60
	return "%d:%02d" % [m, s]


# ────────────────────────────────────────────────────────────────────────────
# Internals

func _apply_difficulty() -> void:
	day_total = DAY_LENGTH.get(GameState.difficulty, 210.0)


func _process(delta: float) -> void:
	# v0.3: during QBR-pending mode the clock is stopped; we poll the player
	# instead, and fire the boss-fight trigger when they cross above the
	# conference-room threshold.
	if GameState.is_qbr_pending and not _qbr_trigger_fired:
		_check_qbr_walkup()
		return

	if not _running or is_paused() or _expired:
		return

	time_remaining = max(0.0, time_remaining - delta)
	tick.emit(time_remaining)

	# Has the virtual hour advanced? Fire hour_changed once per crossing.
	var t: int = current_tick_in_week()
	if t != _last_tick_in_week:
		_last_tick_in_week = t
		# Clamp inputs to legal ranges; end-of-week emits 5 PM (END_HOUR).
		if t >= TICKS_PER_WEEK:
			hour_changed.emit(DAYS_PER_WEEK - 1, END_HOUR)
		else:
			var day: int = t / HOURS_PER_DAY
			var hour24: int = START_HOUR + (t % HOURS_PER_DAY)
			hour_changed.emit(day, hour24)

	if not _warned and time_remaining <= WARN_AT_SECONDS:
		_warned = true
		day_ending_soon.emit()

	if time_remaining <= 0.0:
		_expired = true
		_running = false
		day_ended.emit()
		# v0.3: at 5 PM Friday the week auto-ends — fade out, advance week,
		# respawn at reception. Defer one frame so listeners on day_ended
		# (HUD color flash, etc.) get to react first.
		call_deferred("_auto_end_week")


func _auto_end_week() -> void:
	if DayCycle and not DayCycle.is_transitioning():
		DayCycle.end_day()


# ────────────────────────────────────────────────────────────────────────────
# Signal handlers

func _on_difficulty_set(_diff) -> void:
	# Difficulty picker dismisses → first day begins.
	start_day()


func _on_dialogue_started() -> void:
	pause("dialogue")


func _on_dialogue_ended() -> void:
	resume("dialogue")


func _on_day_ending() -> void:
	# Stop ticking through the fade-to-black + week advance.
	pause("transition")


func _on_day_started() -> void:
	# New morning: clear the transition pause, reset the clock, start running.
	resume("transition")
	if GameState.is_qbr_pending:
		# QBR is queued — don't start a new ticking day. The player is at
		# reception and needs to walk to the conference room.
		stop()
		return
	start_day()


func _on_qbr_pending() -> void:
	stop()
	_qbr_trigger_fired = false
	qbr_started.emit()


## While QBR is pending, watch the player. When they walk above the
## conference-room threshold, fire the legacy time_expired signal which the
## BossFight autoload already listens for.
func _check_qbr_walkup() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player == null or not (player is Node2D):
		return
	if (player as Node2D).global_position.y <= QBR_TRIGGER_Y:
		_qbr_trigger_fired = true
		GameState.game_over.emit("time_expired")
