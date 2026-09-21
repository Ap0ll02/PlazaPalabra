extends Node
## The player's side of the spell system: which spells they know and how
## much they've practiced each. Tier, accuracy and loadout copies are all
## derived from the practice count using the numbers in SpellBank.
## Session-scoped for now (like PlayerProfile).

signal spells_changed
signal tier_up(spell_id: String, tier_name: String)

## spell_id -> {"practice": int}
var _known: Dictionary = {}

func learn_spell(spell_id: String) -> void:
	if _known.has(spell_id) or not SpellBank.has_spell(spell_id):
		return
	_known[spell_id] = {"practice": 0}
	StudySession.log_event("spell_learned", {"spell_id": spell_id})
	spells_changed.emit()

func knows(spell_id: String) -> bool:
	return _known.has(spell_id)

## Known spell ids in SpellBank order (stable, not learn order).
func known_ids() -> Array:
	return SpellBank.all_ids().filter(func(id): return _known.has(id))

func practice_count(spell_id: String) -> int:
	return _known.get(spell_id, {}).get("practice", 0)

## Call after each completed practice build.
func record_practice(spell_id: String) -> void:
	if not _known.has(spell_id):
		return
	var tier_before := tier_index(spell_id)
	_known[spell_id].practice += 1
	StudySession.log_event("spell_practiced", {
		"spell_id": spell_id, "practice": practice_count(spell_id), "tier": tier_index(spell_id),
	})
	if tier_index(spell_id) > tier_before:
		StudySession.log_event("spell_tier_up", {"spell_id": spell_id, "tier": tier_name(spell_id)})
		tier_up.emit(spell_id, tier_name(spell_id))
	spells_changed.emit()

func tier_index(spell_id: String) -> int:
	var count := practice_count(spell_id)
	var index := 0
	for i in SpellBank.TIER_THRESHOLDS.size():
		if count >= SpellBank.TIER_THRESHOLDS[i]:
			index = i
	return index

func tier_name(spell_id: String) -> String:
	return SpellBank.TIER_NAMES[tier_index(spell_id)]

## Practice count needed for the next tier, or -1 if already at the top.
func next_tier_threshold(spell_id: String) -> int:
	var next := tier_index(spell_id) + 1
	return SpellBank.TIER_THRESHOLDS[next] if next < SpellBank.TIER_THRESHOLDS.size() else -1

func max_copies(spell_id: String) -> int:
	return SpellBank.TIER_COPIES[tier_index(spell_id)]

## Hit chance (0-100) after `correct_count` right cast-quiz answers:
## base + tier bonus + a step bonus per correct answer, capped at 100.
func accuracy_for_correct(spell_id: String, correct_count: int) -> int:
	var accuracy: int = SpellBank.get_spell(spell_id).get("base_accuracy", 0)
	accuracy += SpellBank.TIER_ACCURACY_BONUS[tier_index(spell_id)]
	for i in min(correct_count, SpellBank.STEP_BONUSES.size()):
		accuracy += SpellBank.STEP_BONUSES[i]
	return clampi(accuracy, 0, 100)

## For the session summary: spell_id -> {practice, tier}.
func snapshot() -> Dictionary:
	var result := {}
	for id in _known:
		result[id] = {"practice": practice_count(id), "tier": tier_name(id)}
	return result
