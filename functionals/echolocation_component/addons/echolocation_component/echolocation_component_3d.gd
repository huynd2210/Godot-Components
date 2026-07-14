@tool
class_name EcholocationComponent3D
extends Node3D
## Camera-driven echolocation which reveals collision contours instead of surfaces.
##
## In cone mode, the component casts a grid of rays along local -Z. In sphere
## mode, the same grid is distributed around the full 360-degree environment.
## It keeps samples only at depth, collider, hit/miss, and surface-normal
## discontinuities. Those samples appear as an expanding wave reaches them,
## hold briefly, and fade away.

enum ScanShape {
	CONE,
	SPHERE,
}

signal echo_emitted(detected_edges: int)
signal echo_finished
signal echo_cleared

@export_category("Echo Scan")
@export var scan_shape: ScanShape = ScanShape.SPHERE
@export_range(8, 256, 1) var grid_width: int = 96
@export_range(8, 144, 1) var grid_height: int = 54
@export_range(16, 128, 1) var sphere_face_resolution: int = 96
@export_range(0.0, 12.0, 0.5, "suffix:deg") var sphere_face_overlap_degrees: float = 3.0
@export_range(1.0, 170.0, 0.1, "suffix:deg") var horizontal_fov_degrees: float = 88.0
@export_range(1.0, 170.0, 0.1, "suffix:deg") var vertical_fov_degrees: float = 58.0
@export_range(1.0, 200.0, 0.1, "suffix:m") var max_range: float = 42.0
@export_flags_3d_physics var collision_mask: int = 1
@export var collide_with_bodies: bool = true
@export var collide_with_areas: bool = false

@export_category("Contour Detection")
@export_range(0.01, 10.0, 0.01, "suffix:m") var depth_edge_threshold: float = 0.7
@export_range(0.01, 2.0, 0.01) var relative_depth_edge_threshold: float = 0.28
@export_range(1.0, 90.0, 0.5, "suffix:deg") var normal_edge_angle_degrees: float = 32.0

@export_category("Reveal")
@export_range(1.0, 100.0, 0.1, "suffix:m/s") var propagation_speed: float = 22.0
@export_range(0.0, 20.0, 0.1, "suffix:s") var outline_hold_time: float = 2.8
@export_range(0.0, 5.0, 0.05, "suffix:s") var fade_duration: float = 0.75
@export_range(0.002, 0.5, 0.001, "suffix:m") var point_size: float = 0.035
@export var echo_color: Color = Color(0.22, 1.0, 0.72, 0.95)
@export var show_pulse_shell: bool = true
@export_range(0.05, 1.0, 0.01) var pulse_shell_opacity: float = 0.5
@export_range(0.05, 2.0, 0.05, "suffix:m") var pulse_shell_thickness: float = 0.45
@export_range(0.01, 0.5, 0.01, "suffix:m") var pulse_point_size: float = 0.11

@export_category("Audio")
@export var sound_enabled: bool = true
@export_range(-80.0, 12.0, 0.1, "suffix:dB") var sound_volume_db: float = -8.0
@export var echo_sound: AudioStream

var outline_point_count: int:
	get:
		return _outline_point_count

var detected_edge_count: int:
	get:
		return _detected_edge_count

var is_echo_active: bool:
	get:
		return _echo_active

var pulse_radius: float:
	get:
		return minf(_echo_age * propagation_speed, max_range) if _echo_active else 0.0

var wavefront_point_count: int:
	get:
		return _wavefront_point_count

var _outline_point_count := 0
var _wavefront_point_count := 0
var _detected_edge_count := 0
var _echo_active := false
var _echo_age := 0.0
var _last_reveal_time := 0.0
var _pending_cursor := 0
var _pending_edges: Array[Dictionary] = []
var _wave_hits: Array[Dictionary] = []
var _excluded_rids: Array[RID] = []
var _cloud_aabb := AABB()
var _has_cloud_aabb := false

