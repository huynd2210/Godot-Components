@tool
class_name Mirror3D
extends Node3D
## A reusable planar real-time mirror.
##
## The mirror's reflective face points along its local +Z axis. Assign a
## source_camera or leave it empty to follow the active Camera3D automatically.

signal reflection_ready
signal source_camera_changed(camera: Camera3D)

@export_category("Reflection")
@export var source_camera: Camera3D
@export_range(64, 2048, 1) var texture_width := 512:
	set(value):
		texture_width = maxi(value, 64)
		_resize_viewport()
@export_range(1, 32, 1) var update_every_n_frames := 1
@export_range(1, 20, 1) var reflection_layer := 20:
	set(value):
		reflection_layer = clampi(value, 1, 20)
		_update_layer_masks()
@export_range(0.001, 0.2, 0.001, "suffix:m") var near_plane_padding := 0.02
@export_range(5.0, 1000.0, 1.0, "suffix:m") var reflection_far := 200.0

@export_category("Appearance")
@export var mirror_size := Vector2(1.2, 1.7):
	set(value):
		mirror_size = Vector2(maxf(value.x, 0.05), maxf(value.y, 0.05))
		_update_geometry()
		_resize_viewport()
@export_range(0.0, 0.3, 0.005, "suffix:m") var frame_width := 0.075:
	set(value):
		frame_width = maxf(value, 0.0)
		_update_geometry()
@export_range(0.005, 0.2, 0.005, "suffix:m") var frame_depth := 0.055:
	set(value):
		frame_depth = maxf(value, 0.005)
		_update_geometry()
@export var frame_color := Color(0.22, 0.13, 0.065, 1.0):
	set(value):
		frame_color = value
		_update_materials()
@export var backing_color := Color(0.06, 0.065, 0.075, 1.0):
	set(value):
		backing_color = value
		_update_materials()
@export var show_handle := false:
	set(value):
		show_handle = value
		_update_geometry()
@export_range(0.05, 1.5, 0.01, "suffix:m") var handle_length := 0.34:
	set(value):
		handle_length = maxf(value, 0.05)
		_update_geometry()

var reflected_camera: Camera3D:
	get:
		return _reflection_camera
var reflection_viewport: SubViewport:
	get:
		return _reflection_viewport

var _reflection_viewport: SubViewport
var _reflection_camera: Camera3D
var _surface: MeshInstance3D
var _backing: MeshInstance3D
var _frame_top: MeshInstance3D
var _frame_bottom: MeshInstance3D
var _frame_left: MeshInstance3D
var _frame_right: MeshInstance3D
var _handle: MeshInstance3D
var _surface_material: ShaderMaterial
var _frame_material: StandardMaterial3D
var _backing_material: StandardMaterial3D
var _last_source_camera: Camera3D
var _frame_counter := 0


func _ready() -> void:
	_ensure_visuals()
	_update_geometry()
	_update_materials()
	_update_layer_masks()
	if Engine.is_editor_hint():
		return
	_prepare_reflection()
	reflection_ready.emit()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	_frame_counter += 1
	if _frame_counter < maxi(update_every_n_frames, 1):
		return
	_frame_counter = 0
	update_reflection()


## Immediately synchronizes the reflected camera and schedules one rendered frame.
func update_reflection() -> void:
	if _reflection_viewport == null or _reflection_camera == null:
		_prepare_reflection()
	var camera := _resolve_source_camera()
	if camera == null or camera == _reflection_camera:
		return
	if camera != _last_source_camera:
		_last_source_camera = camera
		source_camera_changed.emit(camera)
	_sync_reflected_camera(camera)
	_reflection_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Returns the world-space plane used by the reflection calculation.
func get_mirror_plane() -> Plane:
	var normal := global_basis.z.normalized()
	var glass_center := global_transform * Vector3(0.0, 0.0, frame_depth * 0.52)
	return Plane(normal, normal.dot(glass_center))


## Reflects a world-space point across this mirror's plane.
func reflect_point(point: Vector3) -> Vector3:
	var plane := get_mirror_plane()
	return point - plane.normal * (2.0 * plane.distance_to(point))


func _resolve_source_camera() -> Camera3D:
	if is_instance_valid(source_camera):
		return source_camera
	var main_viewport := get_viewport()
	if main_viewport != null:
		return main_viewport.get_camera_3d()
	return null


func _prepare_reflection() -> void:
	if Engine.is_editor_hint() or is_instance_valid(_reflection_viewport):
		return
	_reflection_viewport = SubViewport.new()
	_reflection_viewport.name = "ReflectionViewport"
	_reflection_viewport.own_world_3d = false
	_reflection_viewport.disable_3d = false
	_reflection_viewport.handle_input_locally = false
	_reflection_viewport.gui_disable_input = true
	_reflection_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_reflection_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_reflection_viewport, false, Node.INTERNAL_MODE_BACK)

	_reflection_camera = Camera3D.new()
	_reflection_camera.name = "ReflectedCamera"
	_reflection_camera.current = true
	_reflection_viewport.add_child(_reflection_camera)
	_resize_viewport()
	_update_layer_masks()

	_surface_material.set_shader_parameter("reflection_texture", _reflection_viewport.get_texture())
	update_reflection()


