extends "res://scripts/world/npc.gd"
## Quest 2's NPC: recognizes the note's handwriting and points the player
## at the thief's hideout in the ruins. Also foreshadows that combat is
## about speaking clearly. Branches on quest state via _get_start_node().
## Portrait poses: tomas (default), tomas_thoughtful, tomas_serious.

const DIALOGUE := {
	"start": {
		"portrait": "tomas_thoughtful",
		"text": "Ah, Mira sent you. I heard about the robbery.",
		"next": "lead",
	},
	"lead": {
		"portrait": "tomas_serious",
		"text": "That note... I know that handwriting. There's a thief who hides out in the old ruins east of town. They call him Sombra.",
		"next": "warn",
	},
	"warn": {
		"text": "Are you sure you want to go after him?",
		"choices": [
			{"text": "I'll go to the ruins.", "next": "go"},
			{"text": "Is it dangerous?", "next": "danger"},
		],
	},
	"danger": {
		"portrait": "tomas_serious",
		"text": "Sombra won't listen to mumbling. Speak clearly and put your words together well -- in the ruins, words are your best weapon.",
		"next": "go",
	},
	"go": {
		"text": "Follow the path east out of town. And be careful.",
		"on_enter": "start_quest_2",
		"next": "end",
	},
	"not_yet": {
		"text": "Sorry, I'm busy. Maybe ask Mira about her missing money first.",
		"next": "end",
	},
	"reminder": {
		"text": "The ruins are east of town. Good luck.",
		"next": "end",
	},
}

func _get_dialogue_data() -> Dictionary:
	return DIALOGUE

func _get_start_node() -> String:
	if GameState.has_flag("quest_2_started"):
		return "reminder"
	elif GameState.has_flag("quest_2_handoff"):
		return "start"
	return "not_yet"
