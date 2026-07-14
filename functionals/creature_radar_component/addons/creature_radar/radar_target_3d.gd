@tool
class_name RadarTarget3D
extends Node3D
## Opt-in marker that makes its creature visible to CreatureRadar3D instances.

signal detectability_changed(is_detectable: bool)

@export var detectable := true:
	set(value):
		if detectable == value:
			return
		detectable = value
		detectability_changed.emit(detectable)
@export var radar_id: StringName
@export var category: StringName = &"creature"
@export var signature_strength := 1.0
@export var registration_group: StringName = &"creature_radar_targets"


func _enter_tree() -> void:
	if not registration_group.is_empty():
		add_to_group(registration_group)


func _exit_tree() -> void:
	if not registration_group.is_empty():
		remove_from_group(registration_group)


func set_radar_invisible(value: bool) -> void:
	detectable = not value


func get_creature() -> Node:
	return get_parent()

