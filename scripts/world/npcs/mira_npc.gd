extends "res://scripts/world/npc.gd"
## Quest 1's NPC: was robbed, sends the player to search the market
## stalls, then redirects to Tomas once the clue is found. Dialogue
## content only -- to edit what Mira says, edit the dicts below.
## Portrait poses: mira (default), mira_worried, mira_sad, mira_relieved.

const DIALOGUE_BEFORE := {
	"start": {
		"portrait": "mira_worried",
		"text": "¡Por Favor! Can you help me? Some men just stole my coin!",
		"next": "ask_help",
	},
	"ask_help": {
		"portrait": "mira_worried",
		"text": "Could you help me look for clues near the market stalls?",
		"choices": [
			{"text": "Of course, I'll help.", "next": "accept"},
			{"text": "I can't right now.", "next": "decline"},
		],
	},
	"accept": {
		"portrait": "mira_relieved",
		"text": "Thank you! ¡Gracias! I think just searching around these market stalls might be a good start...",
		"on_enter": "start_quest_1",
		"next": "end",
	},
	"decline": {
		"portrait": "mira_sad",
		"text": "Oh... please come back if you change your mind. This world could use more heroes.",
		"next": "end",
	},
}

const DIALOGUE_SEARCHING := {
	"start": {"text": "Did you find anything yet?", "next": "end"},
}

const DIALOGUE_FOUND := {
	"start": {"portrait": "mira_worried", "text": "You found something! A note...", "next": "hint"},
	"hint": {
		"portrait": "mira_relieved",
		"text": "This note, I don't know, 'No Lo Se' what it means. Perhaps Tomas, near the well, will have an idea!",
		"on_enter": "start_quest_2_handoff",
		"next": "hint_next",
	},
	"hint_next": {
		"portrait": "mira_relieved",
		"text": "Go talk to him!",
		"next": "end",
	},
}

func _get_dialogue_data() -> Dictionary:
	if GameState.has_flag("found_clue"):
		return DIALOGUE_FOUND
	elif GameState.has_flag("quest_1_started"):
		return DIALOGUE_SEARCHING
	else:
		return DIALOGUE_BEFORE
