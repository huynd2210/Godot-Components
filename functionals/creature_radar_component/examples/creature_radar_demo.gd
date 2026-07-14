extends Node3D

const Radar := preload("res://addons/creature_radar/creature_radar_3d.gd")
const ConeRadar := preload("res://addons/creature_radar/creature_cone_radar_3d.gd")
const Target := preload("res://addons/creature_radar/radar_target_3d.gd")
const RadarDisplay := preload("res://addons/creature_radar/creature_radar_display.gd")

var player: CharacterBody3D
var camera: Camera3D
var radar: Node3D
var omni_radar: Node3D
var cone_radar: Node3D
var radar_display: Control
var tracker: Node3D
var creatures: Array[Dictionary] = []
var pitch := 0.0
var tracker_blend := 1.0
var tracker_target := 1.0
var tracker_is_raised := true
var beep_time := 0.0
var beep_player: AudioStreamPlayer
var hint_label: Label
var mode_label: Label


func _ready() -> void:
	_build_environment()
	_build_station()
	_build_player()
	_build_creatures()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.0022)
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.25, 1.25)
		camera.rotation.x = pitch
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
			set_tracker_raised(not tracker_is_raised)
			get_viewport().set_input_as_handled()
		if event.keycode == KEY_Q or event.physical_keycode == KEY_Q:
			switch_radar_mode()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (player.global_basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := 6.0 if Input.is_action_pressed("sprint") else 3.6
	player.velocity.x = move_toward(player.velocity.x, direction.x * speed, 18.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * speed, 18.0 * delta)
	player.move_and_slide()

	tracker_blend = move_toward(tracker_blend, tracker_target, delta * 4.2)
	var movement_amount := Vector2(player.velocity.x, player.velocity.z).length() / 6.0
	var bob := Time.get_ticks_msec() * 0.008
	tracker.position = Vector3(
		lerpf(0.92, 0.34, tracker_blend) + sin(bob * 0.5) * 0.008 * movement_amount,
		lerpf(-1.28, -0.28, tracker_blend) + absf(sin(bob)) * 0.014 * movement_amount,
		lerpf(-0.48, -0.72, tracker_blend)
	)
	tracker.rotation_degrees = Vector3(lerpf(42.0, -7.0, tracker_blend), lerpf(-8.0, -3.0, tracker_blend), sin(bob * 0.5) * movement_amount)
	tracker.visible = tracker_blend > 0.015 or tracker_target > 0.0
	_animate_creatures(delta)
	_update_audio(delta)


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("030706")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("78928a")
	environment.ambient_light_energy = 0.16
	environment.fog_enabled = true
	environment.fog_light_color = Color("172822")
	environment.fog_light_energy = 0.35
	environment.fog_density = 0.018
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


func _build_station() -> void:
	_add_box("Floor", Vector3(0, -0.15, -5), Vector3(26, 0.3, 32), Color("202725"), true)
	_add_box("Ceiling", Vector3(0, 4.2, -5), Vector3(26, 0.25, 32), Color("111716"), false)
	_add_box("WallL", Vector3(-13, 2, -5), Vector3(0.4, 4.2, 32), Color("303936"), true)
	_add_box("WallR", Vector3(13, 2, -5), Vector3(0.4, 4.2, 32), Color("303936"), true)
	_add_box("WallFront", Vector3(0, 2, 11), Vector3(26, 4.2, 0.4), Color("303936"), true)
	_add_box("WallBack", Vector3(0, 2, -21), Vector3(26, 4.2, 0.4), Color("303936"), true)
	# Broken cross-walls create sightline-blocking rooms with offset doorways.
	_add_box("BulkheadA1", Vector3(-8.5, 2, 2), Vector3(9, 4.2, 0.45), Color("35413e"), true)
	_add_box("BulkheadA2", Vector3(7.5, 2, 2), Vector3(11, 4.2, 0.45), Color("35413e"), true)
	_add_box("BulkheadB1", Vector3(-7.5, 2, -8), Vector3(11, 4.2, 0.45), Color("35413e"), true)
	_add_box("BulkheadB2", Vector3(8.5, 2, -8), Vector3(9, 4.2, 0.45), Color("35413e"), true)
	_add_box("SideRoom", Vector3(3.5, 2, -14), Vector3(0.45, 4.2, 12), Color("2a3431"), true)

	for position in [Vector3(-9, 0.65, 6), Vector3(9, 0.65, -4), Vector3(-9, 0.65, -13), Vector3(7, 0.65, -17)]:
		_add_box("Cargo", position, Vector3(2.2, 1.3, 1.7), Color("4b5149"), true)
		_add_box("CargoStripe", position + Vector3(0, 0.66, 0), Vector3(2.22, 0.08, 1.72), Color("c18135"), false)

	# Ceiling conduits and cold fluorescent pools give the station depth.
	for x in [-10.5, 10.5]:
		_add_pipe(Vector3(x, 3.65, -5), 0.16, 30.0, Color("4b5b57"))
	for z in [7.0, -3.0, -13.0, -19.0]:
		var panel := _add_box("LightPanel", Vector3(0, 4.0, z), Vector3(4.2, 0.08, 0.45), Color("bcebdc"), false)
		var material: StandardMaterial3D = panel.material_override
		material.emission_enabled = true
		material.emission = Color("8fc9b8")
		material.emission_energy_multiplier = 2.5
		var light := OmniLight3D.new()
		light.position = Vector3(0, 3.55, z)
		light.light_color = Color("9ed8c7")
		light.light_energy = 2.1
		light.omni_range = 8.0
		light.shadow_enabled = true
		add_child(light)
	# Emergency light near the deeper room.
	var red_light := OmniLight3D.new()
	red_light.position = Vector3(8, 2.5, -15)
	red_light.light_color = Color("ff492f")
	red_light.light_energy = 3.0
	red_light.omni_range = 7.0
	add_child(red_light)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1.05, 8)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	collision.shape = capsule
	player.add_child(collision)
	add_child(player)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 0.72
	camera.fov = 72.0
	player.add_child(camera)

	omni_radar = Radar.new()
	omni_radar.name = "OmnidirectionalRadar3D"
	omni_radar.detection_range = 22.0
	omni_radar.scans_per_second = 12.0
	player.add_child(omni_radar)
	cone_radar = ConeRadar.new()
	cone_radar.name = "ForwardConeRadar3D"
	cone_radar.scans_per_second = 12.0
	cone_radar.auto_scan = false
	player.add_child(cone_radar)
	radar = omni_radar
	tracker = _build_tracker()
	camera.add_child(tracker)


