@tool
class_name CreatureConeRadar3D
extends "res://addons/creature_radar/creature_radar_3d.gd"
## Directional variant of CreatureRadar3D which only detects inside a forward cone.


func _init() -> void:
	horizontal_fov_degrees = 70.0
	vertical_fov_degrees = 55.0
	detection_range = 26.0

