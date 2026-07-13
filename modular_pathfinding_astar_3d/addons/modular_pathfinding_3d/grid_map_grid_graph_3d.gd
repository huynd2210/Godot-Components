class_name GridMapGridGraph3D
extends GridGraph3D


@export var grid_map: GridMap
@export var occupied_cells_are_solid := true
@export var empty_cells_are_solid := false
@export var sync_cell_size_from_grid_map := true
@export var bounds_padding := Vector3i(1, 1, 1)

var _item_weights := {}


func set_item_weight(item_id: int, weight: float) -> void:
	if is_equal_approx(weight, default_weight):
		_item_weights.erase(item_id)
	else:
		_item_weights[item_id] = max(weight, 0.0)


func get_item_weight(item_id: int) -> float:
	return float(_item_weights.get(item_id, default_weight))


func rebuild_from_grid_map(source: GridMap = null) -> void:
	if source != null:
		grid_map = source

	clear()

	if grid_map == null:
		return

	if sync_cell_size_from_grid_map:
		var map_cell_size = grid_map.get("cell_size")
		if typeof(map_cell_size) == TYPE_VECTOR3:
			cell_size = map_cell_size

	var used_cells := grid_map.get_used_cells()
	if not use_bounds and not used_cells.is_empty():
		_set_bounds_from_used_cells(used_cells, bounds_padding)

	if not use_bounds:
		return

	for x in range(bounds_position.x, bounds_position.x + bounds_size.x):
		for y in range(bounds_position.y, bounds_position.y + bounds_size.y):
			for z in range(bounds_position.z, bounds_position.z + bounds_size.z):
				var cell := Vector3i(x, y, z)
				var item_id := grid_map.get_cell_item(cell)
				var has_item := item_id != -1

				if has_item:
					if occupied_cells_are_solid:
						set_solid(cell, true)
					else:
						set_weight(cell, get_item_weight(item_id))
				elif empty_cells_are_solid:
					set_solid(cell, true)


func world_to_cell(world_position: Vector3) -> Vector3i:
	if grid_map != null:
		return grid_map.local_to_map(grid_map.to_local(world_position))

	return super.world_to_cell(world_position)


func cell_to_world(cell: Vector3i) -> Vector3:
	if grid_map != null:
		return grid_map.to_global(grid_map.map_to_local(cell))

	return super.cell_to_world(cell)


func _set_bounds_from_used_cells(used_cells: Array, padding: Vector3i) -> void:
	var min_cell: Vector3i = used_cells[0]
	var max_cell: Vector3i = used_cells[0]

	for cell in used_cells:
		min_cell.x = min(min_cell.x, cell.x)
		min_cell.y = min(min_cell.y, cell.y)
		min_cell.z = min(min_cell.z, cell.z)
		max_cell.x = max(max_cell.x, cell.x)
		max_cell.y = max(max_cell.y, cell.y)
		max_cell.z = max(max_cell.z, cell.z)

	min_cell -= padding
	max_cell += padding
	set_bounds(min_cell, max_cell - min_cell + Vector3i(1, 1, 1))
