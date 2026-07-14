# Polaroid Camera Component

A self-contained Godot 4 component that lets any `Camera3D` take a still picture. It renders the same 3D view into a private `SubViewport`, returns both an `Image` and an `ImageTexture`, can save PNG files, and includes shutter/flash feedback.

## Try the demo

Open this folder as a Godot project and run it.

- **Left click / Space** — take a picture
- **WASD** — walk around the gallery
- **Mouse** — look
- **Esc** — release or capture the mouse

The photo appears as an instant-film card and develops over a couple of seconds.

## Add it to a game

1. Copy `addons/polaroid_camera` into your Godot project.
2. Add a `Node3D` below the `Camera3D` that should take pictures.
3. Attach `polaroid_camera_3d.gd` to that node.
4. Await `take_picture()` when the player presses the shutter.

```gdscript
@onready var polaroid: PolaroidCamera3D = $Camera3D/PolaroidCamera3D

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("take_picture") and polaroid.can_take_picture():
		var image: Image = await polaroid.take_picture()
		if image != null:
			$UI/Photo.texture = polaroid.latest_texture
```

The component automatically finds a parent `Camera3D`. For a camera elsewhere in the scene, assign `source_camera` in the Inspector.

## Saving photos

Enable `save_to_disk` to write every picture to `user://polaroids`, or pass a path for a single capture:

```gdscript
var image := await polaroid.take_picture("user://album/first_photo.png")
print(polaroid.latest_file_path)
```

Directories are created automatically. PNG is used so the stored image exactly matches the captured texture.

## Main settings

| Setting | Purpose |
| --- | --- |
| `source_camera` | Camera to copy; optional when this node is below a camera. |
| `capture_size` | Width and height of the resulting photo. |
| `cooldown_seconds` | Minimum delay between pictures. |
| `save_to_disk` | Automatically save every capture as PNG. |
| `save_directory` / `file_prefix` | Output location and filename prefix. |
| `flash_enabled`, `flash_strength`, `flash_duration` | Full-screen shutter flash. |
| `shutter_sound`, `shutter_volume_db` | Optional replacement sound and volume. |

The capture camera copies the source camera's transform, projection, FOV, clipping planes, offsets, cull mask, camera attributes, and environment immediately before each photo.

## Signals and API

- `await take_picture(path := "") -> Image` — take one picture.
- `can_take_picture() -> bool` — test camera, capture, and cooldown state.
- `clear_picture()` — release the latest in-memory image and texture.
- `capture_started` — emitted when the shutter begins.
- `picture_taken(image, texture, file_path)` — emitted when the photo is ready.
- `capture_failed(reason)` — emitted when a capture cannot finish.
- `latest_image`, `latest_texture`, `latest_file_path` — most recent result.

The component only captures the 3D world. Your game's normal HUD is not included in the picture.

## Smoke test

```powershell
godot --headless --path . --script tests/polaroid_camera_smoke_test.gd
```
