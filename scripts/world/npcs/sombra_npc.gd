extends "res://scripts/world/npc.gd"
## The thief / boss. Won't engage until the player has picked up enough of
## the ruins' scrolls (exposure to combat words before the fight).
## Portrait poses: sombra (default), sombra_smug, sombra_angry.

const SCROLLS_REQUIRED := 3

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
	"not_ready": {
		"speaker": "You",
		"portrait": "",
		"text": "(Something tells you to look around the ruins first. Those old scrolls might help.)",
		"next": "end",
	},
}

func _get_dialogue_data() -> Dictionary:
	return DIALOGUE

func _get_start_node() -> String:
	if int(GameState.flags.get("ruins_scrolls", 0)) >= SCROLLS_REQUIRED:
		return "start"
	return "not_ready"
