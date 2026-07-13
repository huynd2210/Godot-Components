extends Node3D

@onready var camera: Camera3D = $Player/Camera3D
# Avoid relying on Godot's generated global-class cache so this demo can run
# immediately from a freshly copied/downloaded project.
@onready var scanner = $Player/Camera3D/LidarGun/LidarComponent3D
@onready var player: CharacterBody3D = $Player
@onready var status_label: Label = $UI/Status

var look_sensitivity := 0.0022
var move_speed := 5.0
var ground_acceleration := 24.0
var jump_velocity := 5.2
var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var pitch := 0.0
var last_hits := 0
var last_rays := 0
var jump_requested := false


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scanner.scan_finished.connect(_on_scan_finished)
	_update_status(0, scanner.beams_per_scan)


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
	_update_status(last_hits, last_rays)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		$Player.rotate_y(-event.relative.x * look_sensitivity)
		pitch = clampf(pitch - event.relative.y * look_sensitivity, -1.5, 1.5)
		camera.rotation.x = pitch
	elif event.is_action_pressed("scan"):
		if not scanner.auto_scan:
			scanner.scan_once()
		scanner.auto_scan = true
		_update_status(0, scanner.beams_per_scan)
	elif event.is_action_released("scan"):
		scanner.auto_scan = false
		_update_status(last_hits, last_rays)
	elif event.is_action_pressed("jump"):
		jump_requested = true
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				scanner.clear_points()
				last_hits = 0
				last_rays = scanner.beams_per_scan
				_update_status(0, scanner.beams_per_scan)
			KEY_ESCAPE:
				Input.mouse_mode = (
					Input.MOUSE_MODE_VISIBLE
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
					else Input.MOUSE_MODE_CAPTURED
				)


func _on_scan_finished(hits: int, rays: int) -> void:
	last_hits = hits
	last_rays = rays
	_update_status(hits, rays)


func _update_status(hits: int, rays: int) -> void:
	status_label.text = "POINTS %05d    LAST %03d/%03d    SCANNER %s    GROUNDED %s" % [
		scanner.point_count,
		hits,
		rays,
		"ACTIVE" if scanner.auto_scan else "IDLE",
		"YES" if player.is_on_floor() else "NO",
	]
