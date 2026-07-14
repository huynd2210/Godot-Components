extends Node3D

const HandheldMirrorScene := preload("res://addons/mirror_3d/handheld_mirror_3d.tscn")
const MirrorScene := preload("res://addons/mirror_3d/mirror_3d.tscn")
const BeanPlayerScene := preload("res://examples/bean_player_model.tscn")
const PLAYER_REFLECTION_LAYER := 2

var move_speed := 5.2
var acceleration := 24.0
var gravity := 23.52
var jump_speed := 7.0
var look_sensitivity := 0.0022
var mirror_sensitivity := 0.16
var camera_pitch := 0.0

var player: CharacterBody3D
var camera: Camera3D
var handheld_mirror: HandheldMirror3D
var status_label: Label
var hint_label: Label
var facing_mirrors: Array[Mirror3D] = []
var inter_mirror_reflections_enabled := true


func _ready() -> void:
	_build_environment()
	_build_player()
	_build_mirrors()
	_build_ui()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (player.global_basis * Vector3(movement.x, 0.0, movement.y)).normalized()
	player.velocity.x = move_toward(player.velocity.x, direction.x * move_speed, acceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * move_speed, acceleration * delta)
	if player.is_on_floor():
		player.velocity.y = -0.1
		if Input.is_action_just_pressed("jump"):
			player.velocity.y = jump_speed
	else:
		player.velocity.y -= gravity * delta
	player.move_and_slide()

	var corner_input := Input.get_axis("mirror_left", "mirror_right")
	handheld_mirror.set_corner_extension(corner_input)
	_update_status(corner_input)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_pressed("mirror_control"):
			handheld_mirror.add_tilt_input(Vector2(
				event.relative.x * mirror_sensitivity,
				event.relative.y * mirror_sensitivity
			))
		else:
			player.rotate_y(-event.relative.x * look_sensitivity)
			camera_pitch = clampf(camera_pitch - event.relative.y * look_sensitivity, -1.45, 1.45)
			camera.rotation.x = camera_pitch
	elif event.is_action_pressed("mirror_reset"):
		handheld_mirror.reset_pose()
	elif event.is_action_pressed("toggle_mirror"):
		handheld_mirror.visible = not handheld_mirror.visible
	elif event.is_action_pressed("toggle_recursive_mirrors"):
		inter_mirror_reflections_enabled = not inter_mirror_reflections_enabled
		for mirror in facing_mirrors:
			mirror.reflect_other_mirrors = inter_mirror_reflections_enabled
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.05, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.56, 0.72)
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(0.96, 0.9, 0.78)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	_add_box("Floor", Vector3(0.0, -0.15, -3.0), Vector3(20.0, 0.3, 26.0), Color(0.19, 0.22, 0.27), true)
	_add_box("BackWall", Vector3(0.0, 2.4, -16.0), Vector3(20.0, 4.8, 0.3), Color(0.13, 0.18, 0.25), true)
	_add_box("FrontWall", Vector3(0.0, 2.4, 10.0), Vector3(20.0, 4.8, 0.3), Color(0.13, 0.18, 0.25), true)
	_add_box("LeftWall", Vector3(-10.0, 2.4, -3.0), Vector3(0.3, 4.8, 26.0), Color(0.11, 0.16, 0.22), true)
	_add_box("RightWall", Vector3(10.0, 2.4, -3.0), Vector3(0.3, 4.8, 26.0), Color(0.11, 0.16, 0.22), true)

	# An L-wall creates a real blind corner for the handheld mirror exercise.
	_add_box("CornerWallFront", Vector3(-2.0, 1.65, -3.0), Vector3(8.0, 3.3, 0.35), Color(0.31, 0.34, 0.39), true)
	_add_box("CornerWallSide", Vector3(2.0, 1.65, -7.0), Vector3(0.35, 3.3, 8.0), Color(0.27, 0.3, 0.36), true)
	_add_box("CornerCap", Vector3(2.0, 3.45, -3.0), Vector3(0.62, 0.3, 0.62), Color(0.95, 0.58, 0.12), false)

	# High-contrast subjects make it obvious when the mirror sees around the wall.
	_add_box("HiddenRedColumn", Vector3(0.4, 1.2, -7.2), Vector3(0.8, 2.4, 0.8), Color(0.95, 0.12, 0.12), true)
	_add_box("HiddenCyanColumn", Vector3(-2.0, 0.9, -9.3), Vector3(1.2, 1.8, 1.2), Color(0.04, 0.78, 0.95), true)
	_add_box("GoldenMarker", Vector3(5.7, 1.0, -11.8), Vector3(1.1, 2.0, 1.1), Color(1.0, 0.62, 0.08), true)
	_add_box("PurpleMarker", Vector3(-6.8, 1.4, -12.5), Vector3(1.4, 2.8, 1.0), Color(0.58, 0.22, 0.94), true)
	# These sit behind the starting camera and appear in the hand mirror at rest.
	_add_box("RearOrangeMarker", Vector3(2.3, 1.15, 8.8), Vector3(1.15, 2.3, 0.7), Color(1.0, 0.28, 0.05), true)
	_add_box("RearGreenMarker", Vector3(-2.4, 0.85, 8.75), Vector3(1.6, 1.7, 0.65), Color(0.08, 0.88, 0.38), true)

	for light_data in [
		[Vector3(-6.5, 3.4, -8.0), Color(0.28, 0.55, 1.0)],
		[Vector3(5.4, 3.2, -10.5), Color(1.0, 0.42, 0.18)],
	]:
		var light := OmniLight3D.new()
		light.position = light_data[0]
		light.light_color = light_data[1]
		light.light_energy = 3.0
		light.omni_range = 8.0
		add_child(light)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.3, 0.05, 5.2)
	player.floor_snap_length = 0.25
	add_child(player)
	var bean_model := BeanPlayerScene.instantiate()
	bean_model.name = "BeanPlayerModel"
	player.add_child(bean_model)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	player.add_child(collision)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.58
	camera.current = true
	camera.near = 0.03
	camera.far = 200.0
	camera.set_cull_mask_value(PLAYER_REFLECTION_LAYER, false)
	player.add_child(camera)

	handheld_mirror = HandheldMirrorScene.instantiate()
	handheld_mirror.name = "HandheldMirror3D"
	handheld_mirror.reflection_extra_cull_mask = 1 << (PLAYER_REFLECTION_LAYER - 1)
	camera.add_child(handheld_mirror)