func _sync_reflected_camera(camera: Camera3D) -> void:
	var virtual_eye := reflect_point(camera.global_position)
	var mirror_center := global_transform * Vector3(0.0, 0.0, frame_depth * 0.52)
	var view_direction := mirror_center - virtual_eye
	if view_direction.length_squared() < 0.000001:
		view_direction = global_basis.z.normalized()
	var plane_normal := get_mirror_plane().normal
	var source_up := camera.global_basis.y.normalized()
	var reflected_up := (source_up - plane_normal * (2.0 * source_up.dot(plane_normal))).normalized()
	if absf(reflected_up.dot(view_direction.normalized())) > 0.98:
		reflected_up = global_basis.y.normalized()
	_reflection_camera.global_transform = Transform3D(
		Basis.looking_at(view_direction.normalized(), reflected_up),
		virtual_eye
	)

	var eye_to_plane := maxf(absf(get_mirror_plane().distance_to(virtual_eye)), 0.05)
	var projection_near := maxf(eye_to_plane - near_plane_padding, 0.01)
	_reflection_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_reflection_camera.size = mirror_size.y * projection_near / eye_to_plane
	_reflection_camera.frustum_offset = Vector2.ZERO
	_reflection_camera.near = projection_near
	_reflection_camera.far = maxf(reflection_far, projection_near + 1.0)
	_reflection_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_reflection_camera.attributes = camera.attributes
	_reflection_camera.environment = camera.environment
	_reflection_camera.cull_mask = camera.cull_mask & ~(1 << (reflection_layer - 1))


func _ensure_visuals() -> void:
	if is_instance_valid(_surface):
		return
	_surface = _make_mesh_instance("MirrorSurface")
	_backing = _make_mesh_instance("Backing")
	_frame_top = _make_mesh_instance("FrameTop")
	_frame_bottom = _make_mesh_instance("FrameBottom")
	_frame_left = _make_mesh_instance("FrameLeft")
	_frame_right = _make_mesh_instance("FrameRight")
	_handle = _make_mesh_instance("Handle")

	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D reflection_texture : source_color, filter_linear;
void fragment() {
	vec2 mirror_uv = vec2(1.0 - UV.x, UV.y);
	ALBEDO = texture(reflection_texture, mirror_uv).rgb;
	ROUGHNESS = 0.0;
}"""
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = shader
	_surface.material_override = _surface_material

	_frame_material = StandardMaterial3D.new()
	_frame_material.metallic = 0.45
	_frame_material.roughness = 0.28
	_backing_material = StandardMaterial3D.new()
	_backing_material.metallic = 0.15
	_backing_material.roughness = 0.6
	for item in [_frame_top, _frame_bottom, _frame_left, _frame_right, _handle]:
		item.material_override = _frame_material
	_backing.material_override = _backing_material


func _make_mesh_instance(node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	add_child(instance, false, Node.INTERNAL_MODE_BACK)
	return instance


func _update_geometry() -> void:
	if not is_instance_valid(_surface):
		return
	var surface_mesh := QuadMesh.new()
	surface_mesh.size = mirror_size
	_surface.mesh = surface_mesh
	_surface.position = Vector3(0.0, 0.0, frame_depth * 0.52)

	_set_box(_backing, Vector3(mirror_size.x, mirror_size.y, frame_depth * 0.55))
	_backing.position = Vector3(0.0, 0.0, -frame_depth * 0.25)

	var horizontal_size := Vector3(mirror_size.x + frame_width * 2.0, frame_width, frame_depth)
	var vertical_size := Vector3(frame_width, mirror_size.y, frame_depth)
	_set_box(_frame_top, horizontal_size)
	_set_box(_frame_bottom, horizontal_size)
	_set_box(_frame_left, vertical_size)
	_set_box(_frame_right, vertical_size)
	_frame_top.position = Vector3(0.0, mirror_size.y * 0.5 + frame_width * 0.5, 0.0)
	_frame_bottom.position = Vector3(0.0, -mirror_size.y * 0.5 - frame_width * 0.5, 0.0)
	_frame_left.position = Vector3(-mirror_size.x * 0.5 - frame_width * 0.5, 0.0, 0.0)
	_frame_right.position = Vector3(mirror_size.x * 0.5 + frame_width * 0.5, 0.0, 0.0)

	_set_box(_handle, Vector3(maxf(frame_width * 1.35, 0.045), handle_length, frame_depth * 0.9))
	_handle.position = Vector3(0.0, -mirror_size.y * 0.5 - frame_width - handle_length * 0.5, -frame_depth * 0.05)
	_handle.visible = show_handle


func _set_box(instance: MeshInstance3D, size: Vector3) -> void:
	if not is_instance_valid(instance):
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(size.x, 0.001), maxf(size.y, 0.001), maxf(size.z, 0.001))
	instance.mesh = mesh


func _update_materials() -> void:
	if is_instance_valid(_frame_material):
		_frame_material.albedo_color = frame_color
	if is_instance_valid(_backing_material):
		_backing_material.albedo_color = backing_color


func _update_layer_masks() -> void:
	for item in [_surface, _backing, _frame_top, _frame_bottom, _frame_left, _frame_right, _handle]:
		if is_instance_valid(item):
			item.layers = 1 << (reflection_layer - 1)
	if is_instance_valid(_reflection_camera):
		_reflection_camera.cull_mask &= ~(1 << (reflection_layer - 1))


func _resize_viewport() -> void:
	if not is_instance_valid(_reflection_viewport):
		return
	var aspect := mirror_size.y / mirror_size.x
	_reflection_viewport.size = Vector2i(texture_width, maxi(int(round(texture_width * aspect)), 64))
