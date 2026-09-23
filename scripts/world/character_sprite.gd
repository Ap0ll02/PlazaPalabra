extends Node2D
## A character's world sprite, centralized so importing art never means
## editing scenes. Drop `assets/sprites/characters/<character_id>.png` in
## the project and every scene using that id picks it up automatically; with
## no file yet, a placeholder shape (tinted `fallback_color`) shows instead
## so the game looks and plays the same either way. Same convention as
## SpellIcons (assets/icons/spells/) and the dialogue portraits
## (assets/portraits/) -- see assets/sprites/characters/README.md.
##
## Usage: add as a Node2D named "Visual" (or anything) under a character,
## set character_id + fallback_color (+ fallback_shape if not a person).
## AI-generated art checklist before dropping a file in: transparent PNG,
## the character centered in the frame with a consistent margin, feet near
## the bottom edge (this node draws the character standing on its origin),
## and roughly the same apparent height as other characters at PIXEL_WIDTH.

const PIXEL_WIDTH := 64.0

## Placeholder shapes, in case an id has no art yet -- same look as the
## hand-drawn polygons this replaces.
const SHAPES := {
	"person": [Vector2(0, -22), Vector2(14, 4), Vector2(8, 24), Vector2(-8, 24), Vector2(-14, 4)],
	"diamond": [Vector2(0, -16), Vector2(14, 10), Vector2(0, 16), Vector2(-14, 10)],
}

@export var character_id: String = ""
@export var fallback_color: Color = Color(0.6, 0.6, 0.6, 1)
@export var fallback_shape: String = "person"
## Nudges a real sprite up/down to line up its feet with the placeholder's.
@export var foot_offset: float = 0.0

func _ready() -> void:
	var path := "res://assets/sprites/characters/%s.png" % character_id
	if character_id != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var sprite := Sprite2D.new()
		sprite.texture = tex
		var scale_factor := PIXEL_WIDTH / tex.get_width()
		sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.centered = false
		sprite.position = Vector2(-PIXEL_WIDTH / 2.0, -tex.get_height() * scale_factor + foot_offset)
		add_child(sprite)
	else:
		var poly := Polygon2D.new()
		poly.color = fallback_color
		poly.polygon = PackedVector2Array(SHAPES.get(fallback_shape, SHAPES.person))
		add_child(poly)