func _build_tracker() -> Node3D:
	var device := Node3D.new()
	device.name = "HandheldCreatureRadar"
	var shell := _mesh_box(Vector3(0.48, 0.5, 0.09), Color("3a463c"))
	shell.position = Vector3(0, 0, 0)
	device.add_child(shell)
	var screen_recess := _mesh_box(Vector3(0.39, 0.36, 0.018), Color("0b100d"))
	screen_recess.position = Vector3(0, -0.025, 0.055)
	device.add_child(screen_recess)

	var viewport := SubViewport.new()
	viewport.name = "RadarViewport"
	viewport.size = Vector2i(512, 430)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	device.add_child(viewport)
	radar_display = RadarDisplay.new()
	radar_display.name = "CreatureRadarDisplay"
	radar_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radar_display.set_radar(radar)
	viewport.add_child(radar_display)

	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.295)
	screen.mesh = quad
	screen.position = Vector3(0, -0.025, 0.066)
	var screen_material := StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_texture = viewport.get_texture()
	screen_material.emission_enabled = true
	screen_material.emission_texture = viewport.get_texture()
	screen_material.emission_energy_multiplier = 2.3
	quad.material = screen_material
	device.add_child(screen)

	for x in [-0.19, 0.19]:
		var rail := _mesh_box(Vector3(0.055, 0.49, 0.12), Color("657061"))
		rail.position = Vector3(x, 0, 0.02)
		device.add_child(rail)
	var handle := _mesh_box(Vector3(0.16, 0.24, 0.11), Color("252b27"))
	handle.position = Vector3(0.08, -0.34, -0.01)
	device.add_child(handle)
	var lamp := _mesh_box(Vector3(0.07, 0.035, 0.02), Color("ffb632"))
	lamp.position = Vector3(-0.14, 0.225, 0.068)
	device.add_child(lamp)
	var lamp_material: StandardMaterial3D = lamp.material_override
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("ff9d2e")
	lamp_material.emission_energy_multiplier = 4.0

	# Simple forearm/hand silhouette sells the held-device perspective.
	var hand := MeshInstance3D.new()
	var hand_mesh := CapsuleMesh.new()
	hand_mesh.radius = 0.075
	hand_mesh.height = 0.32
	hand.mesh = hand_mesh
	hand.material_override = _material(Color("8e6651"), 0.85)
	hand.position = Vector3(0.1, -0.43, 0.02)
	hand.rotation_degrees.z = -18
	device.add_child(hand)

	beep_player = AudioStreamPlayer.new()
	beep_player.stream = _make_tracker_beep()
	beep_player.volume_db = -12.0
	device.add_child(beep_player)
	return device


func _build_creatures() -> void:
	_add_creature("Vent Stalker", Vector3(-7, 0, -2), Vector3(4, 0, 0), 0.5)
	_add_creature("Cargo Crawler", Vector3(8, 0, -11), Vector3(0, 0, 5), 2.1)
	_add_creature("Deep Signal", Vector3(-6, 0, -17), Vector3(5, 0, 2), 4.0)


