extends Node

## FloatingTextManager - Spawns floating text for score changes
## Add as autoload singleton

const FloatingTextScene = preload("res://scenes/ui/floating_text.tscn")
const STAGGER_DELAY = 0.15  # Delay between multiple effects

const COLOR_POSITIVE = Color("#228b22")  # Forest green
const COLOR_NEGATIVE = Color("#dc3545")  # Red

var pending_texts: Array = []
var spawn_timer: float = 0.0


func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)


func _process(delta: float) -> void:
	if pending_texts.is_empty():
		return

	spawn_timer -= delta
	if spawn_timer <= 0:
		_spawn_next_text()
		spawn_timer = STAGGER_DELAY


func _on_score_changed(score_name: String, change: int, _new_value: int) -> void:
	if change == 0:
		return

	var text = ""
	var color = COLOR_POSITIVE

	if change > 0:
		text = "+%d %s" % [change, score_name.capitalize()]
		color = COLOR_POSITIVE
	else:
		text = "%d %s" % [change, score_name.capitalize()]
		color = COLOR_NEGATIVE

	pending_texts.append({"text": text, "color": color})

	# Start spawning immediately if this is the first
	if pending_texts.size() == 1:
		spawn_timer = 0


func _spawn_next_text() -> void:
	if pending_texts.is_empty():
		return

	var data = pending_texts.pop_front()

	# Find the player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Create floating text
	var floating_text = FloatingTextScene.instantiate()
	floating_text.position = player.global_position + Vector2(0, -40)

	# Add to the game world (not UI) so it moves with the camera
	get_tree().current_scene.add_child(floating_text)

	# Set the text and color
	floating_text.set_text(data["text"], data["color"])


## Public method to spawn arbitrary floating text at a position
func spawn_at(text: String, pos: Vector2, color: Color = Color.WHITE) -> void:
	var floating_text = FloatingTextScene.instantiate()
	floating_text.position = pos
	get_tree().current_scene.add_child(floating_text)
	floating_text.set_text(text, color)
