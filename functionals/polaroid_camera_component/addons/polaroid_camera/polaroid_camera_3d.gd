@tool
class_name PolaroidCamera3D
extends Node3D
## Captures still images from a Camera3D using a private SubViewport.
##
## Put this node below the camera that should take pictures, then call:
##     var image: Image = await $PolaroidCamera3D.take_picture()

signal capture_started
signal picture_taken(image: Image, texture: ImageTexture, file_path: String)
signal capture_failed(reason: String)
signal camera_ready

@export_category("Camera")
@export var source_camera: Camera3D
@export var auto_find_parent_camera: bool = true
@export var capture_size := Vector2i(640, 480)

@export_category("Film")
@export_range(0.0, 10.0, 0.05, "suffix:s") var cooldown_seconds := 0.75
@export var save_to_disk := false
@export_dir var save_directory := "user://polaroids"
@export var file_prefix := "polaroid"

@export_category("Feedback")
@export var flash_enabled := true
@export_range(0.0, 1.0, 0.01) var flash_strength := 0.82
@export_range(0.01, 1.0, 0.01, "suffix:s") var flash_duration := 0.16
@export var shutter_sound: AudioStream
@export_range(-80.0, 12.0, 0.1, "suffix:dB") var shutter_volume_db := -5.0

var latest_image: Image
var latest_texture: ImageTexture
var latest_file_path := ""
var is_capturing: bool:
	get:
		return _is_capturing

var _is_capturing := false
var _next_capture_time_msec := 0
var _capture_viewport: SubViewport
var _capture_camera: Camera3D
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _audio_player: AudioStreamPlayer
var _generated_shutter_sound: AudioStreamWAV


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_prepare_camera()
	_prepare_feedback()
	camera_ready.emit()


## Returns true when a valid source camera is available and the film cooldown ended.
func can_take_picture() -> bool:
	return (
		not _is_capturing
		and Time.get_ticks_msec() >= _next_capture_time_msec
		and _resolve_source_camera() != null
	)


## Captures a still image. Await this function to receive the resulting Image.
## Pass a res:// or user:// PNG path to save this one photo, regardless of
## save_to_disk. When omitted, save_to_disk and save_directory are used.
func take_picture(custom_file_path := "") -> Image:
	if _is_capturing:
		_capture_error("A picture is already being captured.")
		return null
	var camera := _resolve_source_camera()
	if camera == null:
		_capture_error("PolaroidCamera3D needs a source Camera3D or a Camera3D parent.")
		return null
	if Time.get_ticks_msec() < _next_capture_time_msec:
		_capture_error("The camera is waiting for the film cooldown.")
		return null

	_is_capturing = true
	if _capture_viewport == null:
		_prepare_camera()
	if _capture_viewport == null or _capture_camera == null:
		_is_capturing = false
		_capture_error("The capture viewport could not be created.")
		return null

	_sync_camera(camera)
	capture_started.emit()
	_play_feedback()
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	var image := _capture_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_is_capturing = false
		_capture_error("Godot returned an empty viewport image.")
		return null

	latest_image = image
	latest_texture = ImageTexture.create_from_image(image)
	latest_file_path = _save_image(image, custom_file_path)
	_next_capture_time_msec = Time.get_ticks_msec() + int(cooldown_seconds * 1000.0)
	_is_capturing = false
	picture_taken.emit(latest_image, latest_texture, latest_file_path)
	return latest_image


## Clears the in-memory photo. Saved PNG files are not removed.
func clear_picture() -> void:
	latest_image = null
	latest_texture = null
	latest_file_path = ""


func _resolve_source_camera() -> Camera3D:
	if is_instance_valid(source_camera):
		return source_camera
	if not auto_find_parent_camera:
		return null
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Camera3D:
			return ancestor as Camera3D
		ancestor = ancestor.get_parent()
	return null


