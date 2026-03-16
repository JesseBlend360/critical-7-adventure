@tool
extends RichTextEffect
class_name PopEffect

## Word pop-in: starts small at top-left and grows to full size while fading in.
## Usage: [pop t=0.3]word[/pop]
## "t" is animation progress: 0.0 = just appeared, 1.0 = fully settled.

var bbcode = "pop"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var progress = char_fx.env.get("t", 1.0)
	if progress is String:
		progress = float(progress)

	progress = clampf(progress, 0.0, 1.0)

	if progress < 1.0:
		# Ease out for a snappy feel (fast at start, gentle settle)
		var eased = 1.0 - pow(1.0 - progress, 3.0)

		# Scale: start at 0.5, grow to 1.0
		var scale_val = lerpf(0.5, 1.0, eased)
		char_fx.transform = char_fx.transform.scaled(Vector2(scale_val, scale_val))

		# Alpha: start at 0.0, fade to 1.0
		char_fx.color.a *= eased

	return true
