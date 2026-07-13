class_name Pathfinding3D
extends Node


signal path_found(path: PackedVector3Array)
signal path_failed(start_id: Variant, goal_id: Variant, status: String)

@export var graph: PathfindingGraph3D
@export var include_start := true
@export var include_goal := true
@export var closest_on_fail := false
@export var simplify_grid_paths := true
@export var heuristic_scale := 1.0
@export var max_iterations := 0

var astar := ModularAStar3D.new()


func find_world_path(start_world: Vector3, goal_world: Vector3) -> PackedVector3Array:
	if graph == null:
		path_failed.emit(null, null, "missing_graph")
		return PackedVector3Array()

	var start_id: Variant = graph.get_point_id_from_position(start_world)
	var goal_id: Variant = graph.get_point_id_from_position(goal_world)
	return find_path(start_id, goal_id)


func find_path(start_id: Variant, goal_id: Variant) -> PackedVector3Array:
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


func _find_path_internal(start_id: Variant, goal_id: Variant) -> PackedVector3Array:
	if graph == null:
		astar.last_status = "missing_graph"
		return PackedVector3Array()

	var point_path := astar.find_point_path(graph, start_id, goal_id, _get_astar_options())
	if point_path.is_empty():
		return PackedVector3Array()

	if simplify_grid_paths and graph is GridGraph3D:
		point_path = _simplify_grid_point_path(point_path)

	var world_path := PackedVector3Array()
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


func _grid_direction(from_id: Variant, to_id: Variant) -> Vector3i:
	if typeof(from_id) != TYPE_VECTOR3I or typeof(to_id) != TYPE_VECTOR3I:
		return Vector3i(0, 0, 0)

	var from_cell: Vector3i = from_id
	var to_cell: Vector3i = to_id
	var delta := to_cell - from_cell
	return Vector3i(_axis_sign(delta.x), _axis_sign(delta.y), _axis_sign(delta.z))


func _axis_sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0
