@tool
class_name LidarComponent3D
extends Node3D
## A reusable ray-based LiDAR scanner which paints persistent points on hit surfaces.
##
## Add this node beneath a Camera3D (or any aiming Node3D), configure its collision
## mask, then call scan_once(). Points are stored in world space so they remain on
## the scanned geometry as the scanner moves.

signal scan_finished(hits: int, rays: int)
signal point_cloud_cleared

@export_category("Scanning")
@export_range(1, 4096, 1) var beams_per_scan: int = 100
@export_range(0.1, 500.0, 0.1, "suffix:m") var max_range: float = 40.0
@export_range(0.0, 170.0, 0.1, "suffix:deg") var horizontal_fov_degrees: float = 72.0
@export_range(0.0, 170.0, 0.1, "suffix:deg") var vertical_fov_degrees: float = 52.0
@export var random_seed: int = -1
@export_flags_3d_physics var collision_mask: int = 1
@export var collide_with_bodies: bool = true
@export var collide_with_areas: bool = false

@export_category("Automatic Scanning")
@export var auto_scan: bool = false
@export_range(0.1, 60.0, 0.1, "suffix: scans/s") var scans_per_second: float = 12.0

@export_category("Painted Points")
@export_range(1, 1000000, 1) var max_points: int = 50000
@export_range(0.002, 1.0, 0.001, "suffix:m") var point_size: float = 0.018
@export_range(0.0, 0.2, 0.001, "suffix:m") var surface_offset: float = 0.008
@export var point_color: Color = Color(0.08, 0.8, 1.0, 0.92)

@export_category("Beam Trails")
@export var show_beams: bool = true
@export_range(0.0, 2.0, 0.01, "suffix:s") var beam_lifetime: float = 0.07
@export var beam_color: Color = Color(0.05, 0.75, 1.0, 0.28)

@export_category("Audio")
@export var sound_enabled: bool = true
@export_range(-80.0, 12.0, 0.1, "suffix:dB") var sound_volume_db: float = -10.0
@export var scan_sound: AudioStream
@export var clear_sound: AudioStream

var point_count: int:
	get:
		return _point_count

var _point_count := 0
var _write_cursor := 0
var _scan_accumulator := 0.0
var _beam_time_left := 0.0
var _beam_targets: PackedVector3Array = []
var _excluded_rids: Array[RID] = []
var _cloud_aabb := AABB()
var _has_cloud_aabb := false
var _rng := RandomNumberGenerator.new()

var _point_renderer: MultiMeshInstance3D
var _point_multimesh: MultiMesh
var _beam_renderer: MeshInstance3D
var _beam_mesh: ImmediateMesh
var _beam_material: StandardMaterial3D
var _sound_player: AudioStreamPlayer3D
var _generated_scan_sound: AudioStreamWAV
var _generated_clear_sound: AudioStreamWAV


func _ready() -> void:
	if random_seed < 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	_build_renderers()
	set_physics_process(not Engine.is_editor_hint())
	set_process(not Engine.is_editor_hint())


func _physics_process(delta: float) -> void:
	if not auto_scan:
		_scan_accumulator = 0.0
		return
	_scan_accumulator += delta
	var interval := 1.0 / maxf(scans_per_second, 0.1)
	var scans_this_frame := 0
	while _scan_accumulator >= interval and scans_this_frame < 4:
		_scan_accumulator -= interval
		scan_once()
		scans_this_frame += 1


func _process(delta: float) -> void:
	if _beam_time_left <= 0.0:
		return
	# Hit endpoints remain fixed on their surfaces, but the start of every visible
	# beam follows the live muzzle so movement never leaves rays behind the gun.
	_render_active_beams()
	_beam_time_left -= delta
	if _beam_time_left <= 0.0 and _beam_mesh != null:
		_beam_mesh.clear_surfaces()
		_beam_targets.clear()


