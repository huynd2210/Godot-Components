extends SceneTree
## Headless smoke test:
##   godot --headless --path . --script tests/mirror_smoke_test.gd

const MirrorScript := preload("res://addons/mirror_3d/mirror_3d.gd")
const HandheldScript := preload("res://addons/mirror_3d/handheld_mirror_3d.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.0, 3.0)
	camera.current = true
	world.add_child(camera)

	var mirror: Mirror3D = MirrorScript.new()
	mirror.source_camera = camera
	mirror.mirror_size = Vector2(1.0, 2.0)
	mirror.texture_width = 128
	world.add_child(mirror)
	await process_frame

	if mirror.reflection_viewport == null or mirror.reflected_camera == null:
		_fail("Mirror3D should create a reflection viewport and camera.")
		return
	if mirror.reflection_viewport.size != Vector2i(128, 256):
		_fail("The reflection viewport should follow mirror aspect ratio.")
		return
	var reflected := mirror.reflect_point(Vector3(0.0, 1.0, 3.0))
	var source_distance := mirror.get_mirror_plane().distance_to(Vector3(0.0, 1.0, 3.0))
	var reflected_distance := mirror.get_mirror_plane().distance_to(reflected)
	if not is_equal_approx(source_distance, -reflected_distance):
		_fail("reflect_point() should reflect points across the glass face plane.")
		return
	mirror.update_reflection()
	if not mirror.reflected_camera.global_position.is_equal_approx(reflected):
		_fail("The internal camera should occupy the reflected source position.")
		return
	var own_mirror_layer := mirror.get_assigned_reflection_layer()
	if mirror.reflected_camera.get_cull_mask_value(own_mirror_layer):
		_fail("A reflection camera must always exclude its own complete mirror object.")
		return
	mirror.reflection_extra_cull_mask = 1 << 1
	var other_mirror: Mirror3D = MirrorScript.new()
	other_mirror.source_camera = camera
	other_mirror.position = Vector3(2.0, 0.0, 0.0)
	world.add_child(other_mirror)
	await process_frame
	var other_mirror_layer := other_mirror.get_assigned_reflection_layer()
	if other_mirror_layer == own_mirror_layer:
		_fail("Auto-assigned mirrors should receive unique self-exclusion layers.")
		return
	mirror.reflect_other_mirrors = true
	mirror.update_reflection()
	if not mirror.reflected_camera.get_cull_mask_value(2):
		_fail("Reflection-only objects should be added through reflection_extra_cull_mask.")
		return
	if not mirror.reflected_camera.get_cull_mask_value(other_mirror_layer):
		_fail("reflect_other_mirrors should include other reflective surfaces.")
		return
	if mirror.reflected_camera.get_cull_mask_value(own_mirror_layer):
		_fail("Enabling inter-mirror feedback must never reveal the mirror itself.")
		return

	var handheld: HandheldMirror3D = HandheldScript.new()
	camera.add_child(handheld)
	await process_frame
	handheld.set_tilt_degrees(Vector2(999.0, -999.0))
	if handheld.get_target_tilt_degrees() != Vector2(handheld.tilt_limits_degrees.x, -handheld.tilt_limits_degrees.y):
		_fail("Handheld tilt should respect its exported limits.")
		return
	handheld.set_corner_extension(4.0)
	if handheld.get_target_corner_extension() != 1.0:
		_fail("Corner extension should clamp to the public -1..1 range.")
		return
	handheld.reset_pose()
	if handheld.get_target_tilt_degrees() != Vector2.ZERO or handheld.get_target_corner_extension() != 0.0:
		_fail("reset_pose() should restore the resting targets.")
		return

	var mirror_scene: PackedScene = load("res://addons/mirror_3d/mirror_3d.tscn")
	var handheld_scene: PackedScene = load("res://addons/mirror_3d/handheld_mirror_3d.tscn")
	var demo_scene: PackedScene = load("res://examples/mirror_demo.tscn")
	if mirror_scene == null or handheld_scene == null or demo_scene == null:
		_fail("The reusable scenes and demo should all parse and load.")
		return
	var demo := demo_scene.instantiate()
	root.add_child(demo)
	await process_frame
	if demo.get_node_or_null("Player/Camera3D/HandheldMirror3D") == null:
		_fail("The demo should contain a first-person handheld mirror.")
		return
	if demo.get_node_or_null("Player/BeanPlayerModel") == null:
		_fail("The demo player should contain the reflection-only bean model.")
		return
	var demo_camera := demo.get_node("Player/Camera3D") as Camera3D
	var bean_body := demo.get_node("Player/BeanPlayerModel/Body") as MeshInstance3D
	var demo_handheld := demo.get_node("Player/Camera3D/HandheldMirror3D") as HandheldMirror3D
	if demo_camera.get_cull_mask_value(2) or not bean_body.get_layer_mask_value(2):
		_fail("The bean should be hidden from the first-person camera on layer 2.")
		return
	if not demo_handheld.reflected_camera.get_cull_mask_value(2):
		_fail("The handheld reflection camera should add the bean layer back.")
		return
	if demo.get_node_or_null("WallMirror") == null or demo.get_node_or_null("StandingMirror") == null:
		_fail("The demo should contain reusable stationary mirrors.")
		return
	if demo.get_node_or_null("FacingMirrorLeft") == null or demo.get_node_or_null("FacingMirrorRight") == null:
		_fail("The demo should contain the facing mirror feedback pair.")
		return
	var facing_left := demo.get_node("FacingMirrorLeft") as Mirror3D
	var facing_right := demo.get_node("FacingMirrorRight") as Mirror3D
	if not facing_left.reflect_other_mirrors:
		_fail("The demo facing pair should start with inter-mirror feedback enabled.")
		return
	if facing_left.get_assigned_reflection_layer() == facing_right.get_assigned_reflection_layer():
		_fail("Facing mirrors must have different self-exclusion layers.")
		return
	if facing_left.reflected_camera.get_cull_mask_value(facing_left.get_assigned_reflection_layer()):
		_fail("The left facing mirror should not see itself.")
		return
	if not facing_left.reflected_camera.get_cull_mask_value(facing_right.get_assigned_reflection_layer()):
		_fail("The left facing mirror should see the right facing mirror.")
		return

	print("Mirror3D smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
