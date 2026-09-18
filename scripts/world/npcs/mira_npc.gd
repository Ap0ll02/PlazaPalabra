extends "res://scripts/world/npc.gd"
## Quest 1's NPC: was robbed, sends the player to search the market
## stalls, then redirects to Tomas once the clue is found. Dialogue
## content only -- to edit what Mira says, edit the dicts below.

const DIALOGUE_BEFORE := {
	"start": {
		"text": "Please... someone robbed me. My money is gone!",
		"next": "ask_help",
	},
	"ask_help": {
		"text": "Could you help me look for clues near the market stalls?",
		"choices": [
			{"text": "Of course, I'll help.", "next": "accept"},
			{"text": "I can't right now.", "next": "decline"},
		],
	},
	"accept": {
		"text": "Thank you! Please look around the market stalls -- maybe something was left behind.",
		"on_enter": "start_quest_1",
		"next": "end",
	},
	"decline": {
		"text": "Oh... please come back if you change your mind.",
		"next": "end",
	},
}

const DIALOGUE_SEARCHING := {
	"start": {"text": "Did you find anything yet?", "next": "end"},
}

const DIALOGUE_FOUND := {
	"start": {"text": "You found something! A note...", "next": "hint"},
	"hint": {
		"text": "This might mean something to Tomas -- he's near the well and knows everyone in town.",
		"on_enter": "start_quest_2_handoff",
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
