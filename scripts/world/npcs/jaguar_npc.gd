extends "res://scripts/world/npc.gd"
## The optional jungle jaguar. Choosing to fight starts the encounter (the
## scene, scripts/world/jungle.gd, listens for the action).

const DIALOGUE := {
	"start": {
		"text": "An old stone shrine stands here. On its altar a scroll glints, and a jaguar guards it. It growls and blocks your way.",
		"choices": [
			{"text": "Fight the jaguar.", "next": "fight"},
			{"text": "Back away.", "next": "back"},
		],
	},
	"fight": {
		"text": "The jaguar crouches, ready to pounce.",
		"on_enter": "start_jaguar_fight",
		"next": "end",
	},
	"back": {
		"text": "You step back. The jaguar's eyes follow you, but it doesn't chase.",
		"next": "end",
	},
}

func _get_dialogue_data() -> Dictionary:
	return DIALOGUE

func _prompt_verb() -> String:
	return "Approach"

func _can_interact() -> bool:
	return not GameState.has_flag("w2_jaguar_defeated")