## Fires one batch immediately. The scanner aims along its local -Z axis.
## Returns the number of rays which hit a collision surface.
func scan_once() -> int:
	if not is_inside_tree() or get_world_3d() == null:
		return 0
	if _point_multimesh == null:
		_build_renderers()
	_play_sound(scan_sound if scan_sound != null else _generated_scan_sound)

	var ray_count := maxi(beams_per_scan, 1)
	var origin := global_position
	var space_state := get_world_3d().direct_space_state
	var beam_segments: PackedVector3Array = []
	var hit_count := 0

	for beam_index in ray_count:
		var local_direction := _sample_direction()
		var world_direction := (global_basis * local_direction).normalized()
		var target := origin + world_direction * max_range
		var query := PhysicsRayQueryParameters3D.create(origin, target, collision_mask)
		query.collide_with_bodies = collide_with_bodies
		query.collide_with_areas = collide_with_areas
		query.exclude = _excluded_rids
		var hit := space_state.intersect_ray(query)

		if hit.is_empty():
			if show_beams:
				beam_segments.append(origin)
				beam_segments.append(target)
			continue

		var hit_position: Vector3 = hit["position"]
		var hit_normal: Vector3 = hit["normal"]
		_paint_point(hit_position + hit_normal * surface_offset, origin.distance_to(hit_position))
		hit_count += 1
		if show_beams:
			beam_segments.append(origin)
			beam_segments.append(hit_position)

	if show_beams:
		_draw_beams(beam_segments)
	scan_finished.emit(hit_count, ray_count)
	return hit_count


## Removes every painted LiDAR point.
func clear_points() -> void:
	_point_count = 0
	_write_cursor = 0
	_cloud_aabb = AABB()
	_has_cloud_aabb = false
	if _point_multimesh != null:
		_point_multimesh.visible_instance_count = 0
	if _point_renderer != null:
		_point_renderer.custom_aabb = AABB()
	_play_sound(clear_sound if clear_sound != null else _generated_clear_sound)
	point_cloud_cleared.emit()


## Prevents a body (usually the player carrying the scanner) from being scanned.
func add_exclusion(body: CollisionObject3D) -> void:
	if body != null and not _excluded_rids.has(body.get_rid()):
		_excluded_rids.append(body.get_rid())


func remove_exclusion(body: CollisionObject3D) -> void:
	if body != null:
		_excluded_rids.erase(body.get_rid())


func clear_exclusions() -> void:
	_excluded_rids.clear()


func _build_renderers() -> void:
	if _point_renderer != null and is_instance_valid(_point_renderer):
		return

	max_points = maxi(max_points, 1)
	_point_multimesh = MultiMesh.new()
	_point_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_point_multimesh.use_colors = true
	_point_multimesh.instance_count = max_points
	_point_multimesh.visible_instance_count = 0

	var point_material := StandardMaterial3D.new()
	point_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	point_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Alpha blending preserves the chosen color as points accumulate. Additive
	# blending quickly burns dense scans to white.
	point_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	point_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	point_material.billboard_keep_scale = true
	point_material.vertex_color_use_as_albedo = true
	point_material.albedo_color = Color.WHITE
	point_material.no_depth_test = false

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = point_material
	_point_multimesh.mesh = quad

	_point_renderer = MultiMeshInstance3D.new()
	_point_renderer.name = "LidarPointCloud"
	_point_renderer.multimesh = _point_multimesh
	add_child(_point_renderer, false, Node.INTERNAL_MODE_BACK)
	_point_renderer.top_level = true
	_point_renderer.global_transform = Transform3D.IDENTITY

	_beam_mesh = ImmediateMesh.new()
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_material.vertex_color_use_as_albedo = true
	_beam_material.no_depth_test = true

	_beam_renderer = MeshInstance3D.new()
	_beam_renderer.name = "LidarBeamTrails"
	_beam_renderer.mesh = _beam_mesh
	add_child(_beam_renderer, false, Node.INTERNAL_MODE_BACK)
	_beam_renderer.top_level = true
	_beam_renderer.global_transform = Transform3D.IDENTITY

	_generated_scan_sound = _make_scan_sound()
	_generated_clear_sound = _make_clear_sound()
	_sound_player = AudioStreamPlayer3D.new()
	_sound_player.name = "LidarAudio"
	_sound_player.volume_db = sound_volume_db
	_sound_player.max_distance = 30.0
	_sound_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	add_child(_sound_player, false, Node.INTERNAL_MODE_BACK)


