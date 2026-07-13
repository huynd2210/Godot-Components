class_name GridGraph3D
extends PathfindingGraph3D


enum NeighborMode {
	ORTHOGONAL_6,
	EDGES_18,
	CORNERS_26
}

enum Heuristic {
	MANHATTAN,
	EUCLIDEAN,
	CHEBYSHEV,
	DIAGONAL_26
}

const SQRT_2 := 1.4142135623730951
const SQRT_3 := 1.7320508075688772

@export var cell_size := Vector3.ONE
@export var origin := Vector3.ZERO
@export var default_weight := 1.0
@export var minimum_weight := 1.0
@export var use_bounds := false
@export var bounds_position := Vector3i(0, 0, 0)
@export var bounds_size := Vector3i(16, 4, 16)
@export var neighbor_mode := NeighborMode.ORTHOGONAL_6
@export var prevent_corner_cutting := true
@export var heuristic := Heuristic.EUCLIDEAN

var _solid_cells := {}
var _cell_weights := {}


func clear() -> void:
	_solid_cells.clear()
	_cell_weights.clear()


func set_bounds(position: Vector3i, size: Vector3i) -> void:
	bounds_position = position
	bounds_size = size
	use_bounds = true


func clear_bounds() -> void:
	use_bounds = false


func set_solid(cell: Vector3i, solid := true) -> void:
	if solid:
		_solid_cells[cell] = true
	else:
		_solid_cells.erase(cell)


func is_solid(cell: Vector3i) -> bool:
	return _solid_cells.has(cell)


func is_walkable(cell: Vector3i) -> bool:
	return has_point(cell)


func set_weight(cell: Vector3i, weight: float) -> void:
	if is_equal_approx(weight, default_weight):
		_cell_weights.erase(cell)
	else:
		_cell_weights[cell] = max(weight, 0.0)


func get_weight(cell: Vector3i) -> float:
	return float(_cell_weights.get(cell, default_weight))


func world_to_cell(world_position: Vector3) -> Vector3i:
	var local_position := world_position - origin
	return Vector3i(
		floori(local_position.x / cell_size.x),
		floori(local_position.y / cell_size.y),
		floori(local_position.z / cell_size.z)
	)


func cell_to_world(cell: Vector3i) -> Vector3:
	return origin + Vector3(cell) * cell_size + cell_size * 0.5


func get_point_id_from_position(world_position: Vector3) -> Variant:
	return world_to_cell(world_position)


func has_point(point_id: Variant) -> bool:
	if typeof(point_id) != TYPE_VECTOR3I:
		return false

	var cell: Vector3i = point_id
	if use_bounds and not _bounds_has_cell(cell):
		return false

	return not is_solid(cell)


func get_point_position(point_id: Variant) -> Vector3:
	if typeof(point_id) != TYPE_VECTOR3I:
		return Vector3.ZERO

	return cell_to_world(point_id)


func get_neighbors(point_id: Variant) -> Array:
	if typeof(point_id) != TYPE_VECTOR3I:
		return []

	var cell: Vector3i = point_id
	var neighbors := []

	for direction in _get_neighbor_directions():
		var next_cell := cell + direction
		if has_point(next_cell) and _is_step_allowed(cell, direction):
			neighbors.append(next_cell)

	return neighbors


func can_traverse(from_id: Variant, to_id: Variant) -> bool:
	if typeof(from_id) != TYPE_VECTOR3I or typeof(to_id) != TYPE_VECTOR3I:
		return false

	if not has_point(to_id):
		return false

	var from_cell: Vector3i = from_id
	var to_cell: Vector3i = to_id
	var delta := to_cell - from_cell

	if _nonzero_axis_count(delta) > _max_step_axes():
		return false

	if abs(delta.x) <= 1 and abs(delta.y) <= 1 and abs(delta.z) <= 1:
		return _is_step_allowed(from_cell, delta)

	return false


func get_move_cost(from_id: Variant, to_id: Variant) -> float:
	if typeof(from_id) != TYPE_VECTOR3I or typeof(to_id) != TYPE_VECTOR3I:
		return INF

	var from_cell: Vector3i = from_id
	var to_cell: Vector3i = to_id
	var delta := to_cell - from_cell
	var distance := (Vector3(delta) * cell_size).length()
	return distance * get_weight(to_cell)


