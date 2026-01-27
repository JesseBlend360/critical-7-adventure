extends Node2D

## Floating text that rises and fades out
## Used for showing score changes, damage numbers, etc.

@onready var label: Label = $Label

var velocity: Vector2 = Vector2(0, -60)
var fade_duration: float = 1.0
var rise_duration: float = 1.2
var elapsed: float = 0.0


func _ready() -> void:
	# Start slightly above and add some horizontal randomness
	position.x += randf_range(-20, 20)


func _process(delta: float) -> void:
	elapsed += delta

	# Rise up
	position += velocity * delta
	# Slow down over time
	velocity.y *= 0.98

	# Fade out after a delay
	var fade_start = rise_duration - fade_duration
	if elapsed > fade_start:
		var fade_progress = (elapsed - fade_start) / fade_duration
		modulate.a = 1.0 - fade_progress

	# Remove when done
	if elapsed >= rise_duration:
		queue_free()


func set_text(text: String, color: Color = Color.WHITE) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
