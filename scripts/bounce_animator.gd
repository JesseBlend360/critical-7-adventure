extends Node
class_name BounceAnimator

## Bouncy idle bob and shadow animation system
## Attach as child of any CharacterBody2D or StaticBody2D with a Sprite2D sibling

# Idle animation
@export_group("Idle Animation")
@export var idle_bob_px: float = 1.0
@export var idle_bob_period: float = 1.0

# Movement animation
@export_group("Movement Animation")
@export var move_bob_px: float = 1.5
@export var move_hop_px: float = 1.5
@export var move_bob_period: float = 0.3
@export var move_rotation_deg: float = 2.0

# Options
@export_group("Options")
@export var pixel_snap: bool = false

# Shadow
@export_group("Shadow")
@export var shadow_enabled: bool = true
@export var shadow_base_scale: Vector2 = Vector2(0.9, 0.5)
@export var shadow_squash: float = 0.2
@export var shadow_offset_y: float = 22.0
@export var shadow_color: Color = Color(0, 0, 0, 0.5)

# References
@export_group("References")
@export var target_sprite: Sprite2D

# Internal state
var _time: float = 0.0
var _is_moving: bool = false
var _last_position: Vector2
var _shadow: Sprite2D
var _sprite_base_position: Vector2


func _ready() -> void:
	# Find target sprite if not assigned
	if not target_sprite:
		target_sprite = get_parent().get_node_or_null("Sprite2D")

	if not target_sprite:
		push_warning("BounceAnimator: No Sprite2D found")
		return

	_sprite_base_position = target_sprite.position
	_last_position = get_parent().global_position

	if shadow_enabled:
		# Use call_deferred to ensure parent is fully ready
		call_deferred("_create_shadow")


func _create_shadow() -> void:
	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"

	# Create simple ellipse shadow texture
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)

	for x in range(size):
		for y in range(size):
			# Ellipse formula: (x/a)^2 + (y/b)^2 <= 1
			var dx := (x - center.x) / (size / 2.0)
			var dy := (y - center.y) / (size / 4.0)  # Flatten vertically
			var dist := sqrt(dx * dx + dy * dy)

			if dist <= 1.0:
				var alpha := (1.0 - dist) * shadow_color.a
				img.set_pixel(x, y, Color(shadow_color.r, shadow_color.g, shadow_color.b, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	var tex := ImageTexture.create_from_image(img)
	_shadow.texture = tex
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.z_index = -1
	_shadow.position = Vector2(0, shadow_offset_y)
	_shadow.scale = shadow_base_scale

	get_parent().add_child(_shadow)


func _process(delta: float) -> void:
	if not target_sprite:
		return

	_time += delta

	# Detect motion (instant switch, no blending)
	var current_pos = get_parent().global_position
	_is_moving = _detect_motion(current_pos)
	_last_position = current_pos

	# Calculate bob offset and rotation
	var anim_data = _calculate_bob_offset()
	var offset: Vector2 = anim_data["offset"]
	var rotation_deg: float = anim_data["rotation"]

	# Apply to sprite
	target_sprite.position = _sprite_base_position + offset
	target_sprite.rotation_degrees = rotation_deg

	# Update shadow
	if _shadow:
		_update_shadow(offset.y)


func _detect_motion(current_pos: Vector2) -> bool:
	var parent = get_parent()

	# Check for is_moving property (NPC with wander)
	if "is_moving" in parent:
		return parent.is_moving

	# Check for velocity (CharacterBody2D)
	if "velocity" in parent:
		return parent.velocity.length() > 1.0

	# Fallback: position delta
	return current_pos.distance_to(_last_position) > 0.5


func _calculate_bob_offset() -> Dictionary:
	var offset_x: float = 0.0
	var offset_y: float = 0.0
	var rotation: float = 0.0

	if _is_moving:
		# Walking: bob + side-to-side hop + rotation
		var phase = fmod(_time, move_bob_period) / move_bob_period
		var triangle = 1.0 - abs(phase * 2.0 - 1.0)
		var signed_wave = sin(phase * TAU)

		offset_y = -triangle * move_bob_px
		offset_x = signed_wave * move_hop_px
		rotation = -signed_wave * move_rotation_deg
	else:
		# Idle: gentle vertical bob only
		var phase = fmod(_time, idle_bob_period) / idle_bob_period
		var triangle = 1.0 - abs(phase * 2.0 - 1.0)

		offset_y = -triangle * idle_bob_px

	if pixel_snap:
		offset_x = round(offset_x)
		offset_y = round(offset_y)

	return {
		"offset": Vector2(offset_x, offset_y),
		"rotation": rotation
	}


func _update_shadow(bob_height: float) -> void:
	var max_bob = max(idle_bob_px, move_bob_px)
	if max_bob == 0:
		return

	# Shadow squashes when sprite is higher
	var squash_factor = 1.0 + (bob_height / max_bob) * shadow_squash
	_shadow.scale.x = shadow_base_scale.x * squash_factor
	_shadow.scale.y = shadow_base_scale.y / squash_factor

	# Fade shadow slightly when sprite is higher
	var alpha_factor = 1.0 - abs(bob_height / max_bob) * 0.2
	_shadow.modulate.a = shadow_color.a * alpha_factor
