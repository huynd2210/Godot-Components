# Echolocation Component

A reusable Godot 4 component for games where the player sees by emitting sound. Each echo samples the physics world and reveals only silhouettes, corners, object boundaries, and strong depth changes. Flat surfaces remain dark.

## Demo controls

- **Left click** - emit one echo
- **WASD** - walk
- **E** - jump
- **Mouse** - look
- **C** - clear the current echo
- **Esc** - release/capture the mouse

## How contour detection works

The demo uses a complete 360-degree sphere scan. `EcholocationComponent3D` distributes rays evenly over six cube faces, avoiding the squeezed poles and reduced detail of a latitude/longitude grid. Revealed points are stored in world space, so turning around after an echo shows contours that were detected behind the player. Neighboring samples are classified as an outline when they differ by:

- hit versus miss;
- collider identity;
- depth beyond `depth_edge_threshold`; or
- surface normal beyond `normal_edge_angle_degrees`.

Only those contour samples are rendered. They appear when the expanding pulse reaches their world-space distance, remain visible for `outline_hold_time`, then fade.

The visible sonic wave expands from the emitter at exactly `propagation_speed`, so contours are revealed as the wave reaches them. It is rendered only at physics-hit samples within a thin moving distance band. This creates bright rings that sweep across actual surfaces without placing a globe over the camera.

## Add it to a project

1. Copy `addons/echolocation_component` into the project.
2. Add a `Node3D` below the player camera.
3. Attach `echolocation_component_3d.gd`.
4. Bind an input action and call `emit_echo()`.

```gdscript
@onready var echo: EcholocationComponent3D = $Camera3D/EcholocationComponent3D

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("echo"):
		echo.emit_echo()
```

Exclude the player collision body so the pulse starts outside it:

```gdscript
func _ready() -> void:
	echo.add_exclusion($CharacterBody3D)
```

The component detects `CollisionObject3D` geometry. The demo uses a `CharacterBody3D` capsule for the player and `StaticBody3D` collision shapes for its floor, ceiling, walls, pillars, and archway. In another project, ensure level geometry has matching physics shapes and belongs to a layer included in `collision_mask`.

The demo also includes a large cliff/mesa test structure based on the supplied sketch: a player-scale overhang, tall vertical mass, broad upper surface, and convex sloped buttress. All parts use physics shapes, so both player collision and echolocation respond to the complete silhouette.

## Main settings

| Setting | Purpose |
| --- | --- |
| `scan_shape` | `CONE` scans forward through the configured field of view; `SPHERE` scans the full 360-degree world. |
| `grid_width`, `grid_height` | Forward-cone ray resolution when integrating the optional cone mode elsewhere. |
| `sphere_face_resolution` | Resolution of each of the six 360-degree scan faces. The demo uses 96, matching the earlier cone’s crisp angular detail. |
| `sphere_face_overlap_degrees` | Slight face overlap prevents missing contours at the six sphere-scan seams. Overlapping dots are merged automatically. |
| `horizontal_fov_degrees`, `vertical_fov_degrees` | Echo view cone; ignored in sphere mode. |
| `max_range` | Maximum detectable distance. |
| `depth_edge_threshold` | Minimum neighboring depth jump considered an outline. |
| `relative_depth_edge_threshold` | Required proportional depth jump; prevents perspective gradients on flat planes from becoming bands. |
| `normal_edge_angle_degrees` | Minimum surface-angle change considered a corner. |
| `propagation_speed` | Speed of the visible echo wave. |
| `outline_hold_time`, `fade_duration` | How long revealed contours remain readable. |
| `point_size`, `echo_color` | Contour appearance. |
| `show_pulse_shell` | Enables the visible expanding sonic wave. |
| `pulse_shell_opacity`, `pulse_shell_thickness`, `pulse_point_size` | Appearance of the surface-hugging wavefront. |
| `collision_mask` | Physics layers detectable by the echo. |
| `echo_sound` | Optional replacement sound; otherwise a ping is generated in code. |

## API

- `emit_echo() -> int` - scan and begin one pulse; returns detected contour count.
- `clear_echo()` - cancel the pulse and remove visible contours.
- `add_exclusion(body)` / `remove_exclusion(body)` - ignore collision objects.
- `outline_point_count` - contour samples currently revealed.
- `detected_edge_count` - total samples detected by the current echo.
- `is_echo_active` / `pulse_radius` - runtime status.
- `wavefront_point_count` - surface samples currently forming the moving wavefront.
- `echo_emitted(edges)`, `echo_finished`, `echo_cleared` - lifecycle signals.

## Smoke test

```powershell
godot --headless --path . --script tests/echolocation_component_smoke_test.gd
```
