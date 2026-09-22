extends Node
## The player's side of the spell system: which spells they know and how
## much they've practiced each. Tier, accuracy and loadout copies are all
## derived from the practice count using the numbers in SpellBank.
## Session-scoped for now (like PlayerProfile).

signal spells_changed
signal tier_up(spell_id: String, tier_name: String)
signal book_changed

## spell_id -> {"practice": int}
var _known: Dictionary = {}
## The spellbook loadout: spell_id -> copies carried into a fight.
var book: Dictionary = {}

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

# --- Spellbook loadout -------------------------------------------------------

func book_total() -> int:
	var total := 0
	for id in book:
		total += book[id]
	return total

func book_copies(spell_id: String) -> int:
	return book.get(spell_id, 0)

## Copies of this spell allowed in the book right now.
func copy_cap(spell_id: String) -> int:
	var type_cap: int = SpellBank.TYPE_COPY_CAP.get(SpellBank.get_spell(spell_id).type, 1)
	return mini(max_copies(spell_id), type_cap)

## "" if the copy can be added, otherwise the reason it can't.
func add_block_reason(spell_id: String) -> String:
	if not knows(spell_id):
		return "You haven't learned that spell."
	if book_total() >= SpellBank.BOOK_SLOTS:
		return "Your spellbook is full. Click a spell in it to remove it."
	if book_copies(spell_id) >= copy_cap(spell_id):
		var spell := SpellBank.get_spell(spell_id)
		if max_copies(spell_id) < SpellBank.TYPE_COPY_CAP.get(spell.type, 1):
			return "Only %d cop%s of %s at %s. Practice it to carry more." % [
				copy_cap(spell_id), "y" if copy_cap(spell_id) == 1 else "ies",
				spell.name_es, tier_name(spell_id)]
		return "%s spells max out at %d copies." % [SpellBank.TYPE_LABELS[spell.type], copy_cap(spell_id)]
	return ""

func add_to_book(spell_id: String) -> bool:
	if add_block_reason(spell_id) != "":
		return false
	book[spell_id] = book_copies(spell_id) + 1
	StudySession.log_event("book_add", {"spell_id": spell_id, "copies": book[spell_id]})
	book_changed.emit()
	return true

func remove_from_book(spell_id: String) -> void:
	if book_copies(spell_id) <= 0:
		return
	book[spell_id] -= 1
	if book[spell_id] <= 0:
		book.erase(spell_id)
	StudySession.log_event("book_remove", {"spell_id": spell_id})
	book_changed.emit()

## Hit chance (0-100) after `correct_count` right cast-quiz answers:
## base + tier bonus + a step bonus per correct answer, capped at 100.
func accuracy_for_correct(spell_id: String, correct_count: int) -> int:
	var accuracy: int = SpellBank.get_spell(spell_id).get("base_accuracy", 0)
	accuracy += SpellBank.TIER_ACCURACY_BONUS[tier_index(spell_id)]
	for i in min(correct_count, SpellBank.STEP_BONUSES.size()):
		accuracy += SpellBank.STEP_BONUSES[i]
	return clampi(accuracy, 0, 100)

## The spells a returning (Week-2) participant starts with if their Week-1
## file can't be found.
const DEFAULT_RESTORE := ["bola_de_fuego", "rayo", "muro_de_piedra"]

## Restores spells, practice counts and the book from a Week-1 snapshot()
## (the "spell_progress" entry of session_summary.json). An empty or
## unusable snapshot falls back to DEFAULT_RESTORE at Novice.
func restore(saved: Dictionary) -> void:
	_known = {}
	book = {}
	for id in saved:
		if SpellBank.has_spell(id):
			_known[id] = {"practice": int(saved[id].get("practice", 0))}
	var fallback := _known.is_empty()
	if fallback:
		for id in DEFAULT_RESTORE:
			_known[id] = {"practice": 0}
	for id in known_ids():
		var copies := int(saved.get(id, {}).get("in_book", 0)) if not fallback else copy_cap(id)
		for i in copies:
			add_to_book(id)
	StudySession.log_event("spells_restored", {"spells": known_ids(), "book": book, "fallback": fallback})
	spells_changed.emit()
	book_changed.emit()

## For the session summary: spell_id -> {practice, tier}.
func snapshot() -> Dictionary:
	var result := {}
	for id in _known:
		result[id] = {"practice": practice_count(id), "tier": tier_name(id), "in_book": book_copies(id)}
	return result
