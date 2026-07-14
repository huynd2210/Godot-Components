class_name TileMapGridGraph2D
extends GridGraph2D


@export var tile_source: Node
@export var tilemap_layer := 0
@export var empty_cells_are_solid := true
@export var sync_cell_size_from_tile_set := true
@export var solid_custom_data_key := "solid"
@export var weight_custom_data_key := "weight"


func rebuild_from_tile_source(source: Node = null) -> void:
	if source != null:
		tile_source = source

	clear()

	if tile_source == null:
		return

	if sync_cell_size_from_tile_set:
		_sync_cell_size()

	if tile_source.has_method("get_used_rect"):
		var used_rect: Rect2i = tile_source.call("get_used_rect")
		set_bounds(used_rect)

	if not use_bounds:
		return

	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var cell := Vector2i(x, y)
			var tile_data := _get_cell_tile_data(cell)

			if tile_data == null:
				if empty_cells_are_solid:
					set_solid(cell, true)
				continue

			if not solid_custom_data_key.is_empty():
				var solid_value = tile_data.call("get_custom_data", solid_custom_data_key)
				if solid_value != null and bool(solid_value):
					set_solid(cell, true)

			if not weight_custom_data_key.is_empty():
				var weight_value = tile_data.call("get_custom_data", weight_custom_data_key)
				if typeof(weight_value) == TYPE_INT or typeof(weight_value) == TYPE_FLOAT:
					set_weight(cell, float(weight_value))


func world_to_cell(world_position: Vector2) -> Vector2i:
	if tile_source is Node2D and tile_source.has_method("local_to_map"):
		var source_2d := tile_source as Node2D
		var local_position := source_2d.to_local(world_position)
		return tile_source.call("local_to_map", local_position)

	return super.world_to_cell(world_position)


func cell_to_world(cell: Vector2i) -> Vector2:
	if tile_source is Node2D and tile_source.has_method("map_to_local"):
		var source_2d := tile_source as Node2D
		var local_position: Vector2 = tile_source.call("map_to_local", cell)
		return source_2d.to_global(local_position)

	return super.cell_to_world(cell)


func _get_cell_tile_data(cell: Vector2i) -> Variant:
	if tile_source == null or not tile_source.has_method("get_cell_tile_data"):
		return null

	if tile_source.get_class() == "TileMap":
		return tile_source.call("get_cell_tile_data", tilemap_layer, cell)

	return tile_source.call("get_cell_tile_data", cell)


func _sync_cell_size() -> void:
	var tile_set = tile_source.get("tile_set")
	if tile_set == null:
		return

	var tile_size = tile_set.get("tile_size")
	if typeof(tile_size) == TYPE_VECTOR2I:
		cell_size = Vector2(tile_size)
	elif typeof(tile_size) == TYPE_VECTOR2:
		cell_size = tile_size