var _point_renderer: MultiMeshInstance3D
var _point_multimesh: MultiMesh
var _point_material: StandardMaterial3D
var _wave_renderer: MultiMeshInstance3D
var _wave_multimesh: MultiMesh
var _wave_material: StandardMaterial3D
var _sound_player: AudioStreamPlayer3D
var _generated_echo_sound: AudioStreamWAV


func _ready() -> void:
	_build_renderers()
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if not _echo_active:
		return
	_echo_age += delta
	var current_radius := minf(_echo_age * propagation_speed, max_range)

	while _pending_cursor < _pending_edges.size():
		var edge: Dictionary = _pending_edges[_pending_cursor]
		if float(edge["distance"]) > current_radius:
			break
		_paint_outline_point(edge["position"])
		_pending_cursor += 1

	_update_surface_wavefront(current_radius)
	var fade_start := _last_reveal_time + maxf(outline_hold_time - fade_duration, 0.0)
	if _echo_age >= fade_start and fade_duration > 0.0:
		var fade := clampf((_echo_age - fade_start) / fade_duration, 0.0, 1.0)
		_point_material.albedo_color.a = echo_color.a * (1.0 - fade)

	if _echo_age >= _last_reveal_time + outline_hold_time:
		clear_echo(false)
		echo_finished.emit()


## Emits one echo immediately and returns the number of detected contour samples.
func emit_echo() -> int:
	if not is_inside_tree() or get_world_3d() == null:
		return 0
	if _point_multimesh == null:
		_build_renderers()
	clear_echo(false)

	var origin := global_position
	var sample_width := sphere_face_resolution if scan_shape == ScanShape.SPHERE else grid_width
	var sample_height := sphere_face_resolution if scan_shape == ScanShape.SPHERE else grid_height
	var face_count := 6 if scan_shape == ScanShape.SPHERE else 1
	var face_sample_count := sample_width * sample_height
	var total := face_sample_count * face_count
	_ensure_renderer_capacity(total)
	var hit_flags := PackedByteArray()
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var distances := PackedFloat32Array()
	var collider_ids := PackedInt64Array()
	hit_flags.resize(total)
	positions.resize(total)
	normals.resize(total)
	distances.resize(total)
	collider_ids.resize(total)

	var space_state := get_world_3d().direct_space_state
	for face in face_count:
		for y in sample_height:
			var v := (float(y) + 0.5) / float(sample_height)
			for x in sample_width:
				var u := (float(x) + 0.5) / float(sample_width)
				var index := face * face_sample_count + y * sample_width + x
				var local_direction := (
					_get_sphere_face_direction(face, u, v)
					if scan_shape == ScanShape.SPHERE
					else _get_cone_direction(u, v)
				)
				var world_direction := (global_basis * local_direction).normalized()
				var query := PhysicsRayQueryParameters3D.create(origin, origin + world_direction * max_range, collision_mask)
				query.collide_with_bodies = collide_with_bodies
				query.collide_with_areas = collide_with_areas
				query.exclude = _excluded_rids
				var hit := space_state.intersect_ray(query)
				if hit.is_empty():
					continue
				hit_flags[index] = 1
				positions[index] = hit["position"]
				normals[index] = hit["normal"]
				distances[index] = origin.distance_to(hit["position"])
				collider_ids[index] = int(hit["collider_id"])
				_wave_hits.append({"position": hit["position"], "distance": distances[index]})

	var normal_dot_threshold := cos(deg_to_rad(normal_edge_angle_degrees))
	var farthest_edge := 0.0
	var contour_cells: Dictionary = {}
	var merge_distance := maxf(point_size * 1.5, 0.045)
	for face in face_count:
		var face_offset := face * face_sample_count
		for y in sample_height:
			for x in sample_width:
				var index := face_offset + y * sample_width + x
				if hit_flags[index] == 0:
					continue
				if not _sample_is_contour(index, x, y, sample_width, sample_height, hit_flags, normals, distances, collider_ids, normal_dot_threshold):
					continue
				# Adjacent sphere faces overlap slightly so silhouettes never disappear
				# at cube seams. Merge those overlapping samples back into one crisp dot.
				var position := positions[index]
				var cell := Vector3i(
					roundi(position.x / merge_distance),
					roundi(position.y / merge_distance),
					roundi(position.z / merge_distance)
				)
				if scan_shape == ScanShape.SPHERE and contour_cells.has(cell):
					continue
				contour_cells[cell] = true
				var distance := float(distances[index])
				_pending_edges.append({"position": position, "distance": distance})
				farthest_edge = maxf(farthest_edge, distance)

	_pending_edges.sort_custom(_edge_distance_less)
	_detected_edge_count = _pending_edges.size()
	_echo_age = 0.0
	_pending_cursor = 0
	_last_reveal_time = farthest_edge / maxf(propagation_speed, 0.001)
	_echo_active = true
	_point_material.albedo_color = Color(1.0, 1.0, 1.0, echo_color.a)
	_start_surface_wavefront()
	_play_echo_sound()
	echo_emitted.emit(_detected_edge_count)
	return _detected_edge_count


