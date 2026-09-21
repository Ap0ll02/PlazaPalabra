extends RefCounted
## The rules of a fight, with no UI, so they can be tested with a seeded
## random generator. The Combat overlay drives this and just displays it.

const Config := preload("res://scripts/combat/combat_config.gd")
const Distractors := preload("res://scripts/lesson/distractors.gd")

var encounter: Dictionary
var rng: RandomNumberGenerator
var round_number := 1
var player_hp: int
var player_max_hp: int
var mana: int
var loadout: Dictionary = {}
## Damage the player's shield can still absorb.
var shield := 0
## True after a successful Furia: the next attack is boosted.
var fury_pending := false
var accuracy_bonus := 0
var hp_floor := 0
## Each: {name, hp, max_hp, shield, spells, color, boss}
var enemies: Array = []

func _init(enc: Dictionary, rng_: RandomNumberGenerator, max_hp: int) -> void:
	encounter = enc
	rng = rng_
	player_max_hp = max_hp
	player_hp = max_hp
	mana = mini(enc.get("start_mana", Config.MANA_MAX), Config.MANA_MAX)
	loadout = enc.loadout.duplicate()
	accuracy_bonus = enc.get("accuracy_bonus", 0)
	hp_floor = enc.get("hp_floor", 0)
	for e in enc.enemies:
		enemies.append({
			"name": e.name, "hp": e.hp, "max_hp": e.hp, "shield": 0,
			"spells": e.spells, "color": e.get("color", Color.GRAY), "boss": e.get("boss", false),
		})

# --- Queries ---------------------------------------------------------------

func living() -> Array:
	var out: Array = []
	for i in enemies.size():
		if enemies[i].hp > 0:
			out.append(i)
	return out

func is_won() -> bool:
	var bosses: Array = enemies.filter(func(e): return e.boss)
	if bosses.is_empty() or encounter.get("win", "all") == "all":
		return living().is_empty()
	return bosses.any(func(e): return e.hp <= 0)

func is_lost() -> bool:
	return player_hp <= 0

func uses_left(spell_id: String) -> int:
	return loadout.get(spell_id, 0)

func total_uses() -> int:
	var total := 0
	for id in loadout:
		total += loadout[id]
	return total

## `extra` is mana already set aside for hints on this cast.
func can_cast(spell_id: String, extra: int = 0) -> bool:
	return uses_left(spell_id) > 0 and mana >= SpellBank.get_spell(spell_id).mana_cost + extra

func any_castable() -> bool:
	for id in loadout:
		if can_cast(id):
			return true
	return false

func needs_target(spell_id: String) -> bool:
	return SpellBank.get_spell(spell_id).target == "single" and living().size() > 1

func fury_applies(spell_id: String) -> bool:
	return fury_pending and SpellBank.has_combined(spell_id)

func accuracy(spell_id: String, correct_count: int) -> int:
	return clampi(SpellProgress.accuracy_for_correct(spell_id, correct_count) + accuracy_bonus, 0, 100)

# --- Turn flow -------------------------------------------------------------

## Call at the start of each player turn (mana comes back after round 1).
func begin_player_turn() -> void:
	if round_number > 1:
		mana = mini(Config.MANA_MAX, mana + Config.MANA_REGEN)

func end_round() -> void:
	round_number += 1

# --- Casting ---------------------------------------------------------------

func _shuffled(items: Array) -> Array:
	var a: Array = items.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a

func _question(kind: String, word_id: String, prompt: String, correct: String, distractors: Array) -> Dictionary:
	var options: Array = [correct]
	var es_of := {correct: correct}
	for d in distractors:
		options.append(d.es)
		es_of[d.es] = d.es
	return {
		"kind": kind, "word_id": word_id, "prompt": prompt, "direction": "en_to_es",
		"correct": correct, "options": _shuffled(options), "es_of": es_of,
	}

## A slot question that adapts to the player: more options at higher mastery,
## sometimes reversed at Master+, distractors drawn from past confusions.
func _slot_question(slot: Dictionary, tier: int) -> Dictionary:
	var count: int = 4 if tier >= Config.FOUR_OPTIONS_TIER else 3
	var wrong: Array = Distractors.wrong_options(slot, count, rng)
	var reverse: bool = tier >= Config.REVERSE_TIER and rng.randf() < Config.REVERSE_CHANCE
	var options: Array = []
	var es_of := {}
	var all: Array = [{"es": slot.es, "en": slot.en}] + wrong
	for d in all:
		var shown: String = d.en if reverse else d.es
		if not options.has(shown):
			options.append(shown)
			es_of[shown] = d.es
	return {
		"kind": "slot", "word_id": slot.word_id,
		"prompt": slot.es if reverse else slot.en,
		"direction": "es_to_en" if reverse else "en_to_es",
		"correct": slot.en if reverse else slot.es,
		"options": _shuffled(options), "es_of": es_of,
	}

