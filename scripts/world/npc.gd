extends "res://scripts/world/interactable.gd"
## Base for any NPC. A specific NPC (e.g. scripts/world/npcs/mira_npc.gd)
## extends this and only needs to override _get_dialogue_data() -- and
## optionally _get_start_node() if the NPC's lines change based on quest
## state/flags. See npcs/mira_npc.gd for a branching example.
##
## portrait_id is this NPC's default portrait (e.g. "mira"); individual
## dialogue nodes can override it with a pose like "mira_worried".

@export var npc_name: String = "NPC"
@export var portrait_id: String = ""

const NAME_HEIGHT := 34.0

func _ready() -> void:
	super._ready()
	_build_name_tag()

## The NPC's name floats above their head. When real art lands, change
## NAME_HEIGHT (or move the label) so it sits above the sprite instead.
func _build_name_tag() -> void:
	var tag := Label.new()
	tag.text = npc_name
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_constant_override("outline_size", 5)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	tag.z_index = 50
	add_child(tag)
	tag.position = Vector2(-tag.get_combined_minimum_size().x / 2.0, -NAME_HEIGHT - 22.0)

func _prompt_height() -> float:
	return NAME_HEIGHT + 56.0

func _prompt_verb() -> String:
	return "Talk"

func _on_interact() -> void:
	Dialogue.start(_get_dialogue_data(), _get_start_node(), npc_name, portrait_id)

## Override: return this NPC's dialogue dict (see dialogue.gd for shape).
func _get_dialogue_data() -> Dictionary:
	return {}

## Override: which node to start at. Defaults to "start" -- override this
## to branch based on GameState flags (quest progress, items found, etc.)
func _get_start_node() -> String:
	return "start"
