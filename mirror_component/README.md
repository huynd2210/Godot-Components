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
- **T** — toggle the facing-mirror feedback pair
- **Esc** — release or capture the mouse

The room includes an L-shaped blind corner with bright objects behind it, wall-mounted and freestanding stationary mirrors, and two mirrors facing one another. The player uses a bean avatar placed on a reflection-only layer, so the avatar appears in mirrors without blocking the first-person camera.

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
| `reflection_layer` | Per-mirror self-exclusion layer. Leave at `0` for automatic unique assignment. |
| `reflection_extra_cull_mask` | Layers visible only to reflections, useful for a first-person body. |
| `reflect_other_mirrors` | Opt-in, fixed-cost feedback between mirror textures. |
| `near_plane_padding` | Keeps the reflected camera clipping plane just behind the mirror. |
| `reflection_far` | Far clipping distance inside the reflection. |

Planar mirrors render the world once per mirror update. For several mirrors, lower `texture_width` or raise `update_every_n_frames`. Reflective surfaces remain excluded unless `reflect_other_mirrors` is enabled.

## Mirrors facing mirrors

Enable `reflect_other_mirrors` on mirrors that should display other reflective surfaces. Each mirror receives a unique render layer: its reflected camera excludes its own complete object while including the other mirrors. The implementation samples each other mirror's last completed texture, producing a stable facing-mirror tunnel without creating cameras recursively. GPU cost therefore stays bounded at one viewport render per mirror update rather than multiplying by recursion depth.

Leave `reflection_layer` at `0` for automatic allocation. If you assign layers manually, every mirror participating in inter-mirror feedback must use a different layer. Godot provides only 20 render layers, and this component reserves automatic mirror layers from 3 through 20.

This is game-friendly inter-mirror feedback, not an unlimited physically exact ray-traced recursion. It may be one rendered frame behind and very deep reflections become an approximation. Resolution, mirror count, and `update_every_n_frames` remain the main performance controls. The demo pair uses 320-pixel textures and updates every second frame as a conservative example.

## First-person body layers

The demo bean meshes use render layer 2. The main camera excludes that layer while every mirror adds it through `reflection_extra_cull_mask`:

```gdscript
camera.set_cull_mask_value(2, false)
mirror.reflection_extra_cull_mask = 1 << (2 - 1)
```

## Smoke test

```powershell
godot --headless --path . --script tests/mirror_smoke_test.gd
```