## One question per slot of the spell's sentence, plus the combine question
## when a queued Furia applies to this attack.
func build_questions(spell_id: String) -> Array:
	var spell := SpellBank.get_spell(spell_id)
	var tier := SpellProgress.tier_index(spell_id)
	var questions: Array = []
	for slot in spell.slots:
		questions.append(_slot_question(slot, tier))
	if fury_applies(spell_id):
		var phrase: Dictionary = spell.combined.phrase
		questions.append(_question("combine", phrase.word_id, phrase.en, phrase.es, phrase.distractors))
	return questions

## A random wrong option not already eliminated, or "" if none is left.
func hint_target(question: Dictionary, eliminated: Array) -> String:
	var candidates: Array = question.options.filter(
		func(o): return o != question.correct and not eliminated.has(o))
	if candidates.is_empty():
		return ""
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func damage_enemy(index: int, amount: int) -> Dictionary:
	var e: Dictionary = enemies[index]
	var absorbed := mini(e.shield, amount)
	e.shield -= absorbed
	var dealt := amount - absorbed
	e.hp = maxi(0, e.hp - dealt)
	return {"kind": "damage", "target": index, "name": e.name, "amount": dealt, "absorbed": absorbed, "killed": e.hp <= 0}

func _pick_target(target: int) -> int:
	var alive := living()
	if alive.has(target):
		return target
	return alive[0] if not alive.is_empty() else -1

## Resolves a finished cast. `combine_result`: -1 no combine question,
## 0 wrong, 1 right. `forced_roll` (1-100) is for tests.
func resolve_cast(spell_id: String, correct_count: int, combine_result: int, target: int, hints_used: int, forced_roll: int = -1) -> Dictionary:
	var spell := SpellBank.get_spell(spell_id)
	var cost: int = spell.mana_cost
	var acc := accuracy(spell_id, correct_count)
	var roll := forced_roll if forced_roll > 0 else rng.randi_range(1, 100)
	var hit := roll <= acc
	var result := {
		"spell_id": spell_id, "accuracy": acc, "roll": roll, "hit": hit,
		"hints": hints_used, "bonus_pct": 0, "events": [],
	}

	mana -= cost + hints_used
	if not hit and Config.FIZZLE_REFUNDS_MANA:
		mana += cost
	if hit or Config.FIZZLE_CONSUMES_SLOT:
		loadout[spell_id] = maxi(0, uses_left(spell_id) - 1)

	var buffed := fury_applies(spell_id)
	if not hit:
		if buffed and not Config.FURIA_SURVIVES_FIZZLE:
			fury_pending = false
		return result

	var power: int = spell.power
	match spell.type:
		"attack":
			if buffed:
				result.bonus_pct = SpellBank.COMBINE_BONUS_RIGHT if combine_result == 1 else SpellBank.COMBINE_BONUS_WRONG
				fury_pending = false
			var amount := int(round(power * (100 + result.bonus_pct) / 100.0))
			var targets: Array = living() if spell.target == "all" else [_pick_target(target)]
			for t in targets:
				result.events.append(damage_enemy(t, amount))
		"shield":
			shield += power
			result.events.append({"kind": "shield", "amount": power})
		"heal":
			var healed := mini(power, player_max_hp - player_hp)
			player_hp += healed
			result.events.append({"kind": "heal", "amount": healed})
		"buff":
			fury_pending = true
			result.events.append({"kind": "fury"})
	return result

## The always-available fallback: no quiz, no mana, always hits.
func resolve_struggle(target: int) -> Dictionary:
	var t := _pick_target(target)
	return {"events": [damage_enemy(t, Config.STRUGGLE_DAMAGE)], "hit": true}

# --- Enemy side ------------------------------------------------------------

## One enemy casts a random spell from its pool.
func enemy_action(index: int) -> Dictionary:
	var e: Dictionary = enemies[index]
	var spell: Dictionary = e.spells[rng.randi_range(0, e.spells.size() - 1)]
	var result := {"enemy": index, "name": e.name, "spell": spell, "taken": 0, "absorbed": 0, "gained": 0}
	match spell.kind:
		"attack":
			var absorbed := mini(shield, spell.power)
			shield -= absorbed
			var taken: int = spell.power - absorbed
			player_hp = maxi(player_hp - taken, maxi(hp_floor, 0))
			result.taken = taken
			result.absorbed = absorbed
		"shield":
			e.shield += spell.power
			result.gained = spell.power
		"heal":
			var healed := mini(spell.power, e.max_hp - e.hp)
			e.hp += healed
			result.gained = healed
	return result
