extends RefCounted
## Picks the wrong options for a multiple-choice question about one spell
## slot. Shared by lessons and combat so both are "dynamic" the same way:
## answers this player has actually mixed up with this word before come
## first, then the slot's own authored distractors, then other spells'
## words in the same role (and SpellBank.EXTRA_DISTRACTORS).

## Up to `count - 1` wrong options as {es, en}, never the correct answer,
## never duplicates.
static func wrong_options(slot: Dictionary, count: int, rng: RandomNumberGenerator) -> Array:
	var confused: Array = PlayerProfile.confused_answers(slot.word_id)
	var entries: Array = []
	var seen: Array = [slot.es]

	var add := func(d: Dictionary, own: bool) -> void:
		if seen.has(d.es):
			return
		seen.append(d.es)
		var priority := 0 if confused.has(d.es) else (1 if own else 2)
		entries.append({"d": d, "prio": priority, "r": rng.randf()})

	for d in slot.distractors:
		add.call(d, true)
	for id in SpellBank.all_ids():
		for other in SpellBank.get_spell(id).slots:
			if other.role == slot.role:
				add.call({"es": other.es, "en": other.en}, false)
	for extra in SpellBank.EXTRA_DISTRACTORS.get(slot.role, []):
		add.call(extra, false)

	# Confusions can only surface if they're candidates, so make sure any
	# recorded confusion with a known Spanish form is a candidate too.
	entries.sort_custom(func(a, b): return a.prio < b.prio if a.prio != b.prio else a.r < b.r)
	var out: Array = []
	for e in entries:
		if out.size() >= count - 1:
			break
		out.append(e.d)
	return out
