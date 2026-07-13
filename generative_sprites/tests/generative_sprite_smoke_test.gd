extends SceneTree
## Headless smoke test:
##   godot --headless --script tests/generative_sprite_smoke_test.gd

const Gen := preload("res://addons/generative_sprites/generative_sprite.gd")

func _init() -> void:
	# Same seed -> identical output (deterministic).
	var a := Gen.create({"seed": 7})
	var b := Gen.create({"seed": 7})
	if str(a["grids"]) != str(b["grids"]):
		push_error("Same seed should produce identical grids.")
		quit(1)
		return

	# Different seed -> different output.
	var c := Gen.create({"seed": 8})
	if str(a["grids"]) == str(c["grids"]):
		push_error("Different seeds should produce different grids.")
		quit(1)
		return

	# Texture is valid and non-empty.
	var tex: ImageTexture = a["frames"][0]
	if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0:
		push_error("Expected a non-empty texture.")
		quit(1)
		return

	# Animation returns the requested number of frames, and they differ.
	var anim := Gen.create({"seed": 3, "frames": 3})
	if anim["frames"].size() != 3:
		push_error("Expected 3 animation frames.")
		quit(1)
		return
	if str(anim["grids"][0]) == str(anim["grids"][1]):
		push_error("Animation frames should differ (wiggle).")
		quit(1)
		return

	# .sprite.txt export produces text with the palette header + grid.
	var txt := Gen.to_sprite_txt(a["grids"][0], a["palette"])
	if not txt.begins_with("#") or txt.length() < 50:
		push_error("Expected a .sprite.txt-style export.")
		quit(1)
		return

	print("GenerativeSprite smoke test passed.")
	quit()
