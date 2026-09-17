extends Node2D
## Placeholder planet body -- swap for real art later. Scale/position on
## the node itself is how the intro sells "closer" between shots.

@export var radius: float = 130.0
@export var base_color: Color = Color(0.35, 0.55, 0.45, 1)
@export var highlight_color: Color = Color(0.55, 0.72, 0.6, 0.3)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, base_color)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.55, highlight_color)
