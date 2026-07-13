extends Node3D


const GRID_SIZE := Vector3i(16, 4, 16)
const START_CELL := Vector3i(1, 0, 1)
const GOAL_CELL := Vector3i(14, 2, 13)

var graph := GridGraph3D.new()
var astar := ModularAStar3D.new()
var current_point_path := []
var visual_root: Node3D


func _ready() -> void:
	graph.cell_size = Vector3.ONE
	graph.set_bounds(Vector3i(0, 0, 0), GRID_SIZE)
	graph.neighbor_mode = GridGraph3D.NeighborMode.CORNERS_26
	graph.prevent_corner_cutting = true
	graph.heuristic = GridGraph3D.Heuristic.EUCLIDEAN

	for z in range(2, 15):
		if z != 8:
			graph.set_solid(Vector3i(6, 0, z), true)
			graph.set_solid(Vector3i(6, 1, z), true)

	for x in range(8, 14):
		if x != 11:
			graph.set_solid(Vector3i(x, 1, 8), true)
			graph.set_solid(Vector3i(x, 2, 8), true)

	graph.set_solid(Vector3i(10, 0, 11), true)
	graph.set_solid(Vector3i(10, 1, 11), true)
	graph.set_solid(Vector3i(11, 0, 11), true)

	current_point_path = astar.find_point_path(graph, START_CELL, GOAL_CELL)
	_build_scene()


func _build_scene() -> void:
	_add_camera()
	_add_light()

	visual_root = Node3D.new()
	add_child(visual_root)

	for x in range(GRID_SIZE.x):
		for z in range(GRID_SIZE.z):
			_add_box(graph.cell_to_world(Vector3i(x, 0, z)) - Vector3(0.0, 0.53, 0.0), Vector3(0.96, 0.06, 0.96), Color(0.18, 0.2, 0.22, 1.0))

	for cell in graph.get_solid_cells():
		_add_box(graph.cell_to_world(cell), Vector3(0.9, 0.9, 0.9), Color(0.08, 0.09, 0.1, 1.0))

	for cell in current_point_path:
		_add_box(graph.cell_to_world(cell), Vector3(0.34, 0.34, 0.34), Color(1.0, 0.76, 0.22, 1.0))

	_add_box(graph.cell_to_world(START_CELL), Vector3(0.72, 0.72, 0.72), Color(0.12, 0.58, 0.34, 1.0))
	_add_box(graph.cell_to_world(GOAL_CELL), Vector3(0.72, 0.72, 0.72), Color(0.68, 0.22, 0.22, 1.0))


func _add_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(10.0, 11.0, 23.0)
	camera.look_at(Vector3(8.0, 1.0, 8.0), Vector3.UP)
	camera.current = true
	add_child(camera)


func _add_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	light.light_energy = 1.4
	add_child(light)


func _add_box(position: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh.material = material

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	visual_root.add_child(instance)