func _sample_direction() -> Vector3:
	# Uniform random samples across an elliptical cone. sqrt() prevents points from
	# clustering at the cone's center.
	var angle := _rng.randf() * TAU
	var radius := sqrt(_rng.randf())
	var x_extent := tan(deg_to_rad(horizontal_fov_degrees * 0.5))
	var y_extent := tan(deg_to_rad(vertical_fov_degrees * 0.5))
	return Vector3(
		cos(angle) * radius * x_extent,
		sin(angle) * radius * y_extent,
		-1.0
	).normalized()


func _paint_point(world_position: Vector3, _distance: float) -> void:
	if _point_multimesh == null:
		return
	var scale_basis := Basis.IDENTITY.scaled(Vector3.ONE * point_size)
	_point_multimesh.set_instance_transform(_write_cursor, Transform3D(scale_basis, world_position))
	_point_multimesh.set_instance_color(_write_cursor, point_color)
	var margin := Vector3.ONE * point_size
	if _has_cloud_aabb:
		_cloud_aabb = _cloud_aabb.expand(world_position - margin)
		_cloud_aabb = _cloud_aabb.expand(world_position + margin)
	else:
		_cloud_aabb = AABB(world_position - margin, margin * 2.0)
		_has_cloud_aabb = true
	_point_renderer.custom_aabb = _cloud_aabb
	_write_cursor = (_write_cursor + 1) % max_points
	_point_count = mini(_point_count + 1, max_points)
	_point_multimesh.visible_instance_count = _point_count


func _draw_beams(segments: PackedVector3Array) -> void:
	if _beam_mesh == null:
		return
	_beam_mesh.clear_surfaces()
	_beam_targets.clear()
	if segments.is_empty() or beam_lifetime <= 0.0:
		return
	for index in range(1, segments.size(), 2):
		_beam_targets.append(segments[index])
	_render_active_beams()
	_beam_time_left = beam_lifetime


func _render_active_beams() -> void:
	if _beam_mesh == null or _beam_targets.is_empty():
		return
	_beam_mesh.clear_surfaces()
	_beam_material.albedo_color = beam_color
	_beam_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _beam_material)
	var muzzle_position := global_position
	for target in _beam_targets:
		_beam_mesh.surface_set_color(beam_color)
		_beam_mesh.surface_add_vertex(muzzle_position)
		_beam_mesh.surface_set_color(beam_color)
		_beam_mesh.surface_add_vertex(target)
	_beam_mesh.surface_end()


func _play_sound(stream: AudioStream) -> void:
	if not sound_enabled or stream == null or _sound_player == null:
		return
	_sound_player.volume_db = sound_volume_db
	_sound_player.stream = stream
	_sound_player.play()


func _make_scan_sound() -> AudioStreamWAV:
	# A short high-to-low electronic chirp with a tiny noise transient.
	var sample_rate := 44100
	var duration := 0.055
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase := 0.0
	var noise := RandomNumberGenerator.new()
	noise.seed = 71237
	for i in sample_count:
		var t := float(i) / float(sample_count)
		var frequency := lerpf(1850.0, 620.0, t)
		phase += TAU * frequency / float(sample_rate)
		var envelope := pow(1.0 - t, 2.4)
		var value := (sin(phase) * 0.72 + noise.randf_range(-0.16, 0.16)) * envelope
		bytes.encode_s16(i * 2, clampi(int(value * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav


func _make_clear_sound() -> AudioStreamWAV:
	# A longer descending confirmation tone for clearing the accumulated image.
	var sample_rate := 44100
	var duration := 0.18
	var sample_count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase := 0.0
	for i in sample_count:
		var t := float(i) / float(sample_count)
		var frequency := lerpf(780.0, 170.0, t)
		phase += TAU * frequency / float(sample_rate)
		var envelope := sin(PI * t) * (1.0 - t)
		var value := sin(phase) * envelope * 0.65
		bytes.encode_s16(i * 2, clampi(int(value * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav
