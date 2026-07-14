class_name PathfindingGraph3D
extends Resource


func has_point(_point_id: Variant) -> bool:
	return false


func get_point_position(_point_id: Variant) -> Vector3:
	return Vector3.ZERO


func get_point_id_from_position(_world_position: Vector3) -> Variant:
	return null


func get_neighbors(_point_id: Variant) -> Array:
	return []


func can_traverse(_from_id: Variant, to_id: Variant) -> bool:
	return has_point(to_id)


func get_move_cost(from_id: Variant, to_id: Variant) -> float:
	return get_point_position(from_id).distance_to(get_point_position(to_id))


func estimate_cost(from_id: Variant, to_id: Variant) -> float:
	return get_point_position(from_id).distance_to(get_point_position(to_id))
