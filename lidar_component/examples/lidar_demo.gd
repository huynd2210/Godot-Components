extends Node3D

@onready var camera: Camera3D = $Player/Camera3D
# Avoid relying on Godot's generated global-class cache so this demo can run
# immediately from a freshly copied/downloaded project.
@onready var scanner = $Player/Camera3D/LidarGun/LidarComponent3D
@onready var status_label: Label = $UI/Status

var look_sensitivity := 0.0022
var move_speed := 7.0
var pitch := 0.0


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scanner.scan_finished.connect(_on_scan_finished)
	_update_status(0, scanner.beams_per_scan)


func _process(delta: float) -> void:
	var input_2d := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	).limit_length()
	var vertical := float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	var movement := (camera.global_basis * Vector3(input_2d.x, vertical, input_2d.y)).normalized()
	if movement.length_squared() > 0.0:
		$Player.global_position += movement * move_speed * delta


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
		_update_status(0, scanner.beams_per_scan)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				scanner.clear_points()
				_update_status(0, scanner.beams_per_scan)
			KEY_ESCAPE:
				Input.mouse_mode = (
					Input.MOUSE_MODE_VISIBLE
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
					else Input.MOUSE_MODE_CAPTURED
				)


func _on_scan_finished(hits: int, rays: int) -> void:
	_update_status(hits, rays)


func _update_status(hits: int, rays: int) -> void:
	status_label.text = "POINTS  %05d     LAST SCAN  %03d/%03d     SCANNER  %s" % [
		scanner.point_count,
		hits,
		rays,
		"ACTIVE" if scanner.auto_scan else "IDLE",
	]
