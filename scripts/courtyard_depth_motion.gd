extends Node2D

var travel_progress = 0.0
var lateral_offset = 0.0
var motion_strength = 0.0
var viewport_size = Vector2(1920.0, 1080.0)


func configure(progress: float, lateral: float, moving: float, size: Vector2) -> void:
	travel_progress = progress
	lateral_offset = lateral
	motion_strength = moving
	viewport_size = size
	queue_redraw()


func _draw() -> void:
	var center_x = viewport_size.x * 0.5 - lateral_offset * 210.0
	var horizon_y = viewport_size.y * 0.385
	var bottom_y = viewport_size.y * 1.06

	# Perspective seams move fastest near the camera and barely move at the horizon.
	for index in range(11):
		var phase = fposmod(float(index) / 11.0 + travel_progress * 1.7, 1.0)
		var depth = pow(phase, 1.72)
		var y = lerpf(horizon_y, bottom_y, depth)
		var half_width = lerpf(74.0, viewport_size.x * 0.48, pow(phase, 1.25))

		if index % 3 == 1:
			_draw_puddle(center_x, y, half_width, phase)
		if index % 2 == 0 and phase > 0.16:
			_draw_side_silhouettes(center_x, y, half_width, phase)

func _draw_puddle(center_x: float, y: float, half_width: float, phase: float) -> void:
	var side = -1.0 if int(phase * 100.0) % 2 == 0 else 1.0
	var puddle_center = Vector2(center_x + side * half_width * 0.34, y + 5.0)
	var puddle_width = lerpf(18.0, 145.0, phase)
	var puddle_height = lerpf(2.0, 14.0, phase)
	var points = PackedVector2Array([
		puddle_center + Vector2(-puddle_width, 0.0),
		puddle_center + Vector2(-puddle_width * 0.42, -puddle_height),
		puddle_center + Vector2(puddle_width * 0.56, -puddle_height * 0.55),
		puddle_center + Vector2(puddle_width, 0.0),
		puddle_center + Vector2(puddle_width * 0.35, puddle_height),
		puddle_center + Vector2(-puddle_width * 0.62, puddle_height * 0.65),
	])
	draw_colored_polygon(points, Color(0.33, 0.42, 0.46, lerpf(0.015, 0.095, phase)))


func _draw_side_silhouettes(center_x: float, y: float, half_width: float, phase: float) -> void:
	var scale_factor = lerpf(0.18, 1.35, phase)
	var column_height = 78.0 * scale_factor
	var column_width = 12.0 * scale_factor
	var color = Color(0.025, 0.022, 0.018, lerpf(0.18, 0.72, phase))

	for side: float in [-1.0, 1.0]:
		var x: float = center_x + side * (half_width + 42.0 * scale_factor)
		draw_rect(Rect2(x - column_width * 0.5, y - column_height, column_width, column_height), color)
		var pot_center = Vector2(x + side * 23.0 * scale_factor, y - 5.0 * scale_factor)
		draw_circle(pot_center, 11.0 * scale_factor, Color(0.045, 0.037, 0.028, color.a * 0.9))
		draw_line(
			pot_center + Vector2(0.0, -9.0 * scale_factor),
			pot_center + Vector2(side * 24.0 * scale_factor, -37.0 * scale_factor),
			Color(0.09, 0.075, 0.05, color.a * 0.7),
			maxf(1.0, scale_factor),
			true
		)