func _build_mirrors() -> void:
	var wall_mirror: Mirror3D = MirrorScene.instantiate()
	wall_mirror.name = "WallMirror"
	wall_mirror.position = Vector3(-9.78, 2.05, -7.2)
	wall_mirror.rotation_degrees.y = 90.0
	wall_mirror.mirror_size = Vector2(1.5, 2.2)
	wall_mirror.frame_color = Color(0.78, 0.47, 0.14)
	wall_mirror.texture_width = 512
	wall_mirror.reflection_extra_cull_mask = 1 << (PLAYER_REFLECTION_LAYER - 1)
	add_child(wall_mirror)

	var standing_mirror: Mirror3D = MirrorScene.instantiate()
	standing_mirror.name = "StandingMirror"
	standing_mirror.position = Vector3(6.7, 1.65, -5.7)
	standing_mirror.rotation_degrees.y = -32.0
	standing_mirror.mirror_size = Vector2(1.25, 2.35)
	standing_mirror.frame_color = Color(0.08, 0.42, 0.46)
	standing_mirror.texture_width = 448
	standing_mirror.reflection_extra_cull_mask = 1 << (PLAYER_REFLECTION_LAYER - 1)
	add_child(standing_mirror)
	_add_box("StandingMirrorBase", Vector3(6.7, 0.12, -5.7), Vector3(1.8, 0.24, 0.75), Color(0.07, 0.28, 0.31), true)

	# A throttled, lower-resolution pair demonstrates safe inter-mirror feedback.
	var left_facing_mirror: Mirror3D = MirrorScene.instantiate()
	left_facing_mirror.name = "FacingMirrorLeft"
	left_facing_mirror.position = Vector3(-6.8, 1.55, 4.0)
	left_facing_mirror.rotation_degrees.y = 90.0
	left_facing_mirror.mirror_size = Vector2(1.2, 1.9)
	left_facing_mirror.frame_color = Color(0.76, 0.18, 0.28)
	left_facing_mirror.texture_width = 320
	left_facing_mirror.update_every_n_frames = 2
	left_facing_mirror.reflect_other_mirrors = true
	left_facing_mirror.reflection_extra_cull_mask = 1 << (PLAYER_REFLECTION_LAYER - 1)
	add_child(left_facing_mirror)
	facing_mirrors.append(left_facing_mirror)

	var right_facing_mirror: Mirror3D = MirrorScene.instantiate()
	right_facing_mirror.name = "FacingMirrorRight"
	right_facing_mirror.position = Vector3(6.8, 1.55, 4.0)
	right_facing_mirror.rotation_degrees.y = -90.0
	right_facing_mirror.mirror_size = Vector2(1.2, 1.9)
	right_facing_mirror.frame_color = Color(0.25, 0.46, 0.92)
	right_facing_mirror.texture_width = 320
	right_facing_mirror.update_every_n_frames = 2
	right_facing_mirror.reflect_other_mirrors = true
	right_facing_mirror.reflection_extra_cull_mask = 1 << (PLAYER_REFLECTION_LAYER - 1)
	add_child(right_facing_mirror)
	facing_mirrors.append(right_facing_mirror)
	_add_box("FacingMirrorLeftBase", Vector3(-6.8, 0.12, 4.0), Vector3(0.75, 0.24, 1.65), Color(0.32, 0.08, 0.12), true)
	_add_box("FacingMirrorRightBase", Vector3(6.8, 0.12, 4.0), Vector3(0.75, 0.24, 1.65), Color(0.08, 0.16, 0.34), true)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 116.0
	shade.color = Color(0.015, 0.025, 0.045, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)

	var title := Label.new()
	title.position = Vector2(26.0, 16.0)
	title.text = "MIRROR LAB // PLANAR REFLECTION"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.75, 0.91, 1.0))
	ui.add_child(title)

	hint_label = Label.new()
	hint_label.position = Vector2(28.0, 51.0)
	hint_label.text = "WASD walk   SPACE jump   MOUSE look   hold RMB + MOUSE tilt mirror\nQ / E reach around corners   R reset   F hide   T facing-mirror feedback   ESC release mouse"
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.72, 0.79, 0.86))
	ui.add_child(hint_label)

	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.position = Vector2(26.0, -47.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.99, 0.69, 0.23))
	ui.add_child(status_label)

	var crosshair := Label.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-5.0, -12.0)
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 20)
	crosshair.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))
	ui.add_child(crosshair)


