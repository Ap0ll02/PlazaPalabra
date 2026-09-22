extends "res://scripts/world/npc.gd"
## Mira in Week 2 (after the bandit fight). The scripted scenes -- the ambush,
## the thanks, Tomas missing -- live in scripts/world/town_return.gd; this is
## only what she says if you talk to her afterwards.
## Portrait poses: mira (default), mira_worried, mira_sad, mira_relieved.

const DIALOGUE := {
	"reminder": {
		"portrait": "mira_worried",
		"text": "Please find Tomas. The jungle path to the east is where the bandits came from.",
		"next": "end",
	},
	"busy": {
		"portrait": "mira_worried",
		"text": "Be careful! There are bandits all around me!",
		"next": "end",
	},
}

func _get_dialogue_data() -> Dictionary:
	return DIALOGUE

func _get_start_node() -> String:
	return "reminder" if GameState.has_flag("w2_bandits_defeated") else "busy"
