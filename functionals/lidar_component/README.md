# LiDAR Component

A self-contained Godot 4 component for “blind world” games: it fires physics rays and paints every hit as a glowing, persistent point. The result is a point-cloud view of otherwise invisible level geometry.

## Features

- Random ray emission across a configurable elliptical cone.
- Persistent world-space hit points rendered efficiently with a bounded `MultiMesh`.
- Visible muzzle-to-surface beams that follow the moving scanner without dragging behind it.
- Wide and focused scan modes for exploration or quickly resolving a small area.
- Configurable point color, point size, collision mask, range, beam count, and scan rate.
- Generated scan and clear sound effects, plus Inspector slots for replacement audio.
- Runnable first-person demo with a visible LiDAR gun, gravity, jumping, and collision.

## Try the demo

Open this folder as a Godot project and run it. The demo room contains only collision geometry, so the LiDAR points are the only way to see it.

- **Hold Click / Space** — continuously scan while held
- **Hold Right Click** — focused scan: narrower cone, denser and faster rays
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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("scan"):
		lidar.scan_once() # Immediate first pulse.
		lidar.auto_scan = true
	if event.is_action_released("scan"):
		lidar.auto_scan = false
	if event.is_action_pressed("clear_scan"):
		lidar.clear_points()
```

The component does not impose an input scheme. The demo maps left-click/Space to the wide scan and right-click to a focused scan by changing the component settings while the button is held.

## Demo scan modes

| Mode | Input | Rays per pulse | Horizontal cone | Vertical cone | Pulse rate |
| --- | --- | ---: | ---: | ---: | ---: |
| Wide | Hold left-click or Space | 100 | 78° | 56° | 12/s |
| Focus | Hold right-click | 300 | 16° | 12° | 18/s |

Releasing focused scan restores the wide settings. Both inputs are tracked independently, so holding wide scan while briefly focusing returns to wide scanning instead of stopping.

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

The included demo uses a `CharacterBody3D` with a capsule collider, strong gravity, and `move_and_slide()`. The status display reports `GROUNDED YES` when the player is standing on collision geometry.

Demo gravity is `23.52 m/s²` (`2.4 ×` the default project gravity), with a jump velocity of `7.0 m/s` for a short, responsive arc.

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
