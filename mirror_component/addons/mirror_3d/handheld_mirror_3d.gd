@tool
class_name HandheldMirror3D
extends Mirror3D
## A controllable Mirror3D intended to be parented to a first-person Camera3D.
##
## Feed mouse or stick motion to add_tilt_input(), and a value from -1 to 1 to
## set_corner_extension(). The component smoothly applies the requested pose.

signal pose_changed(tilt_degrees: Vector2, corner_extension: float)

@export_category("Handheld Pose")
@export var resting_position := Vector3(0.4, -0.35, -0.88)
@export var resting_rotation_degrees := Vector3(-8.0, -12.0, -4.0)
@export var tilt_limits_degrees := Vector2(65.0, 55.0)
@export_range(0.0, 1.5, 0.01, "suffix:m") var corner_reach := 0.82
@export_range(0.0, 1.0, 0.01, "suffix:m") var corner_forward_reach := 0.28
@export_range(0.1, 30.0, 0.1) var pose_smoothing := 13.0

var tilt_degrees := Vector2.ZERO
var corner_extension := 0.0

var _target_tilt := Vector2.ZERO
var _target_corner := 0.0


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		position = resting_position
		rotation_degrees = resting_rotation_degrees


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var blend := 1.0 - exp(-pose_smoothing * delta)
	tilt_degrees = tilt_degrees.lerp(_target_tilt, blend)
	corner_extension = lerpf(corner_extension, _target_corner, blend)
	_apply_pose()
	super._process(delta)


## Adds relative tilt in degrees. X is yaw and Y is pitch.
func add_tilt_input(delta_degrees: Vector2) -> void:
	set_tilt_degrees(_target_tilt + delta_degrees)


## Sets the requested yaw/pitch, clamped to tilt_limits_degrees.
func set_tilt_degrees(value: Vector2) -> void:
	_target_tilt = Vector2(
		clampf(value.x, -tilt_limits_degrees.x, tilt_limits_degrees.x),
		clampf(value.y, -tilt_limits_degrees.y, tilt_limits_degrees.y)
	)
	pose_changed.emit(_target_tilt, _target_corner)


## Extends left (-1), rests (0), or extends right (+1) around a corner.
func set_corner_extension(value: float) -> void:
	_target_corner = clampf(value, -1.0, 1.0)
	pose_changed.emit(_target_tilt, _target_corner)


## Smoothly returns the mirror to its ordinary held pose.
func reset_pose() -> void:
	_target_tilt = Vector2.ZERO
	_target_corner = 0.0
	pose_changed.emit(_target_tilt, _target_corner)


func get_target_tilt_degrees() -> Vector2:
	return _target_tilt


func get_target_corner_extension() -> float:
	return _target_corner


func _apply_pose() -> void:
	var reach_amount := absf(corner_extension)
	position = resting_position + Vector3(
		corner_extension * corner_reach,
		0.04 * reach_amount,
		-corner_forward_reach * reach_amount
	)
	rotation_degrees = resting_rotation_degrees + Vector3(
		tilt_degrees.y,
		tilt_degrees.x - corner_extension * 12.0,
		corner_extension * -7.0
	)
