# LiDAR Component

A self-contained Godot 4 component for “blind world” games: it fires physics rays and paints every hit as a glowing, persistent point. The result is a point-cloud view of otherwise invisible level geometry.

## Try the demo

Open this folder as a Godot project and run it. The demo room contains only collision geometry, so the LiDAR points are the only way to see it.

- **Hold Click / Space** — continuously scan while held
- **WASD** — walk with gravity and collision
- **E** — jump while grounded
- **Mouse** — look
- **C** — erase all painted points
- **Esc** — release/capture the mouse

## Add it to a game

1. Copy `addons/lidar_component` into your project.
2. Add a `Node3D` beneath the player camera.
3. Attach `lidar_component_3d.gd`.
4. Call `$Camera3D/LidarComponent3D.scan_once()` from your input code.

The scanner fires along its local **-Z** axis, matching a Godot camera. Painted points use a bounded `MultiMesh`, remain fixed in world space as the scanner moves, and overwrite the oldest points once `max_points` is reached.

```gdscript
@onready var lidar: LidarComponent3D = $Camera3D/LidarComponent3D

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("scan"):
		var hits := lidar.scan_once()
		print("Painted ", hits, " surfaces")
	if event.is_action_pressed("clear_scan"):
		lidar.clear_points()
```

If the scanner is inside a physics-based player, exclude that body so rays do not immediately hit it:

```gdscript
func _ready() -> void:
	lidar.add_exclusion($CharacterBody3D)
```

## Main settings

| Setting | Purpose |
| --- | --- |
| `beams_per_scan` | Rays emitted by each pulse. |
| `max_range` | Maximum ray distance. |
| `horizontal_fov_degrees` / `vertical_fov_degrees` | Rectangular scan field of view. |
| `auto_scan` / `scans_per_second` | Optional continuous scanner. |
| `max_points` | Fixed point-cloud memory budget. |
| `point_size`, `point_color` | Size and chosen color of each painted hit. |
| `show_beams`, `beam_lifetime`, `beam_color` | Brief visible ray trails. |
| `collision_mask` | Which physics layers can be painted. |
| `sound_enabled`, `scan_sound`, `clear_sound` | Generated defaults or your own replacement audio streams. |

Every emission scatters fresh random rays across an elliptical cone. Holding the scan bind gradually fills in a sparse LiDAR image of the surrounding collision geometry.

The included demo uses a `CharacterBody3D` with a capsule collider, project gravity, and `move_and_slide()`. The status display reports `GROUNDED YES` when the player is standing on collision geometry.

## Signal/API reference

- `scan_finished(hits, rays)` — emitted after each pulse.
- `scan_once() -> int` — fire immediately and return hit count.
- `clear_points()` — erase the point cloud.
- `add_exclusion(body)` / `remove_exclusion(body)` — manage ignored collision objects.
- `point_count` — current number of visible points.

## Smoke test

```powershell
godot --headless --path . --script tests/lidar_component_smoke_test.gd
```
