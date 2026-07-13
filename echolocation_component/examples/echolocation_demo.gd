extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var echo = $Player/Camera3D/EcholocationComponent3D
@onready var status_label: Label = $UI/Status

var look_sensitivity := 0.0022
var move_speed := 5.0
var ground_acceleration := 24.0
var gravity := 23.52
var jump_velocity := 7.0
var pitch := 0.0
var jump_requested := false
var wall_contact_time := 0.0


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	echo.add_exclusion(player)


func _physics_process(delta: float) -> void:
	var input_2d := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	).limit_length()
	var wish_direction := (player.global_basis * Vector3(input_2d.x, 0.0, input_2d.y)).normalized()
	player.velocity.x = move_toward(player.velocity.x, wish_direction.x * move_speed, ground_acceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, wish_direction.z * move_speed, ground_acceleration * delta)
	if player.is_on_floor() and jump_requested:
		player.velocity.y = jump_velocity
	elif not player.is_on_floor():
		player.velocity.y -= gravity * delta
	else:
		player.velocity.y = -0.1
	jump_requested = false
	player.move_and_slide()
	wall_contact_time = maxf(wall_contact_time - delta, 0.0)
	for collision_index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(collision_index)
		if absf(collision.get_normal().y) < 0.65:
			wall_contact_time = 0.2
			break
	_update_status()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * look_sensitivity)
		pitch = clampf(pitch - event.relative.y * look_sensitivity, -1.5, 1.5)
		camera.rotation.x = pitch
	elif event.is_action_pressed("echo"):
		echo.emit_echo()
	elif event.is_action_pressed("jump"):
		jump_requested = true
	elif event.is_action_pressed("clear_echo"):
		echo.clear_echo()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)


func _update_status() -> void:
	var state := "PROPAGATING" if echo.is_echo_active else "READY"
	status_label.text = "MODE SPHERE 360    CONTOURS %04d / %04d    PULSE %05.1fm    ECHO %s    GROUND %s    COLLISION %s" % [
		echo.outline_point_count,
		echo.detected_edge_count,
		echo.pulse_radius,
		state,
		"CONTACT" if player.is_on_floor() else "AIRBORNE",
		"WALL" if wall_contact_time > 0.0 else "CLEAR",
	]
