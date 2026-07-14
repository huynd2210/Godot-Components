class_name GridGraph2D
extends PathfindingGraph2D


enum DiagonalMode {
	NEVER,
	ALWAYS,
	NO_CORNER_CUTTING,
	AT_LEAST_ONE_OPEN
}

enum Heuristic {
	MANHATTAN,
	EUCLIDEAN,
	OCTILE,
	CHEBYSHEV
}

const SQRT_2 := 1.4142135623730951
const ORTHOGONAL_DIRECTIONS := [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP
]
const DIAGONAL_DIRECTIONS := [
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1)
]

@export var cell_size := Vector2(16.0, 16.0)
@export var origin := Vector2.ZERO
@export var default_weight := 1.0
@export var minimum_weight := 1.0
@export var use_bounds := false
@export var bounds := Rect2i(Vector2i.ZERO, Vector2i(32, 18))
@export var diagonal_mode := DiagonalMode.NEVER
@export var heuristic := Heuristic.MANHATTAN

var _solid_cells := {}
var _cell_weights := {}


func clear() -> void:
	_solid_cells.clear()
	_cell_weights.clear()


func set_bounds(new_bounds: Rect2i) -> void:
	bounds = new_bounds
	use_bounds = true


func clear_bounds() -> void:
	use_bounds = false


func set_solid(cell: Vector2i, solid := true) -> void:
	if solid:
		_solid_cells[cell] = true
	else:
		_solid_cells.erase(cell)


func is_solid(cell: Vector2i) -> bool:
	return _solid_cells.has(cell)


func is_walkable(cell: Vector2i) -> bool:
	return has_point(cell)


func set_weight(cell: Vector2i, weight: float) -> void:
	if is_equal_approx(weight, default_weight):
		_cell_weights.erase(cell)
	else:
		_cell_weights[cell] = max(weight, 0.0)


func get_weight(cell: Vector2i) -> float:
	return float(_cell_weights.get(cell, default_weight))


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := world_position - origin
	return Vector2i(
		floori(local_position.x / cell_size.x),
		floori(local_position.y / cell_size.y)
	)


func cell_to_world(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell) * cell_size + cell_size * 0.5


func get_point_id_from_position(world_position: Vector2) -> Variant:
	return world_to_cell(world_position)


func has_point(point_id: Variant) -> bool:
	if typeof(point_id) != TYPE_VECTOR2I:
		return false

	var cell: Vector2i = point_id
	if use_bounds and not bounds.has_point(cell):
		return false

	return not is_solid(cell)


func get_point_position(point_id: Variant) -> Vector2:
	if typeof(point_id) != TYPE_VECTOR2I:
		return Vector2.ZERO

	return cell_to_world(point_id)


func get_neighbors(point_id: Variant) -> Array:
	if typeof(point_id) != TYPE_VECTOR2I:
		return []

	var cell: Vector2i = point_id
	var neighbors := []

	for direction in ORTHOGONAL_DIRECTIONS:
		var next_cell := cell + direction
		if has_point(next_cell):
			neighbors.append(next_cell)

	if diagonal_mode == DiagonalMode.NEVER:
		return neighbors

	for direction in DIAGONAL_DIRECTIONS:
		var diagonal_cell := cell + direction
		if has_point(diagonal_cell) and _is_diagonal_allowed(cell, direction):
			neighbors.append(diagonal_cell)

	return neighbors


func can_traverse(from_id: Variant, to_id: Variant) -> bool:
	if typeof(from_id) != TYPE_VECTOR2I or typeof(to_id) != TYPE_VECTOR2I:
		return false

	if not has_point(to_id):
		return false

	var from_cell: Vector2i = from_id
	var to_cell: Vector2i = to_id
	var delta := to_cell - from_cell
	if abs(delta.x) <= 1 and abs(delta.y) <= 1:
		if delta.x != 0 and delta.y != 0:
			return _is_diagonal_allowed(from_cell, delta)
		return true

	return false


func get_move_cost(from_id: Variant, to_id: Variant) -> float:
	if typeof(from_id) != TYPE_VECTOR2I or typeof(to_id) != TYPE_VECTOR2I:
		return INF

	var from_cell: Vector2i = from_id
	var to_cell: Vector2i = to_id
	var delta := to_cell - from_cell
	var step_cost := SQRT_2 if delta.x != 0 and delta.y != 0 else 1.0
	return step_cost * get_weight(to_cell)


func estimate_cost(from_id: Variant, to_id: Variant) -> float:
	if typeof(from_id) != TYPE_VECTOR2I or typeof(to_id) != TYPE_VECTOR2I:
		return 0.0

	var from_cell: Vector2i = from_id
	var to_cell: Vector2i = to_id
	var delta := to_cell - from_cell
	var dx := abs(delta.x)
	var dy := abs(delta.y)
	var base_cost := 0.0

	match heuristic:
		Heuristic.MANHATTAN:
			base_cost = float(dx + dy)
		Heuristic.EUCLIDEAN:
			base_cost = Vector2(dx, dy).length()
		Heuristic.OCTILE:
			base_cost = float(max(dx, dy)) + (SQRT_2 - 1.0) * float(min(dx, dy))
		Heuristic.CHEBYSHEV:
			base_cost = float(max(dx, dy))
		_:
			base_cost = float(dx + dy)

	return base_cost * max(minimum_weight, 0.0)


func get_solid_cells() -> Array:
	return _solid_cells.keys()


func get_weighted_cells() -> Array:
	return _cell_weights.keys()


func _is_diagonal_allowed(cell: Vector2i, diagonal_delta: Vector2i) -> bool:
	match diagonal_mode:
		DiagonalMode.ALWAYS:
			return true
		DiagonalMode.NO_CORNER_CUTTING:
			return has_point(cell + Vector2i(diagonal_delta.x, 0)) and has_point(cell + Vector2i(0, diagonal_delta.y))
		DiagonalMode.AT_LEAST_ONE_OPEN:
			return has_point(cell + Vector2i(diagonal_delta.x, 0)) or has_point(cell + Vector2i(0, diagonal_delta.y))
		_:
			return false
