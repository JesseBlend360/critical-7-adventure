extends Node2D

## Office map controller
## TileMapLayer nodes are created in the editor, not at runtime.
## Add FloorLayer and WallLayer as children in the scene, then paint tiles in the editor.

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var wall_layer: TileMapLayer = $WallLayer

func _ready() -> void:
	# Layers are set up in the editor - nothing to generate at runtime
	pass
