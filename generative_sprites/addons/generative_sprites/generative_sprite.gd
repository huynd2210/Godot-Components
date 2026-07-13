class_name GenerativeSprite
extends RefCounted
## Procedural creature-sprite generator.
##
## Biased mirrored noise + randomized feature variants (eye styles, mouth, horns, antennae,
## accent patches, holes), rendered to crisp pixel-art ImageTextures, with optional
## wiggle-animation frames. Self-contained (no dependencies), deterministic per seed.
##
## Usage:
##     var creature := GenerativeSprite.create({ "seed": 42, "frames": 2, "scale": 6 })
##     $Sprite2D.texture = creature.frames[0]        # Array[ImageTexture]
##     # creature.grids  -> char grids (see to_sprite_txt), creature.color, creature.size
##
## Options (all optional): seed(int, <0 = random), half_width(int), height(int),
## scale(int upscale), frames(int, >1 = wiggle animation), outline(bool).

# ---------------------------------------------------------------------------
# Variant data — adding an eye style / eye color is a data entry, not a branch.
# ---------------------------------------------------------------------------
const EYE_STYLES := [
	{"name": "pair", "cells": [[1, 0]]},
	{"name": "wide", "cells": [[2, 0]]},
	{"name": "tall", "cells": [[1, 0], [1, -1]]},
	{"name": "big", "cells": [[1, 0], [1, -1], [2, 0], [2, -1]]},
	{"name": "cyclops", "cells": [[0, 0], [0, -1]]},
	{"name": "trio", "cells": [[0, 0], [2, 0]]},
	{"name": "beady", "cells": [[1, 0]], "pupil": true},
	{"name": "angry", "cells": [[1, 0]], "brow": true},
	{"name": "stacked", "cells": [[1, 0], [1, -2]]},
]

const EYE_COLORS := [
	Color(1.0, 0.86, 0.25), # yellow
	Color(1.0, 0.32, 0.26), # red
	Color(0.38, 1.0, 0.55), # green
	Color(0.36, 0.86, 1.0), # cyan
	Color(1.0, 1.0, 1.0),   # white
	Color(1.0, 0.48, 0.9),  # pink
]

