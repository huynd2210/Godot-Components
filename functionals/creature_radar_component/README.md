# Creature Radar Component

A modular Godot 4 handheld creature radar in which detection is explicitly opt-in. Creatures without a `RadarTarget3D` marker are invisible to radar, and registered creatures can become invisible at runtime. The included first-person demo places a working tracker in the player's hand inside a dark industrial station.

## Install and use

Copy `addons/creature_radar` into a Godot project. Add `CreatureRadar3D` beneath the scanner/player and add `RadarTarget3D` beneath every creature that may be detected. `CreatureRadarDisplay` is an optional reusable phosphor display; assign its `radar` property and place it in a HUD or a `SubViewport` on a physical scanner screen.

```gdscript
@onready var radar: CreatureRadar3D = $CreatureRadar3D
@onready var radar_marker: RadarTarget3D = $Enemy/RadarTarget3D

func activate_cloak() -> void:
	radar_marker.set_radar_invisible(true)

func find_closest_creature() -> Node:
	var contact := radar.get_nearest_contact()
	return contact.get_creature() if contact else null
```

The marker registers itself through a Godot group, so no autoload or central manager is needed. Multiple radars can detect the same set of creatures.

## Demo controls

- **WASD** — move through the station.
- **Mouse** — look around.
- **Shift** — sprint.
- **Tab** — fully raise or lower the handheld tracker.
- **Q** — switch between omnidirectional 360° detection and the 70° forward-cone tracker.
- **Escape** — release or recapture the mouse.

The roaming creatures continue to register through walls, making the physical tracker the primary way to locate danger before entering a room.

## Filtering and API

- `detectable` / `set_radar_invisible()` controls runtime visibility.
- `CreatureConeRadar3D` is a ready-to-use directional variant with a 70° horizontal and 55° vertical forward cone.
- `category` and the radar's `detected_categories` allow radars to detect selected creature types.
- `signature_strength` and `minimum_signature_strength` support weak signatures and upgraded sensors.
- Range, horizontal field of view, vertical field of view, and scan rate are configurable.
- `scan_now()` returns contacts immediately; `auto_scan` refreshes them periodically.
- `contact_entered`, `contact_updated`, `contact_exited`, and `scan_finished` signals keep UI and gameplay decoupled from scanning.
- `contacts`, `has_contact()`, `get_nearest_contact()`, and `clear_contacts()` provide query access.

The scanner reports target markers, not collision bodies. Call `target.get_creature()` to retrieve the marker's parent, or connect signals and map markers to your own creature model.

## Smoke test

```powershell
godot --headless --path . --script tests/creature_radar_smoke_test.gd
```
