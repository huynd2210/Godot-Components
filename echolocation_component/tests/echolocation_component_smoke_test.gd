extends SceneTree
## Headless smoke test:
##   godot --headless --path . --script tests/echolocation_component_smoke_test.gd

const Echo := preload("res://addons/echolocation_component/echolocation_component_3d.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_3d := Node3D.new()
	root.add_child(root_3d)
	var target := StaticBody3D.new()
	target.position = Vector3(0, 0, -5)
	var target_collision := CollisionShape3D.new()
	var target_shape := BoxShape3D.new()
	target_shape.size = Vector3(3, 3, 1)
	target_collision.shape = target_shape
	target.add_child(target_collision)
	root_3d.add_child(target)

	var echo := Echo.new()
	echo.grid_width = 32
	echo.grid_height = 20
	echo.sphere_face_resolution = 24
	echo.scan_shape = Echo.ScanShape.CONE
	echo.horizontal_fov_degrees = 64.0
	echo.vertical_fov_degrees = 44.0
	echo.max_range = 10.0
	echo.propagation_speed = 1000.0
	echo.outline_hold_time = 10.0
	echo.show_pulse_shell = false
	echo.sound_enabled = false
	root_3d.add_child(echo)
	await physics_frame
	await physics_frame

	var edges := echo.emit_echo()
	if edges <= 0 or echo.detected_edge_count != edges:
		_fail("Expected the box silhouette to produce contour samples.")
		return
	echo._process(0.01)
	if echo.outline_point_count <= 0:
		_fail("Expected the expanding echo to reveal contour points.")
		return
	echo.clear_echo()
	if echo.outline_point_count != 0 or echo.is_echo_active:
		_fail("clear_echo() should remove contours and stop the pulse.")
		return

	# Advance a slow pulse until it reaches the front target. The wavefront must
	# be made from surface hits, not a camera-centered globe mesh.
	echo.show_pulse_shell = true
	echo.propagation_speed = 1.0
	echo.emit_echo()
	echo._process(5.0)
	if echo.wavefront_point_count <= 0:
		_fail("Expected the sonic wavefront to sweep across collision surfaces.")
		return
	echo.clear_echo()

	# Move the only target behind the component. A sphere scan must still find it,
	# which verifies this is genuinely omnidirectional rather than a wider cone.
	target.position = Vector3(0, 0, 5)
	await physics_frame
	echo.propagation_speed = 1000.0
	echo.scan_shape = Echo.ScanShape.SPHERE
	var sphere_edges := echo.emit_echo()
	if sphere_edges <= 0 or echo.detected_edge_count != sphere_edges:
		_fail("Expected sphere scanning to detect contours in every direction.")
		return
	echo._process(0.02)
	var rear_outline_count := echo.outline_point_count
	if rear_outline_count <= 0:
		_fail("Expected rear-facing sphere contours to be revealed.")
		return
	echo.rotate_y(PI)
	echo._process(0.0)
	if echo.outline_point_count != rear_outline_count:
		_fail("World-space contours should remain visible after turning around.")
		return
	echo.clear_echo()

	root_3d.queue_free()
	var demo_scene: PackedScene = load("res://examples/echolocation_demo.tscn")
	if demo_scene == null:
		_fail("Expected the demo scene to load.")
		return
	var demo := demo_scene.instantiate()
	root.add_child(demo)
	var demo_echo = demo.get_node("Player/Camera3D/EcholocationComponent3D")
	if demo_echo.scan_shape != Echo.ScanShape.SPHERE or demo_echo.sphere_face_resolution < 96:
		_fail("The demo should use the high-detail 360-degree outline scan.")
		return
	demo_echo.sound_enabled = false
	if demo_echo.emit_echo() <= 0:
		_fail("The full-resolution demo scan should detect room contours.")
		return
	var low_ceiling = demo.get_node("Room/LowCeilingFront")
	var high_ceiling = demo.get_node("Room/HighCeilingMiddle")
	var back_ceiling = demo.get_node("Room/MidCeilingBack")
	if high_ceiling.position.y < 10.0 or low_ceiling.position.y == back_ceiling.position.y:
		_fail("Expected a taller room with varied ceiling heights.")
		return
	var mesa_mass = demo.get_node("CliffMesa/MainUpperMass")
	var mesa_overhang = demo.get_node("CliffMesa/LeftOverhang")
	var mesa_slope = demo.get_node("CliffMesa/SlopedButtress")
	if mesa_mass.position.y < 6.0 or mesa_overhang.position.y < 3.0:
		_fail("Expected the cliff structure to tower above the player with an overhang.")
		return
	if not mesa_slope.shape is ConvexPolygonShape3D:
		_fail("Expected the cliff structure to have a collidable sloped buttress.")
		return
	for i in 12:
		await physics_frame
	var player = demo.get_node("Player")
	if not player is CharacterBody3D or not player.is_on_floor():
		_fail("The demo player should settle on collision geometry.")
		return
	# The front boundary is centered at z=8. A large motion must collide rather
	# than allowing the capsule to leave the room.
	player.position = Vector3(0, 0.05, 6.5)
	await physics_frame
	var wall_collision = player.move_and_collide(Vector3(0, 0, 4.0), true)
	if wall_collision == null:
		_fail("Expected the player capsule to collide with the room wall.")
		return
	demo_echo.clear_echo()
	demo.queue_free()
	await process_frame
	print("EcholocationComponent3D smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