func estimate_cost(from_id: Variant, to_id: Variant) -> float:
	if typeof(from_id) != TYPE_VECTOR3I or typeof(to_id) != TYPE_VECTOR3I:
		return 0.0

	var from_cell: Vector3i = from_id
	var to_cell: Vector3i = to_id
	var delta := to_cell - from_cell
	var dx := abs(delta.x)
	var dy := abs(delta.y)
	var dz := abs(delta.z)
	var world_delta := Vector3(dx * cell_size.x, dy * cell_size.y, dz * cell_size.z)
	var base_cost := 0.0

	match heuristic:
		Heuristic.MANHATTAN:
			base_cost = world_delta.x + world_delta.y + world_delta.z
		Heuristic.EUCLIDEAN:
			base_cost = world_delta.length()
		Heuristic.CHEBYSHEV:
			base_cost = max(world_delta.x, max(world_delta.y, world_delta.z))
		Heuristic.DIAGONAL_26:
			base_cost = _diagonal_26_estimate(dx, dy, dz) * _minimum_cell_axis()
		_:
			base_cost = world_delta.length()

	return base_cost * max(minimum_weight, 0.0)


func get_solid_cells() -> Array:
	return _solid_cells.keys()


func get_weighted_cells() -> Array:
	return _cell_weights.keys()


func _bounds_has_cell(cell: Vector3i) -> bool:
	return (
		cell.x >= bounds_position.x
		and cell.y >= bounds_position.y
		and cell.z >= bounds_position.z
		and cell.x < bounds_position.x + bounds_size.x
		and cell.y < bounds_position.y + bounds_size.y
		and cell.z < bounds_position.z + bounds_size.z
	)


func _get_neighbor_directions() -> Array:
	var directions := []
	var max_axes := _max_step_axes()

	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var direction := Vector3i(x, y, z)
				var axis_count := _nonzero_axis_count(direction)
				if axis_count > 0 and axis_count <= max_axes:
					directions.append(direction)

	return directions


func _max_step_axes() -> int:
	match neighbor_mode:
		NeighborMode.ORTHOGONAL_6:
			return 1
		NeighborMode.EDGES_18:
			return 2
		NeighborMode.CORNERS_26:
			return 3
		_:
			return 1


func _is_step_allowed(cell: Vector3i, delta: Vector3i) -> bool:
	var axis_count := _nonzero_axis_count(delta)
	if axis_count <= 1:
		return true

	if not prevent_corner_cutting:
		return true

	var axis_offsets := _axis_offsets(delta)
	for offset in axis_offsets:
		if not has_point(cell + offset):
			return false

	if axis_count == 3:
		for first in range(axis_offsets.size()):
			for second in range(first + 1, axis_offsets.size()):
				if not has_point(cell + axis_offsets[first] + axis_offsets[second]):
					return false

	return true


func _axis_offsets(delta: Vector3i) -> Array:
	var offsets := []

	if delta.x != 0:
		offsets.append(Vector3i(_axis_sign(delta.x), 0, 0))
	if delta.y != 0:
		offsets.append(Vector3i(0, _axis_sign(delta.y), 0))
	if delta.z != 0:
		offsets.append(Vector3i(0, 0, _axis_sign(delta.z)))

	return offsets


func _nonzero_axis_count(value: Vector3i) -> int:
	var count := 0

	if value.x != 0:
		count += 1
	if value.y != 0:
		count += 1
	if value.z != 0:
		count += 1

	return count


func _axis_sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0


func _minimum_cell_axis() -> float:
	return min(cell_size.x, min(cell_size.y, cell_size.z))


func _diagonal_26_estimate(dx: int, dy: int, dz: int) -> float:
	var distances := [dx, dy, dz]
	distances.sort()

	var a := float(distances[0])
	var b := float(distances[1])
	var c := float(distances[2])
	return c + (SQRT_2 - 1.0) * b + (SQRT_3 - SQRT_2) * a
