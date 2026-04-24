extends Node

## SceneRouter - Handles transitions between room scenes
##
## Each room scene has one or more SpawnPoint nodes (Marker2D in group "spawn_point"
## with a `spawn_id` metadata key). When transitioning, call:
##
##   SceneRouter.go_to("res://scenes/rooms/war_room.tscn", "from_hallway")
##
## The player in the destination scene will position itself at the matching
## SpawnPoint on _ready().

signal scene_changing(from_path: String, to_path: String)
signal scene_changed(to_path: String)

# Set by go_to() before the change; read by Player._ready() in the new scene.
var pending_spawn_id: String = "default"

# Previous scene path — useful for "back" buttons or debugging.
var previous_scene_path: String = ""


func go_to(scene_path: String, spawn_id: String = "default") -> void:
	if scene_path.is_empty():
		push_error("SceneRouter.go_to called with empty path")
		return

	pending_spawn_id = spawn_id
	previous_scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""

	scene_changing.emit(previous_scene_path, scene_path)

	# change_scene_to_file is deferred; wait a frame so listeners can react cleanly.
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: failed to change scene to %s (err=%d)" % [scene_path, err])
		return

	# Notify after the new scene is current.
	await get_tree().process_frame
	scene_changed.emit(scene_path)


## Called by Player._ready() to find its spawn position in the current scene.
## Returns Vector2.ZERO and warns if no matching spawn point is found.
func get_spawn_position(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var tree := get_tree()
	if not tree:
		return fallback

	var spawn_points := tree.get_nodes_in_group("spawn_point")
	var want := pending_spawn_id

	# Exact match first.
	for sp in spawn_points:
		if sp is Node2D and sp.has_meta("spawn_id") and str(sp.get_meta("spawn_id")) == want:
			return (sp as Node2D).global_position

	# Fallback: any spawn point named "default"/spawn_id "default".
	for sp in spawn_points:
		if sp is Node2D and sp.has_meta("spawn_id") and str(sp.get_meta("spawn_id")) == "default":
			return (sp as Node2D).global_position

	# Final fallback: first spawn point.
	if spawn_points.size() > 0 and spawn_points[0] is Node2D:
		return (spawn_points[0] as Node2D).global_position

	push_warning("SceneRouter: no spawn point found for id '%s'" % want)
	return fallback
