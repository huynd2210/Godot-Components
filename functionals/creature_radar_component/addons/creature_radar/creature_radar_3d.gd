@tool
class_name CreatureRadar3D
extends Node3D
## Reusable, opt-in creature detector. Add RadarTarget3D beneath detectable creatures.

const RadarTarget := preload("res://addons/creature_radar/radar_target_3d.gd")

signal contact_entered(target: Node3D)
signal contact_updated(target: Node3D, distance: float, local_direction: Vector3)
signal contact_exited(target: Node3D)
signal scan_finished(contacts: Array[Node3D])

@export_range(0.1, 10000.0, 0.1, "suffix:m") var detection_range := 30.0
@export_range(0.1, 60.0, 0.1, "suffix: scans/s") var scans_per_second := 5.0
@export_range(0.0, 360.0, 0.1, "suffix:deg") var horizontal_fov_degrees := 360.0
@export_range(0.0, 180.0, 0.1, "suffix:deg") var vertical_fov_degrees := 180.0
@export var auto_scan := true
@export var registration_group: StringName = &"creature_radar_targets"
@export var detected_categories: Array[StringName] = []
@export var minimum_signature_strength := 0.0

var contacts: Array[Node3D]:
	get:
		return _contacts.duplicate()

var _contacts: Array[Node3D] = []
var _scan_accumulator := 0.0


func _ready() -> void:
	set_physics_process(not Engine.is_editor_hint())


func _physics_process(delta: float) -> void:
	if not auto_scan:
		_scan_accumulator = 0.0
		return
	_scan_accumulator += delta
	var interval := 1.0 / maxf(scans_per_second, 0.1)
	if _scan_accumulator >= interval:
		_scan_accumulator = fmod(_scan_accumulator, interval)
		scan_now()


## Immediately refreshes and returns all currently detectable targets.
func scan_now() -> Array[Node3D]:
	var found: Array[Node3D] = []
	if not is_inside_tree():
		return found
	for node in get_tree().get_nodes_in_group(registration_group):
		if node is RadarTarget and _can_detect(node):
			found.append(node)

	found.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)

	for previous in _contacts:
		if is_instance_valid(previous) and not found.has(previous):
			contact_exited.emit(previous)
	for target in found:
		if not _contacts.has(target):
			contact_entered.emit(target)
		var offset := target.global_position - global_position
		contact_updated.emit(target, offset.length(), global_basis.inverse() * offset.normalized())
	_contacts = found
	scan_finished.emit(contacts)
	return contacts


func has_contact(target: Node3D) -> bool:
	return _contacts.has(target)


func get_nearest_contact() -> Node3D:
	return _contacts[0] if not _contacts.is_empty() else null


func clear_contacts() -> void:
	for target in _contacts:
		if is_instance_valid(target):
			contact_exited.emit(target)
	_contacts.clear()


func _can_detect(target: Node3D) -> bool:
	if not target.detectable or target.signature_strength < minimum_signature_strength:
		return false
	if not detected_categories.is_empty() and not detected_categories.has(target.category):
		return false
	var local_offset := global_basis.inverse() * (target.global_position - global_position)
	if local_offset.length_squared() > detection_range * detection_range:
		return false
	if is_zero_approx(local_offset.length_squared()):
		return true
	var horizontal_angle := absf(rad_to_deg(atan2(local_offset.x, -local_offset.z)))
	var flat_length := Vector2(local_offset.x, local_offset.z).length()
	var vertical_angle := absf(rad_to_deg(atan2(local_offset.y, flat_length)))
	return (horizontal_fov_degrees >= 360.0 or horizontal_angle <= horizontal_fov_degrees * 0.5) \
		and (vertical_fov_degrees >= 180.0 or vertical_angle <= vertical_fov_degrees * 0.5)
