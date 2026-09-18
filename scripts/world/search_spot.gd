extends "res://scripts/world/interactable.gd"
## A searchable spot (market stall, crate, etc.). One in a set is usually
## the real clue (is_clue = true, word_id set); the rest are decoys with
## flavor text. Searches once, then stays searched.

signal clue_found(word_id: String)

@export var is_clue: bool = false
@export var word_id: String = ""
@export var flavor_text: String = "There's nothing here."

var _searched := false

func _ready() -> void:
	super._ready()
	add_to_group("search_spots")

func _on_interact() -> void:
	if _searched:
		return
	_searched = true

	if is_clue:
		PlayerProfile.record_seen(word_id)
		GameState.set_flag("found_clue", true)
		var word: Dictionary = WordBank.get_word(word_id)
		clue_found.emit(word_id)
		Dialogue.show_message("You found a %s (%s)! This might be a clue." % [word.spanish, word.english])
	else:
		Dialogue.show_message(flavor_text)
