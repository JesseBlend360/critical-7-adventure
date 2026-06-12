extends Node
class_name CharacterAnimator

## Builds SpriteFrames at runtime from a character sprite sheet.
## Attach as child of any node with an AnimatedSprite2D sibling named "Sprite2D".

@export var sprite_sheet: Texture2D

const FRAME_SIZE := Vector2(16, 32)

# Sprite sheet layout (all characters share this):
# Row 0: Head/preview sprites (not used)
# Row 1: Idle — 6 frames each: RIGHT (0-5), UP (6-11), LEFT (12-17), DOWN (18-23)
# Row 2: Walk — 6 frames each: RIGHT (0-5), UP (6-11), LEFT (12-17), DOWN (18-23)
# Left-facing uses walk_right/idle_right with flip_h = true
# Row 3+: Sleep, sit, etc.
const ANIM_MAP := {
	"idle_down":  {"row": 1, "col": 18, "count": 6, "fps": 6},
	"idle_up":    {"row": 1, "col": 6,  "count": 6, "fps": 6},
	"idle_right": {"row": 1, "col": 0,  "count": 6, "fps": 6},
	"walk_down":  {"row": 2, "col": 18, "count": 6, "fps": 10},
	"walk_up":    {"row": 2, "col": 6,  "count": 6, "fps": 10},
	"walk_right": {"row": 2, "col": 0,  "count": 6, "fps": 10},
}

var _sprite: AnimatedSprite2D
var _direction := Vector2.DOWN
var _moving := false
var _current_anim := ""


func _ready() -> void:
	var node := get_parent().get_node_or_null("Sprite2D")
	if node is AnimatedSprite2D:
		_sprite = node as AnimatedSprite2D
	if not _sprite:
		push_warning("CharacterAnimator: No AnimatedSprite2D 'Sprite2D' found")
		return
	if sprite_sheet:
		_build_sprite_frames()


func setup(sheet: Texture2D) -> void:
	sprite_sheet = sheet
	if _sprite:
		_build_sprite_frames()


func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	# Remove default animation
	if frames.has_animation("default"):
		frames.remove_animation("default")

	for anim_name in ANIM_MAP:
		var info: Dictionary = ANIM_MAP[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, info["fps"])
		frames.set_animation_loop(anim_name, true)

		for i in range(info["count"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = sprite_sheet
			atlas.region = Rect2(
				(info["col"] + i) * FRAME_SIZE.x,
				info["row"] * FRAME_SIZE.y,
				FRAME_SIZE.x,
				FRAME_SIZE.y
			)
			frames.add_frame(anim_name, atlas)

	_sprite.sprite_frames = frames
	_update_animation()


func set_direction(dir: Vector2) -> void:
	if dir.length() < 0.1:
		return
	_direction = dir
	_update_animation()


func set_moving(is_moving: bool) -> void:
	if _moving == is_moving:
		return
	_moving = is_moving
	_update_animation()


func _update_animation() -> void:
	if not _sprite or not _sprite.sprite_frames:
		return

	var prefix := "walk_" if _moving else "idle_"

	# Determine direction name and flip
	var dir_name: String
	var flip := false

	if abs(_direction.x) > abs(_direction.y):
		# Horizontal dominant
		if _direction.x < 0:
			dir_name = "right"
			flip = true
		else:
			dir_name = "right"
			flip = false
	else:
		# Vertical dominant
		if _direction.y < 0:
			dir_name = "up"
		else:
			dir_name = "down"

	var anim_name := prefix + dir_name
	_sprite.flip_h = flip

	if _current_anim != anim_name:
		_current_anim = anim_name
		_sprite.play(anim_name)
		if prefix == "idle_":
			_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count(anim_name)
