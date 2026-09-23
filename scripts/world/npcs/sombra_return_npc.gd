extends "res://scripts/world/npc.gd"
## Sombra, back and stronger, in the clearing. Talking starts the final fight.
## Portrait poses: sombra (default), sombra_smug, sombra_angry.

const DIALOGUE := {
	"start": {
		"portrait": "sombra_smug",
		"text": "So you followed me all the way here. Persistent, aren't you?",
		"next": "taunt",
	},
	"taunt": {
		"portrait": "sombra_smug",
		"text": "Last time I held back. This time, I won't.",
		"choices": [
			{"text": "Give Tomas back!", "next": "fight"},
			{"text": "We'll see about that.", "next": "fight"},
		],
	},
	"fight": {
		"portrait": "sombra_angry",
		"text": "Voy a vencerte... I will defeat you.",
		"on_enter": "start_final_fight",
		"next": "end",
	},
	"retry": {
		"portrait": "sombra_smug",
		"text": "Back for more? Good. I was just getting warmed up.",
		"on_enter": "start_final_fight",
		"next": "end",
	},
}

func _get_dialogue_data() -> Dictionary:
	return DIALOGUE

func _get_start_node() -> String:
	return "retry" if GameState.has_flag("w2_sombra_lost") else "start"

func _can_interact() -> bool:
	return not GameState.has_flag("w2_sombra_defeated")
