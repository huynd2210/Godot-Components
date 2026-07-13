extends Node2D


const CELL_SIZE := Vector2(24.0, 24.0)
const GRID_SIZE := Vector2i(30, 20)

var graph := GridGraph2D.new()
var astar := ModularAStar2D.new()
var start_cell := Vector2i(2, 2)
var goal_cell := Vector2i(26, 16)
var current_path := PackedVector2Array()


func _ready() -> void:
	graph.cell_size = CELL_SIZE
	graph.set_bounds(Rect2i(Vector2i.ZERO, GRID_SIZE))
	graph.diagonal_mode = GridGraph2D.DiagonalMode.NO_CORNER_CUTTING
	graph.heuristic = GridGraph2D.Heuristic.OCTILE

	for y in range(3, 17):
		if y != 10:
			graph.set_solid(Vector2i(12, y), true)

	for x in range(16, 25):
		if x != 21:
			graph.set_solid(Vector2i(x, 8), true)

	_rebuild_path()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		var cell := graph.world_to_cell(get_local_mouse_position())

		if not graph.bounds.has_point(cell):
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if graph.has_point(cell):
				goal_cell = cell
				_rebuild_path()

		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if cell != start_cell and cell != goal_cell:
				graph.set_solid(cell, not graph.is_solid(cell))
				_rebuild_path()


func _draw() -> void:
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * CELL_SIZE, CELL_SIZE)
			var fill := Color(0.12, 0.14, 0.16)

			if graph.is_solid(cell):
				fill = Color(0.08, 0.08, 0.09)
			elif cell == start_cell:
				fill = Color(0.18, 0.52, 0.36)
			elif cell == goal_cell:
				fill = Color(0.58, 0.24, 0.24)

			draw_rect(rect, fill, true)
			draw_rect(rect, Color(0.22, 0.24, 0.27), false, 1.0)

	if current_path.size() > 1:
		draw_polyline(current_path, Color(0.95, 0.72, 0.32), 4.0, true)
		for point in current_path:
			draw_circle(point, 4.0, Color(1.0, 0.91, 0.58))


func _rebuild_path() -> void:
	current_path = astar.find_path(graph, start_cell, goal_cell, {
		"closest_on_fail": true
	})
	queue_redraw()
