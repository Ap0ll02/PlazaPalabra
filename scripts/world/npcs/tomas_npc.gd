extends "res://scripts/world/npc.gd"
## Quest 2's NPC -- currently just a stub handoff since Quest 2 content
## doesn't exist yet. Once it does, replace the "quest_2_dev_bridge"
## on_enter action with whatever actually starts Quest 2.

const DIALOGUE := {
	"start": {
		"text": "Ah, I heard about the robbery. Let me think on where the thief might have gone...",
		"next": "next_line",
	},
	"next_line": {
		"text": "(Quest 2 isn't built yet -- for now, this is where the demo continues.)",
		"on_enter": "quest_2_dev_bridge",
		"next": "end",
	},
}

func _get_dialogue_data() -> Dictionary:
	return DIALOGUE
