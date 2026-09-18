extends "res://scripts/world/interactable.gd"
## Base for any NPC. A specific NPC (e.g. scripts/world/npcs/mira_npc.gd)
## extends this and only needs to override _get_dialogue_data() -- and
## optionally _get_start_node() if the NPC's lines change based on quest
## state/flags. See npcs/mira_npc.gd for a branching example.

@export var npc_name: String = "NPC"

func _on_interact() -> void:
	Dialogue.start(_get_dialogue_data(), _get_start_node(), npc_name)

## Override: return this NPC's dialogue dict (see dialogue.gd for shape).
func _get_dialogue_data() -> Dictionary:
	return {}

## Override: which node to start at. Defaults to "start" -- override this
## to branch based on GameState flags (quest progress, items found, etc.)
func _get_start_node() -> String:
	return "start"
