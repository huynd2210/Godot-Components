# Modular Pathfinding 2D

A small Godot 4 component for modular A* pathfinding in 2D projects.

The solver is separate from the graph, so you can use the included grid graph or create a graph for rooms, waypoints, tile data, procedural terrain, or anything else that can return neighbors and movement costs.

## Files

- `addons/modular_pathfinding_2d/modular_astar_2d.gd` - pure A* solver.
- `addons/modular_pathfinding_2d/pathfinding_graph_2d.gd` - base graph contract.
- `addons/modular_pathfinding_2d/grid_graph_2d.gd` - reusable `Vector2i` grid graph.
- `addons/modular_pathfinding_2d/tile_map_grid_graph_2d.gd` - optional TileMap or TileMapLayer-backed grid graph.
- `addons/modular_pathfinding_2d/pathfinding_2d.gd` - optional node wrapper for world-space path requests.
- `examples/grid_pathfinding_demo.tscn` - runnable click-to-path demo.

## Quick Start

```gdscript
var graph := GridGraph2D.new()
graph.cell_size = Vector2(16, 16)
graph.set_bounds(Rect2i(Vector2i.ZERO, Vector2i(80, 45)))
graph.diagonal_mode = GridGraph2D.DiagonalMode.NO_CORNER_CUTTING
graph.heuristic = GridGraph2D.Heuristic.OCTILE

graph.set_solid(Vector2i(10, 12), true)
graph.set_weight(Vector2i(11, 12), 3.0)

var astar := ModularAStar2D.new()
var path := astar.find_path(graph, Vector2i(0, 0), Vector2i(20, 15))
```

`path` is a `PackedVector2Array` of world positions centered inside each grid cell.

## TileMap Graphs

`TileMapGridGraph2D` can rebuild solids and terrain costs from tile custom data:

```gdscript
var graph := TileMapGridGraph2D.new()
graph.tile_source = $TileMap
graph.tilemap_layer = 0
graph.solid_custom_data_key = "solid"
graph.weight_custom_data_key = "weight"
graph.rebuild_from_tile_source()
```

Set a tile's `solid` custom data to `true` to block it. Set `weight` to a number greater than `1.0` for slower terrain.

## World-Space Requests

Use the `Pathfinding2D` node if callers should work with world positions instead of cell IDs:

```gdscript
@onready var pathfinder: Pathfinding2D = $Pathfinding2D

func _ready() -> void:
	var graph := GridGraph2D.new()
	graph.cell_size = Vector2(16, 16)
	graph.set_bounds(Rect2i(Vector2i.ZERO, Vector2i(80, 45)))
	pathfinder.graph = graph

func move_to(target_world: Vector2) -> void:
	var path := pathfinder.find_world_path(global_position, target_world)
```

## Custom Graphs

Create a script that extends `PathfindingGraph2D` and implement:

```gdscript
func has_point(point_id: Variant) -> bool
func get_point_position(point_id: Variant) -> Vector2
func get_point_id_from_position(world_position: Vector2) -> Variant
func get_neighbors(point_id: Variant) -> Array
func can_traverse(from_id: Variant, to_id: Variant) -> bool
func get_move_cost(from_id: Variant, to_id: Variant) -> float
func estimate_cost(from_id: Variant, to_id: Variant) -> float
```

The point ID can be any hashable value Godot dictionaries support, such as `Vector2i`, `int`, or `StringName`.

## Demo Controls

- Left click: move the goal.
- Right click: toggle a wall.

Open the project in Godot and run `examples/grid_pathfinding_demo.tscn`.

## Smoke Test

If Godot is available from a terminal:

```powershell
godot --headless --script tests/pathfinding_smoke_test.gd
```
