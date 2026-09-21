extends RefCounted
## The scaffolded hint ladder (pure logic). After each miss the learner gets
## a slightly bigger nudge, and only the last step reveals the answer, so
## they keep producing the answer themselves (Finn & Metcalfe, 2010:
## incremental hints until the learner can self-generate the answer led to
## the best memory for corrections after 30 min and 1 day).
##
## Rungs are named so every one can be logged. `miss` is 0 for the first miss.
##
##   choice question (slot):  0 meaning cue -> 1 sentence context (+ drop a wrong option)
##   typed slot:              0 meaning + first letter -> 1 context + two letters
##   whole sentence:          0 word count + first word -> 1 first half of the sentence
## Reveal happens when the miss count reaches the exercise's try limit.

const ROLE_TYPES := {
	"subject": "pronoun (who is doing it)",
	"reflexive": "reflexive pronoun (done to yourself)",
	"verb": "verb (the action)",
	"object": "noun (the thing)",
}

## "It's a verb (the action) meaning "throw"."
static func meaning_cue(slot: Dictionary) -> String:
	return "It's a %s meaning \"%s\"." % [ROLE_TYPES.get(slot.role, "word"), slot.en]

## The spell's sentence with this slot blanked out, plus its English.
static func context_cue(spell: Dictionary, slot_i: int) -> String:
	var parts: Array = []
	for i in spell.slots.size():
		parts.append("_____" if i == slot_i else spell.slots[i].es)
	return "%s   (%s)" % [" ".join(parts), spell.sentence_en]

## "la _ _ _ _" -- the first `n` letters then one blank per remaining letter.
static func letters_cue(word: String, n: int) -> String:
	var shown := mini(n, word.length() - 1)
	var out: Array = []
	for i in word.length():
		out.append(word[i] if i < shown else "_")
	return " ".join(out)

## Sentence-level cue for translate/reorder exercises.
static func sentence_cue(target: String, miss: int) -> String:
	var words: Array = Array(target.split(" "))
	if miss <= 0:
		return "%d words, starting with \"%s\"." % [words.size(), words[0]]
	var half := maxi(2, ceili(words.size() / 2.0))
	return "It starts: %s ..." % " ".join(words.slice(0, half))

## The hint text for a slot-level miss, and the rung names used (for logs).
static func slot_hint(spell: Dictionary, slot_i: int, miss: int, typed: bool) -> Dictionary:
	var slot: Dictionary = spell.slots[slot_i]
	if typed:
		if miss <= 0:
			return {"text": "%s  %s" % [meaning_cue(slot), letters_cue(slot.es, 1)], "rungs": ["meaning", "letters1"]}
		return {"text": "%s\n%s" % [context_cue(spell, slot_i), letters_cue(slot.es, 2)], "rungs": ["context", "letters2"]}
	if miss <= 0:
		return {"text": meaning_cue(slot), "rungs": ["meaning"]}
	return {"text": context_cue(spell, slot_i), "rungs": ["context", "drop_option"]}
