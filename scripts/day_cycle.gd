extends Node

## DayCycle - Handles the end-of-day cinematic (Autoload singleton)
##
## v0.3 reorientation: the day loop is morning walk-and-talk → evening terminal
## → fade to black → reception spawn → next morning. This singleton owns the
## fade overlay and runs the transition.
##
## Trigger from the terminal's END DAY button:
##   await DayCycle.end_day()
##
## What happens during end_day():
##   1. Emits day_ending (listeners can save / close menus)
##   2. Fades the screen to black
##   3. Advances GameState.current_week by 1
##   4. Teleports the player to the "default" spawn marker (reception)
##   5. Brief hold on black, then fades back in
##   6. Emits day_started

signal day_ending      # emitted before the fade-out starts
signal day_started     # emitted after the fade-in completes

@export var fade_duration: float = 0.8
@export var hold_black_duration: float = 0.4

var _overlay: CanvasLayer
var _color_rect: ColorRect
var _transitioning: bool = false


func _ready() -> void:
	_build_overlay()


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "DayCycleOverlay"
	_overlay.layer = 100  # above HUD, dialogue, terminal, everything
	add_child(_overlay)

	_color_rect = ColorRect.new()
	_color_rect.name = "FadeRect"
	_color_rect.color = Color(0, 0, 0, 0)
	_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.visible = false
	_overlay.add_child(_color_rect)


## Run the full end-of-day cinematic. Safe to await.
func end_day() -> void:
	if _transitioning:
		return
	_transitioning = true
	day_ending.emit()

	await _fade_to_black()

	# Resource bookkeeping happens while the screen is fully covered.
	GameState.advance_week(1)
	_reset_daily_state()
	_respawn_player_at_reception()

	await get_tree().create_timer(hold_black_duration).timeout
	await _fade_from_black()

	_transitioning = false
	day_started.emit()


func is_transitioning() -> bool:
	return _transitioning


func _fade_to_black() -> void:
	_color_rect.color = Color(0, 0, 0, 0)
	_color_rect.visible = true
	var tween := create_tween()
	tween.tween_property(_color_rect, "color:a", 1.0, fade_duration)
	await tween.finished


func _fade_from_black() -> void:
	var tween := create_tween()
	tween.tween_property(_color_rect, "color:a", 0.0, fade_duration)
	await tween.finished
	_color_rect.visible = false


## Reset per-day state. v0.3 plans `talked_to_today` here.
## For now we only clear it if GameState happens to expose it; otherwise no-op.
func _reset_daily_state() -> void:
	if GameState.has_method("reset_daily"):
		GameState.reset_daily()


func _respawn_player_at_reception() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var target: Node2D = _find_spawn_marker("default")
	if target == null:
		# Fall back to first spawn point in the group.
		var spawns := tree.get_nodes_in_group("spawn_point")
		if spawns.size() > 0 and spawns[0] is Node2D:
			target = spawns[0]

	if target == null:
		push_warning("DayCycle: no reception spawn marker found; player not moved")
		return

	var player := tree.get_first_node_in_group("player")
	if player and player is Node2D:
		(player as Node2D).global_position = target.global_position


func _find_spawn_marker(spawn_id: String) -> Node2D:
	for sp in get_tree().get_nodes_in_group("spawn_point"):
		if sp is Node2D and sp.has_meta("spawn_id") and str(sp.get_meta("spawn_id")) == spawn_id:
			return sp
	return null
