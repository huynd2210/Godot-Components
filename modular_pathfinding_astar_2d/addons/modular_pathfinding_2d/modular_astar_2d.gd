class_name ModularAStar2D
extends RefCounted


var allow_reopen_closed := true
var default_max_iterations := 0
var default_heuristic_scale := 1.0
var tie_breaker := 0.0001

var last_iterations := 0
var last_visited_count := 0
var last_status := ""


func find_path(graph: PathfindingGraph2D, start_id: Variant, goal_id: Variant, options := {}) -> PackedVector2Array:
	var point_path := find_point_path(graph, start_id, goal_id, options)
	var world_path := PackedVector2Array()

	for point_id in point_path:
		world_path.append(graph.get_point_position(point_id))

	return world_path


func find_point_path(graph: PathfindingGraph2D, start_id: Variant, goal_id: Variant, options := {}) -> Array:
	last_iterations = 0
	last_visited_count = 0
	last_status = "not_started"

	if graph == null:
		last_status = "missing_graph"
		return []

	if not graph.has_point(start_id) or not graph.has_point(goal_id):
		last_status = "invalid_endpoint"
		return []

	var include_start := bool(options.get("include_start", true))
	var include_goal := bool(options.get("include_goal", true))
	var closest_on_fail := bool(options.get("closest_on_fail", false))
	var max_iterations := int(options.get("max_iterations", default_max_iterations))
	var heuristic_scale := float(options.get("heuristic_scale", default_heuristic_scale))

	if start_id == goal_id:
		last_status = "found"
		if include_start:
			return [start_id]
		return []

	var open_heap := []
	var closed := {}
	var came_from := {}
	var g_score := {}

	g_score[start_id] = 0.0
	var start_h := graph.estimate_cost(start_id, goal_id)
	var best_id: Variant = start_id
	var best_h := start_h

	_heap_push(open_heap, {
		"id": start_id,
		"priority": start_h * heuristic_scale
	})

	while not open_heap.is_empty():
		if max_iterations > 0 and last_iterations >= max_iterations:
			last_status = "max_iterations"
			break

		var current_entry: Dictionary = _heap_pop(open_heap)
		var current_id: Variant = current_entry["id"]

		if closed.has(current_id):
			continue

		if not g_score.has(current_id):
			continue

		last_iterations += 1

		if current_id == goal_id:
			last_status = "found"
			last_visited_count = closed.size()
			var found_path := _reconstruct_path(came_from, current_id)
			return _trim_path(found_path, include_start, include_goal)

		closed[current_id] = true

		var current_g := float(g_score[current_id])
		for neighbor_id in graph.get_neighbors(current_id):
			if not graph.can_traverse(current_id, neighbor_id):
				continue

			if closed.has(neighbor_id):
				if not allow_reopen_closed:
					continue
				closed.erase(neighbor_id)

			var move_cost := graph.get_move_cost(current_id, neighbor_id)
			if move_cost < 0.0:
				continue

			var tentative_g := current_g + move_cost
			if not g_score.has(neighbor_id) or tentative_g < float(g_score[neighbor_id]):
				came_from[neighbor_id] = current_id
				g_score[neighbor_id] = tentative_g

				var neighbor_h := graph.estimate_cost(neighbor_id, goal_id)
				if neighbor_h < best_h:
					best_h = neighbor_h
					best_id = neighbor_id

				var priority := tentative_g + neighbor_h * heuristic_scale + tentative_g * tie_breaker
				_heap_push(open_heap, {
					"id": neighbor_id,
					"priority": priority
				})

	last_visited_count = closed.size()

	if closest_on_fail and (best_id == start_id or came_from.has(best_id)):
		last_status = "closest"
		var closest_path := _reconstruct_path(came_from, best_id)
		return _trim_path(closest_path, include_start, include_goal)

	if last_status == "not_started":
		last_status = "unreachable"

	return []


func _reconstruct_path(came_from: Dictionary, current_id: Variant) -> Array:
	var path := [current_id]

	while came_from.has(current_id):
		current_id = came_from[current_id]
		path.push_front(current_id)

	return path


func _trim_path(path: Array, include_start: bool, include_goal: bool) -> Array:
	var trimmed := path.duplicate()

	if not include_start and not trimmed.is_empty():
		trimmed.pop_front()

	if not include_goal and not trimmed.is_empty():
		trimmed.pop_back()

	return trimmed


func _heap_push(heap: Array, entry: Dictionary) -> void:
	heap.append(entry)
	var index := heap.size() - 1

	while index > 0:
		var parent := int((index - 1) / 2)
		if float(heap[parent]["priority"]) <= float(heap[index]["priority"]):
			break
		_heap_swap(heap, parent, index)
		index = parent


func _heap_pop(heap: Array) -> Dictionary:
	var result: Dictionary = heap[0]
	var last: Dictionary = heap.pop_back()

	if not heap.is_empty():
		heap[0] = last
		_heap_sink(heap, 0)

	return result


func _heap_sink(heap: Array, index: int) -> void:
	while true:
		var left := index * 2 + 1
		var right := left + 1
		var smallest := index

		if left < heap.size() and float(heap[left]["priority"]) < float(heap[smallest]["priority"]):
			smallest = left

		if right < heap.size() and float(heap[right]["priority"]) < float(heap[smallest]["priority"]):
			smallest = right

		if smallest == index:
			return

		_heap_swap(heap, index, smallest)
		index = smallest


func _heap_swap(heap: Array, a: int, b: int) -> void:
	var temp: Dictionary = heap[a]
	heap[a] = heap[b]
	heap[b] = temp
