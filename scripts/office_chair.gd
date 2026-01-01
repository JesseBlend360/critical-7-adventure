extends RigidBody2D

## Office Chair - Spinnable furniture
## Player can interact to spin the chair

@onready var sprite: Sprite2D = $Sprite
@onready var interaction_area: Area2D = $InteractionArea

# Chair facing directions and their sprite regions (16x16 tiles, different rows/columns)
# Adjust these Rect2 values to match the actual sprite positions in your spritesheet
var direction_regions: Array[Rect2] = [
	Rect2(32, 128, 16, 32),   # Down (facing camera) - current
	Rect2(64, 128, 16, 32),   # Left
	Rect2(16, 128, 16, 32),   # Up (facing away)
	Rect2(80, 128, 16, 32),   # Right
]

@export_enum("Down", "Left", "Up", "Right") var initial_direction: int = 0
var current_direction: int = 0  # 0=down, 1=left, 2=up, 3=right
var is_spinning: bool = false
var spin_speed: float = 0.0
var spin_timer: float = 0.0

const INITIAL_SPIN_SPEED: float = 6.0  # Rotations per second at start
const MAX_SPIN_SPEED: float = 20.0  # Maximum spin speed
const SPIN_FRICTION: float = 4.0  # How fast it slows down
const MIN_SPIN_SPEED: float = 1.0  # Speed at which it stops

var player_ref: Node2D = null


func _ready() -> void:
	# Configure RigidBody2D for pushable furniture
	mass = 2.0
	gravity_scale = 0.0
	lock_rotation = true
	linear_damp = 5.0

	# Set initial direction
	current_direction = initial_direction
	_update_sprite()

	# Create interaction area if it doesn't exist
	if not has_node("InteractionArea"):
		_create_interaction_area()
	else:
		interaction_area = $InteractionArea

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _create_interaction_area() -> void:
	interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20  # Interaction radius (in scaled units, so ~60px)
	collision.shape = shape

	interaction_area.add_child(collision)
	add_child(interaction_area)


func _process(delta: float) -> void:
	if is_spinning:
		_update_spin(delta)


## Called by player when they press interact while nearby
func interact() -> void:
	spin_chair()


func spin_chair() -> void:
	# Add spin momentum, capped at max
	spin_speed = minf(spin_speed + INITIAL_SPIN_SPEED, MAX_SPIN_SPEED)
	is_spinning = true


func _update_spin(delta: float) -> void:
	if spin_speed <= 0:
		is_spinning = false
		return

	# Accumulate spin
	spin_timer += spin_speed * delta

	# Check if we've rotated to the next direction (every 0.25 = 90 degrees)
	while spin_timer >= 0.25:
		spin_timer -= 0.25
		current_direction = (current_direction + 1) % 4
		_update_sprite()

	# Apply friction
	spin_speed -= SPIN_FRICTION * delta

	# Stop if too slow
	if spin_speed < MIN_SPIN_SPEED:
		spin_speed = 0
		is_spinning = false


func _update_sprite() -> void:
	sprite.region_rect = direction_regions[current_direction]


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		# Register with player as a nearby interactable (like NPCs do)
		if body.has_method("set_nearby_npc"):
			body.set_nearby_npc(self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Unregister from player
		if body.has_method("clear_nearby_npc"):
			body.clear_nearby_npc(self)
		player_ref = null
