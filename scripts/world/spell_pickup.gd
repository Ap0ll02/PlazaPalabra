extends "res://scripts/world/interactable.gd"
## Something in the world that teaches a spell: press Enter/Space next to it,
## read a line of flavor text, then the learn lesson opens. When the spell
## is learned the object disappears; if an optional lesson is quit, it stays
## so the player can come back. `required` lessons can't be quit.
##
## `reveal_group` lets a scene reveal it later along with other objects
## (Town's market stalls join "search_spots").
##
## Visual: a bound scroll (assets/icons/world/scroll.png), replacing whatever
## placeholder shapes a scene's "Glow"/"Visual" child nodes drew -- those are
## removed in code so every scroll looks the same without editing each scene.
## It bobs gently and has a soft glow behind it, tinted per spell type once
## the spell is known (SpellBank.type_color), or gold while unidentified.

const SCROLL_TEXTURE := preload("res://assets/icons/world/scroll.png")
const SCROLL_WIDTH := 64.0
const BOB_HEIGHT := 5.0
const BOB_SECONDS := 1.8

@export var spell_id: String = ""
@export var flavor_text: String = ""
@export var required := false
@export var reveal_group: String = ""

var _intro_shown := false
var _sprite: Sprite2D
var _glow: Sprite2D
var _bob_time := 0.0

func _ready() -> void:
	super._ready()
	if reveal_group != "":
		add_to_group(reveal_group)
	Lesson.lesson_finished.connect(_on_lesson_finished)
	_build_visual()

## Swaps out any hand-drawn placeholder ("Glow"/"Visual") for the scroll art.
func _build_visual() -> void:
	for old_name in ["Glow", "Visual"]:
		var old := get_node_or_null(old_name)
		if old:
			remove_child(old)   # frees the name immediately, unlike queue_free() alone
			old.queue_free()

	var color := SpellBank.type_color(spell_id) if SpellBank.has_spell(spell_id) else Color(0.95, 0.8, 0.35)

	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = SCROLL_TEXTURE
	var glow_scale := (SCROLL_WIDTH * 1.6) / SCROLL_TEXTURE.get_width()
	_glow.scale = Vector2(glow_scale, glow_scale)
	_glow.modulate = Color(color.r, color.g, color.b, 0.35)
	add_child(_glow)

	_sprite = Sprite2D.new()
	_sprite.name = "Visual"
	_sprite.texture = SCROLL_TEXTURE
	var sprite_scale := SCROLL_WIDTH / SCROLL_TEXTURE.get_width()
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_sprite)

	_bob_time = randf() * TAU  # so multiple scrolls don't bob in lockstep

func _process(delta: float) -> void:
	super._process(delta)   # interactable.gd's prompt bob/fade
	if not is_instance_valid(_sprite):
		return
	_bob_time += delta
	var offset := sin(_bob_time * TAU / BOB_SECONDS) * BOB_HEIGHT
	_sprite.position.y = offset
	if is_instance_valid(_glow):
		_glow.position.y = offset

func _prompt_verb() -> String:
	return "Read the scroll"

func _can_interact() -> bool:
	return not SpellProgress.knows(spell_id)

func _on_interact() -> void:
	if SpellProgress.knows(spell_id):
		return
	if flavor_text != "" and not _intro_shown:
		_intro_shown = true
		Dialogue.dialogue_ended.connect(_start_lesson, CONNECT_ONE_SHOT)
		Dialogue.show_message(flavor_text)
	else:
		_start_lesson()

func _start_lesson() -> void:
	Lesson.start_learn(spell_id, required)

func _on_lesson_finished(finished_id: String, mode: String) -> void:
	if mode == "learn" and finished_id == spell_id:
		queue_free()
