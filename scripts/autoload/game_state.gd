extends Node
## Session-level state: player HP and quest/story progress flags.
## Kept separate from PlayerProfile, which is about word mastery.

signal hp_changed(current: int, max: int)
signal quest_stage_changed(stage: String)

const MAX_HP := 100

var hp: int = MAX_HP
var quest_stage: String = "intro" # intro -> tutorial -> quest_1 -> quest_2 -> boss -> ending
var flags: Dictionary = {}

func set_quest_stage(stage: String) -> void:
	quest_stage = stage
	quest_stage_changed.emit(stage)

func damage_player(amount: int) -> void:
	hp = max(0, hp - amount)
	hp_changed.emit(hp, MAX_HP)

func heal_player(amount: int) -> void:
	hp = min(MAX_HP, hp + amount)
	hp_changed.emit(hp, MAX_HP)

func set_flag(key: String, value = true) -> void:
	flags[key] = value

func has_flag(key: String) -> bool:
	return flags.get(key, false)
