extends RefCounted
## Decides which exercises make up a lesson. Pure logic (no UI), so the
## difficulty ladder can be tuned and tested in one place.
##
## learn:    translate (tiles) -> build (guided) -> 1 cast-style question
## practice: build + one extra exercise, both chosen by mastery tier:
##   Novice       guided build, fixed order, 3 choices   + assemble English tiles
##   Adept        guided build, shuffled order           + type the English
##   Advanced     English-only build, 4 choices          + type the English
##   Master       English-only, shuffled, 4 choices      + type Spanish / fill blank / listen
##   Grandmaster  English-only, shuffled, type each slot + same pool as Master
##
## Exercise specs are dictionaries with a "kind":
##   translate_tiles | translate_type {lang} | build {guided, order, choices,
##   typed} | quiz {slot} | fill_blank {slot, choices} | listen_pick {slot} |
##   tile_reorder | contrast_pair (word order, from Adept up)

const AUDIO_DIR := "res://assets/audio/voice/"
const AUDIO_EXTENSIONS := ["ogg", "wav", "mp3"]

## Recordings are named after the Spanish text as shown to the player, so
## "lanzo" -> lanzo.ogg and "una bola de fuego" -> una_bola_de_fuego.ogg
## (lowercase, accents dropped, spaces -> underscores).
static func audio_key(spanish: String) -> String:
	var t: String = spanish.to_lower()
	for accented in ["á", "é", "í", "ó", "ú", "ü", "ñ"]:
		t = t.replace(accented, {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}[accented])
	return t.strip_edges().replace(" ", "_")

## Path of the recorded clip for this Spanish text, or "" if none exists yet.
static func audio_path(spanish: String) -> String:
	var key := audio_key(spanish)
	for ext in AUDIO_EXTENSIONS:
		var path: String = "%s%s.%s" % [AUDIO_DIR, key, ext]
		if ResourceLoader.exists(path):
			return path
	return ""

static func slot_order(shuffled: bool, rng: RandomNumberGenerator) -> Array:
	var order: Array = [0, 1, 2]
	if not shuffled:
		return order
	# Reshuffle until it actually differs from the natural order.
	for attempt in 20:
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = order[i]
			order[i] = order[j]
			order[j] = tmp
		if order != [0, 1, 2]:
			break
	return order

## The word-order exercises, shared by every tier from Adept up.
static func _order_pool() -> Array:
	return [{"kind": "tile_reorder"}, {"kind": "contrast_pair"}]

## A random entry from `pool` plus the `always` items (kept so each tier
## still gets its familiar exercise now and then).
static func _pick(pool: Array, rng: RandomNumberGenerator, always: Array) -> Dictionary:
	var all: Array = pool + always
	return all[rng.randi_range(0, all.size() - 1)]

static func _build(guided: bool, shuffled: bool, choices: int, typed: bool, rng: RandomNumberGenerator) -> Dictionary:
	return {"kind": "build", "guided": guided, "order": slot_order(shuffled, rng), "choices": choices, "typed": typed}

static func build_plan(spell_id: String, mode: String, tier: int, rng: RandomNumberGenerator) -> Array:
	if mode == "learn":
		return [
			{"kind": "translate_tiles"},
			_build(true, false, 3, false, rng),
			{"kind": "quiz", "slot": rng.randi_range(0, 2)},
		]

	match tier:
		0:
			return [_build(true, false, 3, false, rng), {"kind": "translate_tiles"}]
		1:
			return [_build(true, true, 3, false, rng), _pick(_order_pool(), rng, [{"kind": "translate_type", "lang": "en"}])]
		2:
			return [_build(false, false, 4, false, rng), _pick(_order_pool(), rng, [{"kind": "translate_type", "lang": "en"}])]
	# Master and Grandmaster share the extra-exercise pool.
	var pool: Array = _order_pool()
	pool.append_array([
		{"kind": "translate_type", "lang": "es"},
		{"kind": "fill_blank", "slot": rng.randi_range(0, 2), "choices": 4},
	])
	var voiced: Array = []
	var slots: Array = SpellBank.get_spell(spell_id).slots
	for i in slots.size():
		if audio_path(slots[i].es) != "":
			voiced.append(i)
	if not voiced.is_empty():
		pool.append({"kind": "listen_pick", "slot": voiced[rng.randi_range(0, voiced.size() - 1)]})
	var extra: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return [_build(false, true, 4, tier >= 4, rng), extra]
