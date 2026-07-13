extends SceneTree


func _init() -> void:
	var graph := GridGraph2D.new()
	graph.set_bounds(Rect2i(Vector2i.ZERO, Vector2i(6, 4)))
	graph.diagonal_mode = GridGraph2D.DiagonalMode.NO_CORNER_CUTTING
	graph.heuristic = GridGraph2D.Heuristic.OCTILE
	graph.set_solid(Vector2i(1, 0), true)
	graph.set_solid(Vector2i(1, 1), true)
	graph.set_solid(Vector2i(1, 2), true)

	var astar := ModularAStar2D.new()
	var path := astar.find_point_path(graph, Vector2i(0, 0), Vector2i(5, 0))

	if path.is_empty():
		push_error("Expected a path around the wall.")
		quit(1)
		return

	if path.front() != Vector2i(0, 0) or path.back() != Vector2i(5, 0):
		push_error("Path endpoints were not preserved.")
		quit(1)
		return

	var blocked_path := astar.find_point_path(graph, Vector2i(0, 0), Vector2i(1, 1))
	if not blocked_path.is_empty():
		push_error("Expected blocked endpoint to fail.")
		quit(1)
		return

	print("Pathfinding smoke test passed.")
	quit()
