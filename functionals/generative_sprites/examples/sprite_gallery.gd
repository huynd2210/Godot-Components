extends Control
## Standalone visual demo for GenerativeSprite. SPACE = re-roll a fresh batch.
## Top strip shows each creature's two animation frames side by side; the gallery below
## animates them live.
##
## In your own project, call the global class directly:  GenerativeSprite.create({...})
## This demo preloads the script so it runs headless without an editor import pass.

const Gen := preload("res://addons/generative_sprites/generative_sprite.gd")

const GALLERY_COLS := 10
const GALLERY_ROWS := 4
const CELL := Vector2(96, 108)
const STRIP_COUNT := 5
const ANIM_FPS := 5.0

var _cells: Array = []      # each: { rect: TextureRect, frames: Array }
var _grid: GridContainer
var _strip: HBoxContainer
var _phase := 0
var _accum := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	size = get_viewport_rect().size
	_build_ui()
	_regenerate()

func _process(delta: float) -> void:
	_accum += delta
	if _accum < 1.0 / ANIM_FPS:
		return
	_accum = 0.0
	_phase += 1
	for cell in _cells:
		var frames: Array = cell["frames"]
		cell["rect"].texture = frames[_phase % frames.size()]

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 26)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	margin.add_child(v)

	v.add_child(_label("GENERATIVE SPRITES  ·  eye variants · features · wiggle", 24, Color(0.95, 0.95, 1.0)))
	v.add_child(_label("SPACE = re-roll.  Top row shows each creature's two animation frames (A | B).", 14, Color(0.70, 0.72, 0.82)))
	v.add_child(_spacer(8))

	v.add_child(_label("WIGGLE FRAMES", 13, Color(0.55, 0.85, 1.0)))
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 26)
	v.add_child(_strip)
	v.add_child(_spacer(12))

	v.add_child(_label("GALLERY (animating live)", 13, Color(0.55, 0.85, 1.0)))
	_grid = GridContainer.new()
	_grid.columns = GALLERY_COLS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	v.add_child(_grid)

func _regenerate() -> void:
	_phase = 0
	for c in _grid.get_children():
		c.queue_free()
	for c in _strip.get_children():
		c.queue_free()
	_cells.clear()

	for i in STRIP_COUNT:
		var cr := Gen.create({"frames": 2})
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.add_child(_rect(cr["frames"][0], Vector2(66, 84)))
		box.add_child(_rect(cr["frames"][1], Vector2(66, 84)))
		_strip.add_child(box)

	for i in GALLERY_COLS * GALLERY_ROWS:
		var cr := Gen.create({"frames": 2})
		var rect := _rect(cr["frames"][0], CELL)
		_grid.add_child(rect)
		_cells.append({"rect": rect, "frames": cr["frames"]})

func _rect(tex: Texture2D, cell: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = cell
	return r

func _label(text: String, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l

func _spacer(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_regenerate()
