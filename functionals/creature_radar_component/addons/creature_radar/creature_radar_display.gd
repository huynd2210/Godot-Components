@tool
class_name CreatureRadarDisplay
extends Control
## Phosphor-style display for a CreatureRadar3D. Suitable for HUDs or SubViewports.

@export var radar_path: NodePath
@export var radar: Node3D
@export_range(0.05, 4.0, 0.05, "suffix:rev/s") var sweep_speed := 0.42
@export var background_color := Color("07130e")
@export var grid_color := Color("2f694e")
@export var sweep_color := Color("72ff9b")
@export var contact_color := Color("c8ff72")
@export var warning_color := Color("ffe66d")

var _sweep_angle := -PI * 0.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if radar == null and not radar_path.is_empty():
		radar = get_node_or_null(radar_path)
	set_process(not Engine.is_editor_hint())


func set_radar(value: Node3D) -> void:
	radar = value
	queue_redraw()


func _process(delta: float) -> void:
	_sweep_angle = fmod(_sweep_angle + delta * sweep_speed * TAU, TAU)
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, background_color)
	var margin := minf(size.x, size.y) * 0.075
	var directional := is_instance_valid(radar) and float(radar.horizontal_fov_degrees) < 359.9
	var center := Vector2(size.x * 0.5, size.y * (0.88 if directional else 0.51))
	var radius := minf(size.x * 0.47, size.y * (0.72 if directional else 0.5) - margin)
	if radius <= 4.0:
		return

	# Faint phosphor scan lines keep the display readable on a physical mesh.
	for y in range(0, int(size.y), 7):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.65, 0.4, 0.035), 1.0)
	var half_cone := deg_to_rad(float(radar.horizontal_fov_degrees) * 0.5) if directional else PI
	var arc_start := -PI * 0.5 - half_cone
	var arc_end := -PI * 0.5 + half_cone
	if directional:
		var sector := PackedVector2Array([center])
		for step in range(49):
			var sector_angle := lerpf(arc_start, arc_end, float(step) / 48.0)
			sector.append(center + Vector2(cos(sector_angle), sin(sector_angle)) * radius)
		sector.append(center)
		draw_colored_polygon(sector, Color(0.02, 0.16, 0.09, 0.88))
	else:
		draw_circle(center, radius, Color(0.02, 0.16, 0.09, 0.88))
	for ring in range(1, 5):
		draw_arc(center, radius * float(ring) / 4.0, arc_start, arc_end, 96, grid_color, 1.5)
	if directional:
		draw_line(center, center + Vector2(cos(arc_start), sin(arc_start)) * radius, grid_color, 1.5)
		draw_line(center, center + Vector2(cos(arc_end), sin(arc_end)) * radius, grid_color, 1.5)
		for fraction: float in [-0.5, 0.0, 0.5]:
			var spoke_angle: float = -PI * 0.5 + half_cone * fraction
			draw_line(center, center + Vector2(cos(spoke_angle), sin(spoke_angle)) * radius, grid_color, 1.0)
	else:
		draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), grid_color, 1.2)
		draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), grid_color, 1.2)
		for spoke in range(8):
			var angle := float(spoke) * TAU / 8.0
			draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.88,
				center + Vector2(cos(angle), sin(angle)) * radius, grid_color, 1.0)

	# Layered sweep tail approximates a fading CRT phosphor wedge.
	var display_sweep: float = -PI * 0.5 + sin(_sweep_angle) * half_cone if directional else _sweep_angle
	for trail in range(18, -1, -1):
		var trail_angle := display_sweep - float(trail) * (0.012 if directional else 0.022)
		var alpha := lerpf(0.015, 0.32, 1.0 - float(trail) / 18.0)
		draw_line(center, center + Vector2(cos(trail_angle), sin(trail_angle)) * radius,
			Color(sweep_color, alpha), 2.0 if trail < 3 else 1.0)
	var sweep_tip := center + Vector2(cos(display_sweep), sin(display_sweep)) * radius
	draw_circle(sweep_tip, 3.5, Color(sweep_color, 0.8))

	var nearest := INF
	var contact_count := 0
	if is_instance_valid(radar):
		for target in radar.contacts:
			if not is_instance_valid(target):
				continue
			var local_offset: Vector3 = radar.global_basis.inverse() * (target.global_position - radar.global_position)
			var distance: float = Vector2(local_offset.x, local_offset.z).length()
			if distance > radar.detection_range:
				continue
			nearest = minf(nearest, distance)
			contact_count += 1
			var point: Vector2 = center + Vector2(local_offset.x, local_offset.z) * radius / float(radar.detection_range)
			var pulse: float = 0.75 + sin(Time.get_ticks_msec() * 0.008 + target.get_instance_id()) * 0.25
			var color: Color = warning_color if distance < float(radar.detection_range) * 0.3 else contact_color
			draw_circle(point, 8.0 + pulse * 3.0, Color(color, 0.13))
			draw_circle(point, 4.0 + pulse * 1.5, color)
			draw_line(point + Vector2(-7, 0), point + Vector2(7, 0), Color(color, 0.55), 1.0)
			draw_line(point + Vector2(0, -7), point + Vector2(0, 7), Color(color, 0.55), 1.0)

	var font := ThemeDB.fallback_font
	var font_size := maxi(13, int(size.y * 0.042))
	var mode_text := "MOTION  //  FORWARD" if directional else "MOTION  //  360"
	draw_string(font, Vector2(margin, margin * 0.72), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, sweep_color)
	var range_text := "RNG --" if nearest == INF else "RNG %04.1fM" % nearest
	draw_string(font, Vector2(margin, size.y - margin * 0.25), range_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, contact_color)
	draw_string(font, Vector2(size.x - margin - 95, size.y - margin * 0.25), "%02d SIG" % contact_count,
		HORIZONTAL_ALIGNMENT_RIGHT, 95, font_size, contact_color)