const DEFAULTS := {
	"seed": -1, "half_width": 5, "height": 13, "scale": 1, "frames": 1, "outline": true,
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
static func create(opts := {}) -> Dictionary:
	var cfg := DEFAULTS.duplicate()
	for k in opts:
		cfg[k] = opts[k]

	var rng := RandomNumberGenerator.new()
	if int(cfg["seed"]) < 0:
		rng.randomize()
	else:
		rng.seed = int(cfg["seed"])

	var hw := int(cfg["half_width"])
	var h := int(cfg["height"])
	var scale := maxi(1, int(cfg["scale"]))
	var nframes := maxi(1, int(cfg["frames"]))
	var outline: bool = cfg["outline"]

	var pal_info := _make_palette(rng)
	var palette: Dictionary = pal_info["palette"]

	var base := _build_base(rng, hw, h)
	var meta := _apply_features(base, rng, hw, h)

	var frames: Array = []
	var grids: Array = []
	for f in nframes:
		var half := _dup_grid(base)
		if nframes > 1:
			_animate(half, rng, hw, h, f, meta)
		var full := _finalize_grid(_mirror(half), outline)
		frames.append(ImageTexture.create_from_image(_grid_to_image(full, palette, scale)))
		grids.append(full)

	var first: ImageTexture = frames[0]
	return {
		"frames": frames,
		"grids": grids,
		"palette": palette,
		"color": pal_info["base"],
		"size": Vector2i(first.get_width(), first.get_height()),
	}

## Convenience: just the first frame's texture.
static func create_texture(opts := {}) -> ImageTexture:
	return create(opts)["frames"][0]

## Export a finalized char grid to the project's `.sprite.txt` format (palette header + grid).
static func to_sprite_txt(grid: Array, palette: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("# Generative creature sprite — one character = one pixel.")
	lines.append("#")
	lines.append("# Palette:")
	lines.append("# . = transparent")
	for key in palette:
		var c: Color = palette[key]
		lines.append("# %s = #%s" % [key, c.to_html(false)])
	lines.append("")
	for row in grid:
		lines.append("".join(row))
	return "\n".join(lines)

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------
static func _make_palette(rng: RandomNumberGenerator) -> Dictionary:
	var hue := rng.randf()
	var base := Color.from_hsv(hue, rng.randf_range(0.55, 0.85), rng.randf_range(0.72, 0.98))
	var acc_hue := fmod(hue + rng.randf_range(0.28, 0.55), 1.0)
	var accent := Color.from_hsv(acc_hue, rng.randf_range(0.5, 0.85), rng.randf_range(0.8, 1.0))
	var eye: Color = EYE_COLORS[rng.randi() % EYE_COLORS.size()]
	var palette := {
		"o": base.darkened(0.78),
		"d": base.darkened(0.42),
		"b": base,
		"h": base.lightened(0.42),
		"a": accent,
		"y": eye,
		"p": eye.darkened(0.62),
		"k": Color(0.04, 0.04, 0.06),
		"w": Color(0.96, 0.96, 1.0),
	}
	return {"palette": palette, "base": base, "accent": accent, "eye": eye}

# ---------------------------------------------------------------------------
# Base silhouette (biased mirrored noise)
# ---------------------------------------------------------------------------
static func _build_base(rng: RandomNumberGenerator, hw: int, h: int) -> Array:
	var g: Array = []
	for y in h:
		var row: Array = []
		for x in hw:
			var p := 0.52
			if x == 0:
				p = 0.30                 # sparse outer edge -> limbs / wings
			elif x == hw - 1:
				p = 0.90                 # dense centre column -> connected spine
			if y == 0 or y == h - 1:
				p *= 0.55                # taper the very top and bottom
			row.append("b" if rng.randf() < p else ".")
		g.append(row)
	return g

# ---------------------------------------------------------------------------
# Feature pipeline (each independent + probability-gated)
# ---------------------------------------------------------------------------
static func _apply_features(g: Array, rng: RandomNumberGenerator, hw: int, h: int) -> Dictionary:
	var meta := {}
	_feat_head_and_eyes(g, rng, hw, h)
	if rng.randf() < 0.55:
		_feat_mouth(g, rng, hw, h)
	if rng.randf() < 0.45:
		_feat_horns(g, rng, hw)
	if rng.randf() < 0.42:
		meta["antennae"] = _feat_antennae(g, hw)
	if rng.randf() < 0.50:
		_feat_accent(g, rng, hw, h)
	if rng.randf() < 0.28:
		_feat_holes(g, rng, hw, h)
	return meta

static func _feat_head_and_eyes(g: Array, rng: RandomNumberGenerator, hw: int, _h: int) -> void:
	var er := 2 + rng.randi() % 3
	# Solid head block so eyes always sit on a face.
	for yy in range(maxi(0, er - 2), er + 2):
		for xx in range(maxi(0, hw - 3), hw):
			if _cell(g, xx, yy) == ".":
				_put(g, xx, yy, "b")
	var style: Dictionary = EYE_STYLES[rng.randi() % EYE_STYLES.size()]
	for cell in style["cells"]:
		var col := hw - 1 - int(cell[0])
		var row := er + int(cell[1])
		_put(g, col, row, "p" if style.get("pupil", false) else "y")
	if style.get("brow", false):
		for xx in range(maxi(0, hw - 3), hw):
			_put(g, xx, er - 1, "d")

static func _feat_mouth(g: Array, rng: RandomNumberGenerator, hw: int, h: int) -> void:
	var mr := clampi(5 + rng.randi() % 3, 3, h - 3)
	for xx in range(maxi(0, hw - 3), hw):
		if _cell(g, xx, mr) != ".":
			_put(g, xx, mr, "k")
	if rng.randf() < 0.5:
		_put(g, hw - 1, mr, "w")
		_put(g, hw - 3, mr, "w")

static func _feat_horns(g: Array, rng: RandomNumberGenerator, hw: int) -> void:
	var col := hw - 2 - (rng.randi() % 2)
	for yy in range(0, 3):
		_put(g, col, yy, "d")

static func _feat_antennae(g: Array, hw: int) -> Dictionary:
	var col := hw - 2
	_put(g, col, 2, "b")
	_put(g, col, 1, "b")
	_put(g, col, 0, "w")
	return {"col": col}

static func _feat_accent(g: Array, rng: RandomNumberGenerator, hw: int, h: int) -> void:
	for y in h:
		for x in hw:
			if _cell(g, x, y) == "b" and rng.randf() < 0.16:
				_put(g, x, y, "a")

static func _feat_holes(g: Array, rng: RandomNumberGenerator, hw: int, h: int) -> void:
	for y in range(4, h - 1):
		for x in range(1, hw):
			if _cell(g, x, y) == "b" and rng.randf() < 0.10:
				_put(g, x, y, ".")

# ---------------------------------------------------------------------------
# Animation: shuffle the leg zone + twitch antennae per frame
# ---------------------------------------------------------------------------
static func _animate(g: Array, rng: RandomNumberGenerator, hw: int, h: int, frame: int, meta: Dictionary) -> void:
	for y in range(h - 2, h):
		for x in range(hw):
			var p := 0.30 if x == 0 else (0.7 if x == hw - 1 else 0.55)
			g[y][x] = "b" if rng.randf() < p else "."
	if meta.has("antennae"):
		var col: int = meta["antennae"]["col"]
		var shift := 1 if frame % 2 == 1 else 0
		_put(g, col, 0, ".")
		_put(g, clampi(col - shift, 0, hw - 1), 0, "w")
		_put(g, col, 1, "b")
		_put(g, col, 2, "b")

# ---------------------------------------------------------------------------
# Grid -> mirror -> outline -> image
# ---------------------------------------------------------------------------
static func _mirror(half: Array) -> Array:
	var full: Array = []
	for row in half:
		var new_row: Array = row.duplicate()
		for i in range(row.size() - 2, -1, -1):
			new_row.append(row[i])
		full.append(new_row)
	return full

## Pad by 1px and add a dark outline in char space, so image + .sprite.txt stay identical.
static func _finalize_grid(full: Array, outline: bool) -> Array:
	var gh := full.size()
	var gw := 0
	for row in full:
		gw = maxi(gw, row.size())
	var pg: Array = []
	for y in gh + 2:
		var r: Array = []
		for x in gw + 2:
			r.append(".")
		pg.append(r)
	for y in gh:
		var row: Array = full[y]
		for x in row.size():
			pg[y + 1][x + 1] = row[x]
	if outline:
		var dirs := [[1, 0], [-1, 0], [0, 1], [0, -1]]
		var pts: Array = []
		var ph := pg.size()
		for y in ph:
			var prow: Array = pg[y]
			var pw := prow.size()
			for x in pw:
				if prow[x] != ".":
					continue
				for d in dirs:
					var nx := x + int(d[0])
					var ny := y + int(d[1])
					if nx >= 0 and nx < pw and ny >= 0 and ny < ph:
						var nrow: Array = pg[ny]
						if nrow[nx] != ".":
							pts.append([x, y])
							break
		for p in pts:
			pg[p[1]][p[0]] = "o"
	return pg

static func _grid_to_image(pg: Array, palette: Dictionary, scale: int) -> Image:
	var h := pg.size()
	var w: int = pg[0].size()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: Array = pg[y]
		for x in row.size():
			var ch: String = row[x]
			if ch != "." and palette.has(ch):
				var col: Color = palette[ch]
				img.set_pixel(x, y, col)
	if scale > 1:
		img.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	return img

# ---------------------------------------------------------------------------
# Small grid helpers
# ---------------------------------------------------------------------------
static func _dup_grid(g: Array) -> Array:
	var out: Array = []
	for row in g:
		out.append(row.duplicate())
	return out

static func _put(g: Array, x: int, y: int, ch: String) -> void:
	if y >= 0 and y < g.size() and x >= 0 and x < g[y].size():
		g[y][x] = ch

static func _cell(g: Array, x: int, y: int) -> String:
	if y >= 0 and y < g.size() and x >= 0 and x < g[y].size():
		return g[y][x]
	return "."