## Clears visible contours and cancels the active echo.
func clear_echo(emit_signal := true) -> void:
	_outline_point_count = 0
	_wavefront_point_count = 0
	_pending_cursor = 0
	_pending_edges.clear()
	_wave_hits.clear()
	_echo_active = false
	_echo_age = 0.0
	_last_reveal_time = 0.0
	_cloud_aabb = AABB()
	_has_cloud_aabb = false
	if _point_multimesh != null:
		_point_multimesh.visible_instance_count = 0
	if _point_renderer != null:
		_point_renderer.custom_aabb = AABB()
	if _wave_multimesh != null:
		_wave_multimesh.visible_instance_count = 0
	if _wave_renderer != null:
		_wave_renderer.visible = false
	if emit_signal:
		echo_cleared.emit()


func add_exclusion(body: CollisionObject3D) -> void:
	if body != null and not _excluded_rids.has(body.get_rid()):
		_excluded_rids.append(body.get_rid())


func remove_exclusion(body: CollisionObject3D) -> void:
	if body != null:
		_excluded_rids.erase(body.get_rid())


func clear_exclusions() -> void:
	_excluded_rids.clear()


func _get_cone_direction(u: float, v: float) -> Vector3:
	var x_extent := tan(deg_to_rad(horizontal_fov_degrees * 0.5))
	var y_extent := tan(deg_to_rad(vertical_fov_degrees * 0.5))
	return Vector3(
		(u * 2.0 - 1.0) * x_extent,
		(v * 2.0 - 1.0) * y_extent,
		-1.0
	).normalized()


func _get_sphere_face_direction(face: int, u: float, v: float) -> Vector3:
	# Cubemap sampling avoids the squeezed poles and uneven angular density of
	# latitude/longitude sampling. Every direction receives comparable detail.
	var face_extent := tan(deg_to_rad(45.0 + sphere_face_overlap_degrees))
	var horizontal := (u * 2.0 - 1.0) * face_extent
	var vertical := (v * 2.0 - 1.0) * face_extent
	match face:
		0: return Vector3(1.0, -vertical, -horizontal).normalized() # +X
		1: return Vector3(-1.0, -vertical, horizontal).normalized() # -X
		2: return Vector3(horizontal, 1.0, vertical).normalized() # +Y
		3: return Vector3(horizontal, -1.0, -vertical).normalized() # -Y
		4: return Vector3(horizontal, -vertical, 1.0).normalized() # +Z
		_: return Vector3(-horizontal, -vertical, -1.0).normalized() # -Z