func _prepare_camera() -> void:
	if _capture_viewport != null and is_instance_valid(_capture_viewport):
		return
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "PolaroidCaptureViewport"
	_capture_viewport.size = Vector2i(maxi(capture_size.x, 1), maxi(capture_size.y, 1))
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_capture_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_capture_viewport.handle_input_locally = false
	_capture_viewport.gui_disable_input = true
	_capture_viewport.disable_3d = false
	add_child(_capture_viewport, false, Node.INTERNAL_MODE_BACK)

	_capture_camera = Camera3D.new()
	_capture_camera.name = "PolaroidCaptureCamera"
	_capture_camera.current = true
	_capture_viewport.add_child(_capture_camera)


func _sync_camera(camera: Camera3D) -> void:
	_capture_viewport.size = Vector2i(maxi(capture_size.x, 1), maxi(capture_size.y, 1))
	_capture_camera.global_transform = camera.global_transform
	_capture_camera.projection = camera.projection
	_capture_camera.fov = camera.fov
	_capture_camera.size = camera.size
	_capture_camera.frustum_offset = camera.frustum_offset
	_capture_camera.near = camera.near
	_capture_camera.far = camera.far
	_capture_camera.keep_aspect = camera.keep_aspect
	_capture_camera.cull_mask = camera.cull_mask
	_capture_camera.h_offset = camera.h_offset
	_capture_camera.v_offset = camera.v_offset
	_capture_camera.attributes = camera.attributes
	_capture_camera.environment = camera.environment


func _prepare_feedback() -> void:
	_generated_shutter_sound = _make_shutter_sound()
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "PolaroidShutterAudio"
	add_child(_audio_player, false, Node.INTERNAL_MODE_BACK)

	_flash_layer = CanvasLayer.new()
	_flash_layer.name = "PolaroidFlashLayer"
	_flash_layer.layer = 1000
	add_child(_flash_layer, false, Node.INTERNAL_MODE_BACK)
	_flash_rect = ColorRect.new()
	_flash_rect.name = "Flash"
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color.WHITE
	_flash_rect.modulate.a = 0.0
	_flash_rect.visible = false
	_flash_layer.add_child(_flash_rect)


func _play_feedback() -> void:
	if _audio_player != null:
		_audio_player.stream = shutter_sound if shutter_sound != null else _generated_shutter_sound
		_audio_player.volume_db = shutter_volume_db
		_audio_player.play()
	if not flash_enabled or _flash_rect == null:
		return
	_flash_rect.visible = true
	_flash_rect.modulate.a = flash_strength
	var tween := create_tween()
	tween.tween_property(_flash_rect, "modulate:a", 0.0, flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_flash_rect.hide)


func _save_image(image: Image, custom_file_path: String) -> String:
	var path := custom_file_path
	if path.is_empty() and save_to_disk:
		var safe_prefix := file_prefix.validate_filename()
		if safe_prefix.is_empty():
			safe_prefix = "polaroid"
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		path = save_directory.path_join("%s_%s_%d.png" % [safe_prefix, stamp, Time.get_ticks_msec()])
	if path.is_empty():
		return ""
	if path.get_extension().to_lower() != "png":
		path += ".png"
	var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_capture_error("Could not create photo directory: %s" % path.get_base_dir())
		return ""
	var save_error := image.save_png(path)
	if save_error != OK:
		_capture_error("Could not save photo to %s (error %d)." % [path, save_error])
		return ""
	return path


func _capture_error(reason: String) -> void:
	push_warning(reason)
	capture_failed.emit(reason)


func _make_shutter_sound() -> AudioStreamWAV:
	var sample_rate := 44100
	var duration := 0.11
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 90731
	for index in sample_count:
		var t := float(index) / float(sample_rate)
		var click_one := exp(-t * 105.0) * noise.randf_range(-1.0, 1.0)
		var second_t := maxf(t - 0.052, 0.0)
		var click_two := (exp(-second_t * 135.0) * noise.randf_range(-0.8, 0.8)) if t >= 0.052 else 0.0
		var mechanism := sin(TAU * 155.0 * t) * exp(-t * 32.0) * 0.22
		var value := clampf(click_one * 0.62 + click_two * 0.48 + mechanism, -1.0, 1.0)
		bytes.encode_s16(index * 2, int(value * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav
