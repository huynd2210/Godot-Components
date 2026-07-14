extends SceneTree

const Radar := preload("res://addons/creature_radar/creature_radar_3d.gd")
const ConeRadar := preload("res://addons/creature_radar/creature_cone_radar_3d.gd")
const Target := preload("res://addons/creature_radar/radar_target_3d.gd")
const RadarDisplay := preload("res://addons/creature_radar/creature_radar_display.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var radar := Radar.new()
	radar.auto_scan = false
	radar.detection_range = 10.0
	world.add_child(radar)
	var near := _target_at(world, Vector3(0, 0, -5), &"near")
	var far := _target_at(world, Vector3(0, 0, -20), &"far")
	var hidden := _target_at(world, Vector3(2, 0, -5), &"hidden")
	hidden.detectable = false
	await process_frame

	var found := radar.scan_now()
	if found.size() != 1 or found[0] != near or radar.get_nearest_contact() != near:
		return _fail("Only the registered, visible, in-range creature should be detected.")
	hidden.detectable = true
	if radar.scan_now().size() != 2:
		return _fail("A creature should appear after detectability is enabled.")
	near.set_radar_invisible(true)
	if radar.scan_now().has(near):
		return _fail("set_radar_invisible(true) should remove a creature on the next scan.")
	far.position = Vector3(0, 0, -3)
	if not radar.scan_now().has(far):
		return _fail("Moving a target into range should make it detectable.")
	var display := RadarDisplay.new()
	display.size = Vector2(320, 260)
	display.set_radar(radar)
	root.add_child(display)
	await process_frame
	if display.radar != radar:
		return _fail("The reusable radar display should accept a radar instance.")
	var behind := _target_at(world, Vector3(0, 0, 4), &"behind")
	var cone_radar := ConeRadar.new()
	cone_radar.auto_scan = false
	cone_radar.detection_range = 10.0
	world.add_child(cone_radar)
	await process_frame
	var cone_contacts := cone_radar.scan_now()
	if not cone_contacts.has(far) or cone_contacts.has(behind):
		return _fail("The cone radar should detect forward targets and reject targets behind it.")
	world.queue_free()
	display.queue_free()
	await process_frame
	var demo_scene: PackedScene = load("res://examples/creature_radar_demo.tscn")
	var demo := demo_scene.instantiate()
	root.add_child(demo)
	await physics_frame
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	demo._unhandled_input(tab)
	for frame in 24:
		await physics_frame
	if demo.tracker_is_raised or demo.tracker.visible or demo.tracker.position.y > -1.0:
		return _fail("Tab should fully lower and hide the handheld tracker.")
	var previous_radar = demo.radar
	demo.switch_radar_mode()
	if demo.radar == previous_radar or demo.radar != demo.cone_radar:
		return _fail("The demo should switch from its 360 radar to the forward-cone radar.")
	demo.queue_free()
	print("CreatureRadar3D smoke test passed.")
	quit()


func _target_at(parent: Node3D, at: Vector3, id: StringName) -> Node3D:
	var target := Target.new()
	target.position = at
	target.radar_id = id
	parent.add_child(target)
	return target


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