func _sample_is_contour(
	index: int,
	x: int,
	y: int,
	sample_width: int,
	sample_height: int,
	hit_flags: PackedByteArray,
	normals: PackedVector3Array,
	distances: PackedFloat32Array,
	collider_ids: PackedInt64Array,
	normal_dot_threshold: float
) -> bool:
	if x > 0 and _neighbor_is_discontinuous(index, index - 1, hit_flags, normals, distances, collider_ids, normal_dot_threshold):
		return true
	if x + 1 < sample_width and _neighbor_is_discontinuous(index, index + 1, hit_flags, normals, distances, collider_ids, normal_dot_threshold):
		return true
	if y > 0 and _neighbor_is_discontinuous(index, index - sample_width, hit_flags, normals, distances, collider_ids, normal_dot_threshold):
		return true
	if y + 1 < sample_height and _neighbor_is_discontinuous(index, index + sample_width, hit_flags, normals, distances, collider_ids, normal_dot_threshold):
		return true
	return false


func _neighbor_is_discontinuous(
	index: int,
	neighbor: int,
	hit_flags: PackedByteArray,
	normals: PackedVector3Array,
	distances: PackedFloat32Array,
	collider_ids: PackedInt64Array,
	normal_dot_threshold: float
) -> bool:
	if hit_flags[neighbor] == 0:
		return true
	if collider_ids[index] != collider_ids[neighbor]:
		return true
	var depth_delta := absf(distances[index] - distances[neighbor])
	var near_depth := maxf(minf(distances[index], distances[neighbor]), 0.001)
	if depth_delta >= depth_edge_threshold and depth_delta / near_depth >= relative_depth_edge_threshold:
		return true
	return normals[index].dot(normals[neighbor]) <= normal_dot_threshold


func _edge_distance_less(a: Dictionary, b: Dictionary) -> bool:
	return float(a["distance"]) < float(b["distance"])


func _build_renderers() -> void:
	if _point_renderer != null and is_instance_valid(_point_renderer):
		return
	var sphere_capacity := sphere_face_resolution * sphere_face_resolution * 6
	var capacity := maxi(maxi(grid_width * grid_height, sphere_capacity), 1)
	_point_multimesh = MultiMesh.new()
	_point_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_point_multimesh.use_colors = true
	_point_multimesh.instance_count = capacity
	_point_multimesh.visible_instance_count = 0

	_point_material = StandardMaterial3D.new()
	_point_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_point_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_point_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_point_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_point_material.billboard_keep_scale = true
	_point_material.vertex_color_use_as_albedo = true
	_point_material.albedo_color = Color.WHITE

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _point_material
	_point_multimesh.mesh = quad
	_point_renderer = MultiMeshInstance3D.new()
	_point_renderer.name = "EchoContours"
	_point_renderer.multimesh = _point_multimesh
	add_child(_point_renderer, false, Node.INTERNAL_MODE_BACK)
	_point_renderer.top_level = true
	_point_renderer.global_transform = Transform3D.IDENTITY

	_wave_multimesh = MultiMesh.new()
	_wave_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_wave_multimesh.use_colors = true
	_wave_multimesh.instance_count = capacity
	_wave_multimesh.visible_instance_count = 0
	_wave_material = StandardMaterial3D.new()
	_wave_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wave_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wave_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_wave_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_wave_material.billboard_keep_scale = true
	_wave_material.vertex_color_use_as_albedo = true
	_wave_material.albedo_color = Color.WHITE
	var wave_quad := QuadMesh.new()
	wave_quad.size = Vector2.ONE
	wave_quad.material = _wave_material
	_wave_multimesh.mesh = wave_quad
	_wave_renderer = MultiMeshInstance3D.new()
	_wave_renderer.name = "EchoSurfaceWavefront"
	_wave_renderer.multimesh = _wave_multimesh
	_wave_renderer.visible = false
	add_child(_wave_renderer, false, Node.INTERNAL_MODE_BACK)
	_wave_renderer.top_level = true
	_wave_renderer.global_transform = Transform3D.IDENTITY
	_wave_renderer.custom_aabb = AABB(Vector3.ONE * -max_range, Vector3.ONE * max_range * 2.0)

	_generated_echo_sound = _make_echo_sound()
	_sound_player = AudioStreamPlayer3D.new()
	_sound_player.name = "EchoAudio"
	_sound_player.volume_db = sound_volume_db
	_sound_player.max_distance = 35.0
	_sound_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	add_child(_sound_player, false, Node.INTERNAL_MODE_BACK)


