extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var polaroid = $Player/Camera3D/PolaroidCamera3D
@onready var photo_card: PanelContainer = $UI/PhotoCard
@onready var photo: TextureRect = $UI/PhotoCard/Margin/Stack/Photo
@onready var caption: Label = $UI/PhotoCard/Margin/Stack/Caption
@onready var status: Label = $UI/Status

var look_sensitivity := 0.0022
var move_speed := 5.5
var gravity := 23.52
var pitch := 0.0
var shot_number := 0


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	polaroid.picture_taken.connect(_on_picture_taken)
	polaroid.capture_failed.connect(_on_capture_failed)
	photo_card.visible = false


func _physics_process(delta: float) -> void:
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (player.global_basis * Vector3(movement.x, 0.0, movement.y)).normalized()
	player.velocity.x = move_toward(player.velocity.x, direction.x * move_speed, 22.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * move_speed, 22.0 * delta)
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	else:
		player.velocity.y = -0.1
	player.move_and_slide()
	status.text = "FILM  UNLIMITED    RESOLUTION  %d x %d    CAMERA  %s" % [
		polaroid.capture_size.x,
		polaroid.capture_size.y,
		"DEVELOPING" if polaroid.is_capturing else "READY",
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * look_sensitivity)
		pitch = clampf(pitch - event.relative.y * look_sensitivity, -1.35, 1.35)
		camera.rotation.x = pitch
	elif event.is_action_pressed("take_picture"):
		_take_picture()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _take_picture() -> void:
	if polaroid.can_take_picture():
		polaroid.take_picture()


func _on_picture_taken(_image: Image, texture: ImageTexture, _file_path: String) -> void:
	shot_number += 1
	photo.texture = texture
	caption.text = "MEMORY  %02d" % shot_number
	photo_card.visible = true
	photo_card.pivot_offset = photo_card.size * 0.5
	photo_card.scale = Vector2(0.72, 0.72)
	photo_card.rotation = deg_to_rad(-7.0)
	photo.modulate = Color(0.08, 0.08, 0.08, 1.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(photo_card, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(photo_card, "rotation", deg_to_rad(2.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(photo, "modulate", Color.WHITE, 2.2).set_delay(0.18).set_trans(Tween.TRANS_SINE)


func _on_capture_failed(reason: String) -> void:
	status.text = reason.to_upper()