func _add_creature(label: String, center: Vector3, axis: Vector3, phase: float) -> void:
	var creature := Node3D.new()
	creature.name = label
	creature.position = center
	add_child(creature)
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.34
	torso_mesh.height = 1.7
	torso.mesh = torso_mesh
	torso.position.y = 1.05
	torso.material_override = _material(Color("101815"), 0.7)
	creature.add_child(torso)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.28
	head_mesh.height = 0.56
	head.mesh = head_mesh
	head.scale = Vector3(0.72, 1.0, 1.35)
	head.position = Vector3(0, 1.83, -0.12)
	head.material_override = _material(Color("17211d"), 0.62)
	creature.add_child(head)
	for x in [-0.38, 0.38]:
		var limb := MeshInstance3D.new()
		var limb_mesh := CylinderMesh.new()
		limb_mesh.top_radius = 0.07
		limb_mesh.bottom_radius = 0.1
		limb_mesh.height = 1.35
		limb.mesh = limb_mesh
		limb.position = Vector3(x, 0.72, 0)
		limb.rotation_degrees.z = -18.0 * signf(x)
		limb.material_override = _material(Color("0d1512"), 0.75)
		creature.add_child(limb)
	var marker := Target.new()
	marker.radar_id = label
	marker.position.y = 1.0
	creature.add_child(marker)
	creatures.append({"node": creature, "center": center, "axis": axis, "phase": phase, "speed": 0.34 + phase * 0.025})


func _build_hud() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	hint_label = Label.new()
	hint_label.position = Vector2(22, 18)
	hint_label.text = "WASD  MOVE     SHIFT  SPRINT     TAB  RAISE/LOWER     Q  RADAR MODE     ESC  MOUSE"
	hint_label.add_theme_color_override("font_color", Color("9eb8ae"))
	hint_label.add_theme_font_size_override("font_size", 15)
	overlay.add_child(hint_label)
	var objective := Label.new()
	objective.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective.position = Vector2(-300, 22)
	objective.size = Vector2(275, 80)
	objective.text = "SIGNAL ACQUISITION\nLocate movement beyond the bulkhead"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective.add_theme_color_override("font_color", Color("b6c8c1"))
	objective.add_theme_font_size_override("font_size", 14)
	overlay.add_child(objective)
	mode_label = Label.new()
	mode_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mode_label.position = Vector2(22, -54)
	mode_label.size = Vector2(320, 32)
	mode_label.text = "SENSOR: OMNIDIRECTIONAL 360"
	mode_label.add_theme_color_override("font_color", Color("8dffb0"))
	mode_label.add_theme_font_size_override("font_size", 14)
	overlay.add_child(mode_label)


func set_tracker_raised(raised: bool) -> void:
	tracker_is_raised = raised
	tracker_target = 1.0 if raised else 0.0
	if raised and is_instance_valid(tracker):
		tracker.visible = true


func switch_radar_mode() -> void:
	if radar == omni_radar:
		omni_radar.auto_scan = false
		omni_radar.clear_contacts()
		cone_radar.auto_scan = true
		radar = cone_radar
		mode_label.text = "SENSOR: FORWARD CONE 70 DEG"
	else:
		cone_radar.auto_scan = false
		cone_radar.clear_contacts()
		omni_radar.auto_scan = true
		radar = omni_radar
		mode_label.text = "SENSOR: OMNIDIRECTIONAL 360"
	radar.scan_now()
	radar_display.set_radar(radar)


func _animate_creatures(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for data in creatures:
		var creature: Node3D = data.node
		var amount := sin(now * data.speed + data.phase)
		creature.position = data.center + data.axis * amount
		creature.rotation.y = atan2(data.axis.x, data.axis.z) + (PI if cos(now * data.speed + data.phase) < 0 else 0.0)
		creature.position.y = sin(now * 5.0 + data.phase) * 0.025


func _update_audio(delta: float) -> void:
	beep_time -= delta
	if beep_time > 0.0 or radar.contacts.is_empty() or tracker_blend < 0.85:
		return
	var nearest := radar.global_position.distance_to(radar.contacts[0].global_position)
	beep_time = lerpf(0.16, 0.85, clampf(nearest / radar.detection_range, 0.0, 1.0))
	beep_player.pitch_scale = lerpf(1.45, 0.82, clampf(nearest / radar.detection_range, 0.0, 1.0))
	beep_player.play()


func _add_box(node_name: String, at: Vector3, size: Vector3, color: Color, collision_enabled: bool) -> MeshInstance3D:
	var mesh_instance := _mesh_box(size, color)
	mesh_instance.name = node_name
	if collision_enabled:
		var body := StaticBody3D.new()
		body.name = node_name + "Body"
		body.position = at
		body.add_child(mesh_instance)
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		add_child(body)
	else:
		mesh_instance.position = at
		add_child(mesh_instance)
	return mesh_instance


func _add_pipe(at: Vector3, radius: float, length: float, color: Color) -> void:
	var pipe := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	pipe.mesh = mesh
	pipe.position = at
	pipe.rotation_degrees.x = 90
	pipe.material_override = _material(color, 0.65)
	add_child(pipe)


func _mesh_box(size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _material(color, 0.78)
	return instance


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.18
	return material


func _make_tracker_beep() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.055
	var samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for index in samples:
		var t := float(index) / sample_rate
		var envelope := exp(-t * 42.0)
		var value := (sin(TAU * 1250.0 * t) + sin(TAU * 1740.0 * t) * 0.35) * envelope * 0.52
		data.encode_s16(index * 2, clampi(int(value * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