func _ensure_renderer_capacity(required_capacity: int) -> void:
	if _point_multimesh.instance_count < required_capacity:
		_point_multimesh.visible_instance_count = 0
		_point_multimesh.instance_count = required_capacity
	if _wave_multimesh.instance_count < required_capacity:
		_wave_multimesh.visible_instance_count = 0
		_wave_multimesh.instance_count = required_capacity


func _paint_outline_point(world_position: Vector3) -> void:
	if _outline_point_count >= _point_multimesh.instance_count:
		return
	var basis := Basis.IDENTITY.scaled(Vector3.ONE * point_size)
	_point_multimesh.set_instance_transform(_outline_point_count, Transform3D(basis, world_position))
	_point_multimesh.set_instance_color(_outline_point_count, echo_color)
	_outline_point_count += 1
	_point_multimesh.visible_instance_count = _outline_point_count
	var margin := Vector3.ONE * point_size
	if _has_cloud_aabb:
		_cloud_aabb = _cloud_aabb.expand(world_position - margin)
		_cloud_aabb = _cloud_aabb.expand(world_position + margin)
	else:
		_cloud_aabb = AABB(world_position - margin, margin * 2.0)
		_has_cloud_aabb = true
	_point_renderer.custom_aabb = _cloud_aabb


func _start_surface_wavefront() -> void:
	if not show_pulse_shell:
		return
	_wave_renderer.visible = true


func _update_surface_wavefront(radius: float) -> void:
	if not show_pulse_shell or _wave_renderer == null:
		return
	var half_thickness := maxf(pulse_shell_thickness * 0.5, 0.001)
	var visible_count := 0
	for hit in _wave_hits:
		var distance_delta := absf(float(hit["distance"]) - radius)
		if distance_delta > half_thickness:
			continue
		if visible_count >= _wave_multimesh.instance_count:
			break
		var strength := 1.0 - distance_delta / half_thickness
		var size := pulse_point_size * lerpf(0.7, 1.25, strength)
		var basis := Basis.IDENTITY.scaled(Vector3.ONE * size)
		_wave_multimesh.set_instance_transform(visible_count, Transform3D(basis, hit["position"]))
		_wave_multimesh.set_instance_color(visible_count, Color(echo_color.r, echo_color.g, echo_color.b, pulse_shell_opacity * strength))
		visible_count += 1
	_wave_multimesh.visible_instance_count = visible_count
	_wave_renderer.visible = visible_count > 0
	_wavefront_point_count = visible_count


func _play_echo_sound() -> void:
	if not sound_enabled or _sound_player == null:
		return
	_sound_player.volume_db = sound_volume_db
	_sound_player.stream = echo_sound if echo_sound != null else _generated_echo_sound
	_sound_player.play()


func _make_echo_sound() -> AudioStreamWAV:
	var sample_rate := 44100
	var duration := 0.32
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase := 0.0
	for i in sample_count:
		var t := float(i) / float(sample_count)
		var frequency := lerpf(920.0, 310.0, t)
		phase += TAU * frequency / float(sample_rate)
		var attack := minf(t / 0.025, 1.0)
		var envelope := attack * pow(1.0 - t, 2.8)
		var value := (sin(phase) * 0.72 + sin(phase * 0.5) * 0.22) * envelope
		bytes.encode_s16(i * 2, clampi(int(value * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav
