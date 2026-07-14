extends SceneTree
## Headless smoke test:
##   godot --headless --path . --script tests/polaroid_camera_smoke_test.gd

const PolaroidCamera := preload("res://addons/polaroid_camera/polaroid_camera_3d.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	if DisplayServer.get_name() != "headless":
		var subject := MeshInstance3D.new()
		var subject_mesh := BoxMesh.new()
		subject_mesh.size = Vector3(2.0, 2.0, 0.5)
		var subject_material := StandardMaterial3D.new()
		subject_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		subject_material.albedo_color = Color(0.9, 0.05, 0.02, 1.0)
		subject_mesh.material = subject_material
		subject.mesh = subject_mesh
		subject.position = Vector3(0.0, 0.0, -3.0)
		world.add_child(subject)
	var camera := Camera3D.new()
	camera.current = true
	world.add_child(camera)
	var polaroid := PolaroidCamera.new()
	polaroid.capture_size = Vector2i(96, 64)
	polaroid.cooldown_seconds = 0.0
	polaroid.flash_enabled = false
	camera.add_child(polaroid)

	await process_frame
	if not polaroid.can_take_picture():
		_fail("A PolaroidCamera3D below a Camera3D should be ready.")
		return
	# Godot's headless display driver uses a dummy renderer and cannot return
	# viewport pixels. Exercise the real capture path whenever a renderer exists.
	if DisplayServer.get_name() != "headless":
		var picture: Image = await polaroid.take_picture()
		if picture == null or picture.is_empty():
			_fail("take_picture() should return a rendered Image.")
			return
		if picture.get_size() != Vector2i(96, 64):
			_fail("The rendered image should match capture_size.")
			return
		var center_pixel := picture.get_pixel(48, 32)
		if center_pixel.r < 0.6 or center_pixel.r <= center_pixel.g * 2.0:
			_fail("The photo should contain the red test subject at its center.")
			return
		if polaroid.latest_texture == null:
			_fail("The latest photo should also be exposed as an ImageTexture.")
			return
	else:
		if polaroid.get_node_or_null("PolaroidCaptureViewport") == null:
			_fail("The component should create its private capture viewport.")
			return

	var demo_scene: PackedScene = load("res://examples/polaroid_camera_demo.tscn")
	if demo_scene == null:
		_fail("The demo scene should parse and load.")
		return
	if DisplayServer.get_name() != "headless":
		var demo := demo_scene.instantiate()
		root.add_child(demo)
		await process_frame
		if not demo.has_node("Player/Camera3D/PolaroidCamera3D"):
			_fail("The demo should contain the reusable camera component.")
			return

	print("PolaroidCamera3D smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
