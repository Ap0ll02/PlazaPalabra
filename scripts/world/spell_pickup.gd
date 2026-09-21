extends "res://scripts/world/interactable.gd"
## Something in the world that teaches a spell: press Enter/Space next to it,
## read a line of flavor text, then the learn lesson opens. When the spell
## is learned the object disappears; if an optional lesson is quit, it stays
## so the player can come back. `required` lessons can't be quit.
##
## `reveal_group` lets a scene reveal it later along with other objects
## (Town's market stalls join "search_spots").

@export var spell_id: String = ""
@export var flavor_text: String = ""
@export var required := false
@export var reveal_group: String = ""

var _intro_shown := false

func _ready() -> void:
	super._ready()
	if reveal_group != "":
		add_to_group(reveal_group)
	Lesson.lesson_finished.connect(_on_lesson_finished)

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
