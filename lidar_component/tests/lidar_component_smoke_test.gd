extends SceneTree
## Headless smoke test:
##   godot --headless --path . --script tests/lidar_component_smoke_test.gd

const Lidar := preload("res://addons/lidar_component/lidar_component_3d.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_3d := Node3D.new()
	root.add_child(root_3d)

	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 20.0, 0.25)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	wall.position = Vector3(0.0, 0.0, -5.0)
	root_3d.add_child(wall)

	var scanner := Lidar.new()
	scanner.beams_per_scan = 24
	scanner.max_range = 10.0
	scanner.horizontal_fov_degrees = 12.0
	scanner.vertical_fov_degrees = 12.0
	scanner.max_points = 32
	scanner.show_beams = false
	root_3d.add_child(scanner)

	await physics_frame
	await physics_frame
	var hits := scanner.scan_once()
	if hits <= 0 or scanner.point_count != hits:
		_fail("Expected rays to paint the wall; hits=%d points=%d" % [hits, scanner.point_count])
		return

	# Ring-buffer capacity must stay bounded after repeated scans.
	for i in 4:
		scanner.scan_once()
	if scanner.point_count != 32:
		_fail("Expected point cloud to stop at max_points (32).")
		return

	scanner.clear_points()
	if scanner.point_count != 0:
		_fail("clear_points() should empty the point cloud.")
		return

	# The shipped demo must parse, instantiate, and survive a frame as well.
	root_3d.queue_free()
	var demo_scene: PackedScene = load("res://examples/lidar_demo.tscn")
	if demo_scene == null:
		_fail("Expected the demo scene to load.")
		return
	var demo := demo_scene.instantiate()
	root.add_child(demo)
	for i in 12:
		await physics_frame
	var demo_player = demo.get_node("Player")
	if not demo_player is CharacterBody3D:
		_fail("The demo player should be a CharacterBody3D.")
		return
	if not demo_player.has_node("CollisionShape3D") or demo_player.get_node("CollisionShape3D").shape == null:
		_fail("The demo player should have a collision shape.")
		return
	if not demo_player.is_on_floor():
		_fail("Gravity should settle the demo player on the floor.")
		return
	var floor_collision = demo_player.move_and_collide(Vector3.DOWN * 0.25, true)
	if floor_collision == null:
		_fail("The player capsule should collide with the room floor.")
		return
	var demo_scanner = demo.get_node("Player/Camera3D/LidarGun/LidarComponent3D")
	var press := InputEventAction.new()
	press.action = "scan"
	press.pressed = true
	demo._input(press)
	if not demo_scanner.auto_scan or demo_scanner.point_count <= 0:
		_fail("Holding the scan action should start scanning and paint immediately.")
		return
	var release := InputEventAction.new()
	release.action = "scan"
	release.pressed = false
	demo._input(release)
	if demo_scanner.auto_scan:
		_fail("Releasing the scan action should stop continuous scanning.")
		return
	demo.queue_free()
	await process_frame

	print("LidarComponent3D smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
