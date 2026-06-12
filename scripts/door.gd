extends StaticBody2D

## Animated door that can be opened/closed
## Supports locked doors requiring flags
## Swap door_sprite_sheet to change door style (must be 5 frames of 16x48)
##
## Scene transitions:
##   Set `target_scene` to a .tscn path to turn this door into a room exit.
##   The door will route through SceneRouter on interact, placing the player
##   at a SpawnPoint matching `target_spawn` in the destination scene.

@export var door_sprite_sheet: Texture2D
@export var is_open: bool = false
@export var required_flag: String = ""
@export var locked_message: String = "It's locked."

## If set, interacting with this door transitions to that scene instead of
## just opening/closing. Leave empty for a purely decorative/animated door.
@export_file("*.tscn") var target_scene: String = ""
## Spawn point ID in the target scene. Must match a SpawnPoint's `spawn_id`
## metadata in that scene. Defaults to "default".
@export var target_spawn: String = "default"
## If true, play the open animation before transitioning. Looks nicer but adds ~0.3s.
@export var animate_before_transition: bool = true

const FRAME_SIZE := Vector2(16, 48)
const FRAME_COUNT := 5
const ANIM_FPS := 16

@onready var interaction_zone: Area2D = $InteractionZone
@onready var prompt_label: Label = $PromptLabel
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player_in_range: bool = false
var _animating: bool = false


func _ready() -> void:
	prompt_label.visible = false
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

	if door_sprite_sheet:
		_build_sprite_frames()

	# Set initial state without animation. Guard on sprite_frames so a missing
	# or failed-to-load door_sprite_sheet doesn't spam "no animation" errors
	# (the frames only exist if _build_sprite_frames ran).
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("close"):
		if is_open:
			sprite.animation = "open"
		else:
			sprite.animation = "close"
		sprite.frame = FRAME_COUNT - 1

	collision_shape.disabled = is_open

	sprite.animation_finished.connect(_on_animation_finished)


func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	# Open animation: frames 0 → 4 (closed to open)
	frames.add_animation("open")
	frames.set_animation_speed("open", ANIM_FPS)
	frames.set_animation_loop("open", false)

	# Close animation: frames 4 → 0 (open to closed)
	frames.add_animation("close")
	frames.set_animation_speed("close", ANIM_FPS)
	frames.set_animation_loop("close", false)

	for i in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = door_sprite_sheet
		atlas.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame("open", atlas)

		# Close is reverse order
		var atlas_rev := AtlasTexture.new()
		atlas_rev.atlas = door_sprite_sheet
		atlas_rev.region = Rect2((FRAME_COUNT - 1 - i) * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame("close", atlas_rev)

	sprite.sprite_frames = frames


func interact() -> void:
	if _animating:
		return

	# Check lock
	if required_flag != "" and not GameState.has_flag(required_flag):
		FloatingTextManager.spawn_at(locked_message, global_position + Vector2(0, -40), Color(0.9, 0.6, 0.2))
		return

	# Scene-transition door: route through SceneRouter instead of toggling open/closed.
	if target_scene != "":
		_transition_to_target_scene()
		return

	_animating = true
	if is_open:
		# Close the door — re-enable collision immediately
		collision_shape.disabled = false
		sprite.play("close")
	else:
		# Open the door
		sprite.play("open")

	is_open = not is_open


func _transition_to_target_scene() -> void:
	_animating = true

	if animate_before_transition and not is_open:
		sprite.play("open")
		# Wait for the animation to finish before changing scene.
		await sprite.animation_finished

	SceneRouter.go_to(target_scene, target_spawn)


func _on_animation_finished() -> void:
	_animating = false
	if is_open:
		collision_shape.disabled = true


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		prompt_label.visible = true
		if body.has_method("set_nearby_npc"):
			body.set_nearby_npc(self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		prompt_label.visible = false
		if body.has_method("clear_nearby_npc"):
			body.clear_nearby_npc(self)