func _update_status(corner_input: float) -> void:
	var tilt := handheld_mirror.get_target_tilt_degrees()
	var mode := "REST"
	if corner_input < -0.01:
		mode = "EXTENDING LEFT"
	elif corner_input > 0.01:
		mode = "EXTENDING RIGHT"
	elif Input.is_action_pressed("mirror_control"):
		mode = "TILTING"
	status_label.text = "HAND MIRROR  %s    YAW %+04.0f deg    PITCH %+04.0f deg    FACING PAIR %s    REFLECTION %d x %d" % [
		mode,
		tilt.x,
		tilt.y,
		"ON" if inter_mirror_reflections_enabled else "OFF",
		handheld_mirror.reflection_viewport.size.x if handheld_mirror.reflection_viewport else 0,
		handheld_mirror.reflection_viewport.size.y if handheld_mirror.reflection_viewport else 0,
	]


func _add_box(node_name: String, box_position: Vector3, size: Vector3, color: Color, collision_enabled: bool) -> Node3D:
	var root_node: Node3D
	if collision_enabled:
		root_node = StaticBody3D.new()
	else:
		root_node = Node3D.new()
	root_node.name = node_name
	root_node.position = box_position
	add_child(root_node)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	mesh.material = material
	mesh_instance.mesh = mesh
	root_node.add_child(mesh_instance)

	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root_node.add_child(collision)
	return root_node
