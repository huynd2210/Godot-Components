# Modular Pathfinding 3D

A small Godot 4 component for modular A* pathfinding in 3D projects.

The solver is separate from the graph, so you can use the included voxel-style grid graph, build from a `GridMap`, or create a custom graph for waypoints, rooms, procedural volumes, flying enemies, or tactical maps.

## Files

- `addons/modular_pathfinding_3d/modular_astar_3d.gd` - pure A* solver.
- `addons/modular_pathfinding_3d/pathfinding_graph_3d.gd` - base graph contract.
- `addons/modular_pathfinding_3d/grid_graph_3d.gd` - reusable `Vector3i` grid graph.
- `addons/modular_pathfinding_3d/grid_map_grid_graph_3d.gd` - optional `GridMap` occupancy adapter.
- `addons/modular_pathfinding_3d/pathfinding_3d.gd` - optional node wrapper for world-space path requests.
- `examples/grid_pathfinding_3d_demo.tscn` - runnable 3D demo scene.

## Quick Start

```gdscript
var graph := GridGraph3D.new()
graph.cell_size = Vector3.ONE
graph.set_bounds(Vector3i(0, 0, 0), Vector3i(32, 8, 32))
graph.neighbor_mode = GridGraph3D.NeighborMode.CORNERS_26
graph.prevent_corner_cutting = true
graph.heuristic = GridGraph3D.Heuristic.EUCLIDEAN

graph.set_solid(Vector3i(10, 0, 12), true)
graph.set_weight(Vector3i(11, 0, 12), 3.0)

var astar := ModularAStar3D.new()
var path := astar.find_path(graph, Vector3i(0, 0, 0), Vector3i(20, 2, 15))
```

`path` is a `PackedVector3Array` of world positions centered inside each grid cell.

## Movement Modes

- `ORTHOGONAL_6` moves on the six cardinal axes.
- `EDGES_18` adds two-axis diagonal moves.
- `CORNERS_26` adds full three-axis diagonal moves.

When `prevent_corner_cutting` is enabled, diagonal moves are blocked unless their supporting side cells are also walkable.

## GridMap Graphs

`GridMapGridGraph3D` can rebuild walkability from a `GridMap`:

```gdscript
var graph := GridMapGridGraph3D.new()
graph.grid_map = $GridMap
graph.occupied_cells_are_solid = true
graph.empty_cells_are_solid = false
graph.set_bounds(Vector3i(0, 0, 0), Vector3i(32, 8, 32))
graph.rebuild_from_grid_map()
```

Use `occupied_cells_are_solid = true` when the `GridMap` represents obstacles. Use `occupied_cells_are_solid = false` and `empty_cells_are_solid = true` when the `GridMap` represents walkable cells.

## World-Space Requests

Use the `Pathfinding3D` node if callers should work with world positions instead of cell IDs:

```gdscript
@onready var pathfinder: Pathfinding3D = $Pathfinding3D

func _ready() -> void:
	var graph := GridGraph3D.new()
	graph.cell_size = Vector3.ONE
	graph.set_bounds(Vector3i(0, 0, 0), Vector3i(32, 8, 32))
	pathfinder.graph = graph

func move_to(target_world: Vector3) -> void:
	var path := pathfinder.find_world_path(global_position, target_world)
```

## Custom Graphs

Create a script that extends `PathfindingGraph3D` and implement:

```gdscript
func has_point(point_id: Variant) -> bool
func get_point_position(point_id: Variant) -> Vector3
func get_point_id_from_position(world_position: Vector3) -> Variant
func get_neighbors(point_id: Variant) -> Array
func can_traverse(from_id: Variant, to_id: Variant) -> bool
func get_move_cost(from_id: Variant, to_id: Variant) -> float
func estimate_cost(from_id: Variant, to_id: Variant) -> float
```

The point ID can be any hashable value Godot dictionaries support, such as `Vector3i`, `int`, or `StringName`.

## Smoke Test

If Godot is available from a terminal:

```powershell
godot --headless --script tests/pathfinding_3d_smoke_test.gd
```
