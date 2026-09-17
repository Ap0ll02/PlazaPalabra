extends Node2D
## Cheap procedural starfield for the intro cutscene -- swap for a real
## background/parallax layer once art exists.

@export var star_count: int = 120
@export var area: Vector2 = Vector2(1280, 720)

var _stars: Array[Vector2] = []
var _sizes: Array[float] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in star_count:
		_stars.append(Vector2(rng.randf_range(0, area.x), rng.randf_range(0, area.y)))
		_sizes.append(rng.randf_range(1.0, 2.4))
	queue_redraw()

func _draw() -> void:
	for i in _stars.size():
		draw_circle(_stars[i], _sizes[i], Color(1, 1, 1, 0.85))
