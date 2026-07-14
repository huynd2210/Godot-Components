# Mirror 3D Component

A modular Godot 4 planar mirror with two ready-to-use variants:

- `Mirror3D` is a stationary world mirror with a configurable frame, size, resolution, and source camera.
- `HandheldMirror3D` adds smooth tilt and left/right corner-extension controls without assuming your input map.

Both use the same private `SubViewport` reflection camera. Mirror presentation geometry lives on a configurable render layer that reflection cameras exclude, preventing self-occlusion and mirror-within-mirror recursion.

## Try the first-person demo

Open this folder as a Godot project and run it.

- **WASD** — walk
- **Space** — jump
- **Mouse** — look
- **Hold right mouse + Mouse** — tilt the handheld mirror
- **Hold Q / E** — reach the mirror left / right around a corner
- **R** — reset the handheld pose
- **F** — hide or show the handheld mirror
- **Esc** — release or capture the mouse

The room includes an L-shaped blind corner with bright objects behind it, plus wall-mounted and freestanding stationary mirrors.

## Add a stationary mirror

1. Copy `addons/mirror_3d` into your Godot project.
2. Instantiate `mirror_3d.tscn` anywhere in a 3D scene.
3. Rotate the node so its local **+Z axis** points out of the reflective face.
4. Leave `source_camera` empty to use the active camera, or assign a specific `Camera3D`.

The scene builds its frame and reflective surface automatically. `mirror_size`, `frame_width`, `frame_color`, `texture_width`, and refresh rate are available in the Inspector.

## Add a handheld mirror

Parent `handheld_mirror_3d.tscn` to the first-person `Camera3D`, then feed it input:

```gdscript
@onready var hand_mirror: HandheldMirror3D = $Camera3D/HandheldMirror3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("mirror_control"):
		hand_mirror.add_tilt_input(event.relative * 0.16)

func _process(_delta: float) -> void:
	var reach := Input.get_axis("mirror_left", "mirror_right")
	hand_mirror.set_corner_extension(reach)
```

`set_tilt_degrees()`, `set_corner_extension()`, and `reset_pose()` are also public. The corner value is analog: `-1` is fully left, `0` rests, and `1` is fully right.

## Reflection settings

| Setting | Purpose |
| --- | --- |
| `source_camera` | Camera being reflected; defaults to the active viewport camera. |
| `texture_width` | Reflection width; height follows the physical mirror aspect ratio. |
| `update_every_n_frames` | Render every frame or trade smoothness for performance. |
| `reflection_layer` | Layer used by mirror presentation geometry and excluded from reflected views. |
| `near_plane_padding` | Keeps the reflected camera clipping plane just behind the mirror. |
| `reflection_far` | Far clipping distance inside the reflection. |

Planar mirrors render the world once per mirror update. For several mirrors, lower `texture_width` or raise `update_every_n_frames`. Objects on the selected reflection layer will not appear in mirrors.

## Smoke test

```powershell
godot --headless --path . --script tests/mirror_smoke_test.gd
```
