extends "res://scripts/world/npc.gd"
## The thief / boss. Talking to him starts the fight.
## Portrait poses: sombra (default), sombra_smug, sombra_angry.

const DIALOGUE := {
	"start": {
		"portrait": "sombra_smug",
		"text": "Tch. You followed me all the way out here?",
		"next": "taunt",
	},
	"taunt": {
		"portrait": "sombra_smug",
		"text": "Those coins are mine now. Go home, traveler.",
		"choices": [
			{"text": "Give the money back!", "next": "fight"},
			{"text": "Let's talk about this.", "next": "talk"},
		],
	},
	"fight": {
		"portrait": "sombra_angry",
		"text": "Bold. Let's see what you've got.",
		"on_enter": "start_boss_fight",
		"next": "end",
	},
	"talk": {
		"portrait": "sombra_smug",
		"text": "Talk? Ha! Then talk -- if you can string a sentence together.",
		"on_enter": "start_boss_fight",
		"next": "end",
	},
}

func _get_dialogue_data() -> Dictionary:
	return DIALOGUE
