extends SceneTree


func _init() -> void:
	var graph := GridGraph3D.new()
	graph.set_bounds(Vector3i(0, 0, 0), Vector3i(6, 3, 4))
	graph.neighbor_mode = GridGraph3D.NeighborMode.ORTHOGONAL_6
	graph.heuristic = GridGraph3D.Heuristic.EUCLIDEAN
	graph.set_solid(Vector3i(1, 0, 0), true)
	graph.set_solid(Vector3i(1, 0, 1), true)
	graph.set_solid(Vector3i(1, 0, 2), true)

	var astar := ModularAStar3D.new()
	var path := astar.find_point_path(graph, Vector3i(0, 0, 0), Vector3i(5, 0, 0))

	if path.is_empty():
		push_error("Expected a 3D path around the wall.")
		quit(1)
		return

	if path.front() != Vector3i(0, 0, 0) or path.back() != Vector3i(5, 0, 0):
		push_error("Path endpoints were not preserved.")
		quit(1)
		return

	var blocked_path := astar.find_point_path(graph, Vector3i(0, 0, 0), Vector3i(1, 0, 1))
	if not blocked_path.is_empty():
		push_error("Expected blocked endpoint to fail.")
		quit(1)
		return

	print("3D pathfinding smoke test passed.")
	quit()
