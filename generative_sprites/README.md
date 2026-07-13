# Generative Sprites

A small Godot 4 component that procedurally generates pixel-art creature sprites from mirrored noise — with randomized eye styles and features, and optional wiggle animation.

Everything is generated in code (no image assets). Each creature is built as a character grid (the same one-char-per-pixel idea as `.sprite.txt`), mirrored for symmetry, given a dark outline, and tinted from a per-creature palette. The result is returned as `ImageTexture`s you can drop onto a `Sprite2D`, `Sprite3D`, `TextureRect`, or a billboard.

## Files

- `addons/generative_sprites/generative_sprite.gd` - the whole generator (`GenerativeSprite`).
- `examples/sprite_gallery.tscn` - runnable gallery; SPACE re-rolls, creatures animate live.
- `tests/generative_sprite_smoke_test.gd` - headless determinism / output test.

## Quick Start

```gdscript
# A single creature texture:
$Sprite2D.texture = GenerativeSprite.create_texture({ "scale": 6 })

# Full result (animation frames + data):
var creature := GenerativeSprite.create({ "seed": 42, "frames": 2, "scale": 6 })
$Sprite2D.texture = creature.frames[0]        # Array[ImageTexture]
```

`create()` returns a dictionary:

| Key | Type | Meaning |
| --- | --- | --- |
| `frames` | `Array[ImageTexture]` | one texture per animation frame (1 if not animated) |
| `grids` | `Array` | the finalized char grid per frame (see `to_sprite_txt`) |
| `palette` | `Dictionary` | `char -> Color` used for this creature |
| `color` | `Color` | the base body color |
| `size` | `Vector2i` | pixel dimensions of a frame |

## Options

All optional; pass any subset to `create()`.

| Option | Default | Meaning |
| --- | --- | --- |
| `seed` | random | `int` seed; same seed = same creature. `< 0` randomizes. |
| `half_width` | `5` | half the sprite width (full width = `2 * half_width - 1`). |
| `height` | `13` | sprite height in pixels. |
| `scale` | `1` | integer upscale factor (nearest-neighbor). |
| `frames` | `1` | number of animation frames; `> 1` produces a leg/antenna wiggle. |
| `outline` | `true` | add a dark outline around the silhouette. |

## What gets randomized

- **Eye styles** (data-driven list): pair, wide, tall, big, cyclops, trio, beady, angry, stacked — in one of several eye colors.
- **Features** (each probability-gated): mouth / fangs, horns, antennae, accent-color patches, and interior holes.
- **Silhouette**: biased mirrored noise — sparse outer edge (limbs/wings), dense center (a connected spine).
- **Palette**: a random base hue with derived shadow/highlight and a complementary accent.

Add a new eye style by appending one entry to `EYE_STYLES`; add a feature by adding one function to the pipeline in `_apply_features`.

## Animation (wiggle)

Pass `frames: 2` (or more). The head and body stay fixed while the bottom rows (legs/feet) re-roll and any antennae twitch, so cycling the frames reads as a scuttle. Drive it by swapping `frames[i]` on a timer:

```gdscript
var creature := GenerativeSprite.create({ "frames": 2 })
var i := 0
# in a timer / _process tick:
i += 1
$Sprite2D.texture = creature.frames[i % creature.frames.size()]
```

## Export to `.sprite.txt`

The finalized grid can be written out in the hand-authored sprite format:

```gdscript
var creature := GenerativeSprite.create({ "seed": 1 })
var text := GenerativeSprite.to_sprite_txt(creature.grids[0], creature.palette)
```

## Demo Controls

- `SPACE`: re-roll a fresh batch.

Open the project in Godot and run `examples/sprite_gallery.tscn`.

## Smoke Test

If Godot is available from a terminal:

```powershell
godot --headless --script tests/generative_sprite_smoke_test.gd
```
