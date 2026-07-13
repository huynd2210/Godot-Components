class_name Pathfinding2D
extends Node


signal path_found(path: PackedVector2Array)
signal path_failed(start_id: Variant, goal_id: Variant, status: String)

@export var graph: PathfindingGraph2D
@export var include_start := true
@export var include_goal := true
@export var closest_on_fail := false
@export var simplify_grid_paths := true
@export var heuristic_scale := 1.0
@export var max_iterations := 0

var astar := ModularAStar2D.new()


func find_world_path(start_world: Vector2, goal_world: Vector2) -> PackedVector2Array:
	if graph == null:
		path_failed.emit(null, null, "missing_graph")
		return PackedVector2Array()

	var start_id: Variant = graph.get_point_id_from_position(start_world)
	var goal_id: Variant = graph.get_point_id_from_position(goal_world)
	return find_path(start_id, goal_id)


func find_path(start_id: Variant, goal_id: Variant) -> PackedVector2Array:
	var path := _find_path_internal(start_id, goal_id)

	if path.is_empty() and astar.last_status != "found":
		path_failed.emit(start_id, goal_id, astar.last_status)
	else:
		path_found.emit(path)

	return path


func find_point_path(start_id: Variant, goal_id: Variant) -> Array:
	if graph == null:
		return []

	return astar.find_point_path(graph, start_id, goal_id, _get_astar_options())


func _find_path_internal(start_id: Variant, goal_id: Variant) -> PackedVector2Array:
	if graph == null:
		astar.last_status = "missing_graph"
		return PackedVector2Array()

	var point_path := astar.find_point_path(graph, start_id, goal_id, _get_astar_options())
	if point_path.is_empty():
		return PackedVector2Array()

	if simplify_grid_paths and graph is GridGraph2D:
		point_path = _simplify_grid_point_path(point_path)

	var world_path := PackedVector2Array()
	for point_id in point_path:
		world_path.append(graph.get_point_position(point_id))

	return world_path


func _get_astar_options() -> Dictionary:
	return {
		"include_start": include_start,
		"include_goal": include_goal,
		"closest_on_fail": closest_on_fail,
		"heuristic_scale": heuristic_scale,
		"max_iterations": max_iterations
	}


func _simplify_grid_point_path(point_path: Array) -> Array:
	if point_path.size() <= 2:
		return point_path

	var simplified := [point_path[0]]
	var previous_direction := _grid_direction(point_path[0], point_path[1])

	for index in range(2, point_path.size()):
		var current_direction := _grid_direction(point_path[index - 1], point_path[index])
		if current_direction != previous_direction:
			simplified.append(point_path[index - 1])
			previous_direction = current_direction

	simplified.append(point_path[point_path.size() - 1])
	return simplified


func _grid_direction(from_id: Variant, to_id: Variant) -> Vector2i:
	if typeof(from_id) != TYPE_VECTOR2I or typeof(to_id) != TYPE_VECTOR2I:
		return Vector2i.ZERO

	var from_cell: Vector2i = from_id
	var to_cell: Vector2i = to_id
	var delta := to_cell - from_cell
	return Vector2i(signi(delta.x), signi(delta.y))
