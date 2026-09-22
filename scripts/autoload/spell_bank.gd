extends Node
## Static spell data + the tuning numbers for spells and mastery. All the
## numbers you'd want to tweak while playtesting are in the "Tuning"
## section; spells are plain dictionaries below it, so adding one means
## adding one entry to SPELLS.
##
## Each spell is a 3-slot sentence. The same three slots drive the lesson
## builder and the cast quiz (one question per slot). `word_id` links a
## slot to WordBank so per-word mastery tracking works; `distractors` are
## the wrong-but-plausible options shown next to the correct one.
##
## Combining: casting Furia (the buff) makes the NEXT attack's sentence
## longer -- each attack's "combined" entry holds the extended sentence and
## the appended `phrase`, which becomes one extra cast question. A correct
## answer earns COMBINE_BONUS_RIGHT, a wrong one COMBINE_BONUS_WRONG (never
## zero). The bonus is extra damage and doesn't touch accuracy.
##
## target: "single" (pick an enemy), "all" (every enemy), "self".
## power meaning by type:
##   attack -> damage (per target)   shield -> damage absorbed
##   heal   -> HP restored           buff   -> unused (see COMBINE_BONUS_*)

# --- Tuning -------------------------------------------------------------

## Accuracy added for the 1st, 2nd, 3rd correct cast-quiz answer.
const STEP_BONUSES := [35, 25, 15]

## Extra damage (%) on a buffed attack, by how the combine question went.
const COMBINE_BONUS_WRONG := 50
const COMBINE_BONUS_RIGHT := 100

## Mastery tiers, keyed by number of practice builds. Parallel arrays.
const TIER_NAMES := ["Novice", "Adept", "Advanced", "Master", "Grandmaster"]
const TIER_THRESHOLDS := [0, 4, 10, 15, 25]
## Flat accuracy added to a spell's base accuracy at each tier.
const TIER_ACCURACY_BONUS := [0, 5, 10, 15, 20]
## How many copies of the spell fit in a loadout at each tier.
const TIER_COPIES := [2, 2, 3, 4, 5]

## The spellbook you carry into a fight: this many slots, one per cast.
## A spell's copies are capped by the LOWER of its tier's TIER_COPIES and
## its type's TYPE_COPY_CAP.
const BOOK_SLOTS := 8
const TYPE_COPY_CAP := {"attack": 2, "buff": 3, "shield": 3, "heal": 2}

const TYPE_LABELS := {
	"attack": "Attack", "shield": "Shield", "heal": "Heal", "buff": "Buff",
}
const TARGET_LABELS := {
	"single": "single target", "all": "all enemies", "self": "self",
}
const TYPE_COLORS := {
	"attack": Color(0.9, 0.4, 0.35),
	"shield": Color(0.4, 0.6, 0.95),
	"heal": Color(0.45, 0.8, 0.5),
	"buff": Color(0.95, 0.8, 0.35),
}

# --- Shared pieces ------------------------------------------------------

const YO_SLOT := {
	"role": "subject", "word_id": "yo", "es": "Yo", "en": "I",
	"distractors": [{"es": "Tú", "en": "you"}, {"es": "Ustedes", "en": "you all"}],
}

## The phrase Furia appends to a normal attack.
const FUERZA_PHRASE := {
	"word_id": "con_fuerza", "es": "con fuerza", "en": "with force",
	"distractors": [{"es": "con fuego", "en": "with fire"}, {"es": "sin fuerza", "en": "without force"}],
}

## Filler distractors by slot role, used when a build wants more choices
## than a spell's own distractors provide (other spells' words are used too).
const EXTRA_DISTRACTORS := {
	"subject": [{"es": "Nosotros", "en": "we"}, {"es": "Ellos", "en": "they"}],
	"reflexive": [{"es": "nos", "en": "ourselves"}],
}

# --- Word order ---------------------------------------------------------
## Each spell has an "order_foil": a plausible wrong ordering (what an English
## speaker might write) and an "order_pattern" that names the rule it breaks.
## The pattern's note is shown after the second miss of that pattern.

const WORD_ORDER_NOTES := {
	"pronoun_before_verb": "In Spanish, the pronoun (me, te, los...) goes BEFORE the verb: \"me protejo\", not \"protejo me\".",
	"verb_before_object": "Spanish keeps the verb before what it acts on: verb first, then the object.",
	"adjective_after_noun": "Spanish usually puts the adjective AFTER the noun: \"rayo supremo\" (bolt supreme), where English says \"supreme bolt\".",
	"noun_before_de_noun": "Spanish names the thing first: \"bola de fuego\" (ball of fire), not \"fire ball\".",
}

# --- Spells -------------------------------------------------------------
# "source" records where the player learns it (data only, for now).

const SPELLS := {
	"bola_de_fuego": {
		"order_foil": "Yo lanzo una fuego bola", "order_pattern": "noun_before_de_noun",
		"name": "Fireball", "name_es": "Bola de Fuego",
		"type": "attack", "target": "single", "source": "tutorial",
		"sentence_es": "Yo lanzo una bola de fuego", "sentence_en": "I throw a fireball",
		# Accepted typed answers: first entry is the canonical sentence.
		"accepted_en": ["I throw a fireball", "I throw a ball of fire", "I throw the fireball", "I cast a fireball", "I am throwing a fireball", "I'm throwing a fireball"],
		"accepted_es": ["Yo lanzo una bola de fuego", "Lanzo una bola de fuego"],
		"mana_cost": 4, "base_accuracy": 15, "power": 25,
		"slots": [
			YO_SLOT,
			{"role": "verb", "word_id": "lanzar", "es": "lanzo", "en": "throw",
				"distractors": [{"es": "lanzas", "en": "you throw"}, {"es": "lanzamos", "en": "we throw"}]},
			{"role": "object", "word_id": "bola_fuego", "es": "una bola de fuego", "en": "a fireball",
				"distractors": [{"es": "una roca", "en": "a rock"}, {"es": "un rayo", "en": "a lightning bolt"}]},
		],
		"combined": {
			"sentence_es": "Yo lanzo una bola de fuego con fuerza",
			"sentence_en": "I throw a fireball with force",
			"phrase": FUERZA_PHRASE,
		},
	},
	"rayo": {
		"order_foil": "Yo un rayo disparo", "order_pattern": "verb_before_object",
		"name": "Lightning Bolt", "name_es": "Rayo",
		"type": "attack", "target": "single", "source": "tomas",
		"sentence_es": "Yo disparo un rayo", "sentence_en": "I shoot a lightning bolt",
		# Accepted typed answers: first entry is the canonical sentence.
		"accepted_en": ["I shoot a lightning bolt", "I shoot lightning", "I fire a lightning bolt", "I shoot a bolt of lightning", "I fire a bolt of lightning", "I shoot a ray", "I am shooting a lightning bolt", "I'm shooting a lightning bolt"],
		"accepted_es": ["Yo disparo un rayo", "Disparo un rayo"],
		"mana_cost": 3, "base_accuracy": 20, "power": 18,
		"slots": [
			YO_SLOT,
			{"role": "verb", "word_id": "disparar", "es": "disparo", "en": "shoot",
				"distractors": [{"es": "disparas", "en": "you shoot"}, {"es": "disparan", "en": "they shoot"}]},
			{"role": "object", "word_id": "rayo", "es": "un rayo", "en": "a lightning bolt",
				"distractors": [{"es": "un trueno", "en": "a thunderclap"}, {"es": "una roca", "en": "a rock"}]},
		],
		"combined": {
			"sentence_es": "Yo disparo un rayo con fuerza",
			"sentence_en": "I shoot a lightning bolt with force",
			"phrase": FUERZA_PHRASE,
		},
	},
	"tormenta_de_hielo": {
		"order_foil": "Ustedes frío sienten", "order_pattern": "verb_before_object",
		"name": "Ice Storm", "name_es": "Tormenta de Hielo",
		"type": "attack", "target": "all", "source": "ruins",
		"sentence_es": "Ustedes sienten frío", "sentence_en": "You all feel cold",
		# Accepted typed answers: first entry is the canonical sentence.
		"accepted_en": ["You all feel cold", "You feel cold", "You guys feel cold", "Y'all feel cold", "You all are feeling cold", "You are all feeling cold"],
		"accepted_es": ["Ustedes sienten frío", "Sienten frío"],
		"mana_cost": 5, "base_accuracy": 10, "power": 10,
		"slots": [
			{"role": "subject", "word_id": "ustedes", "es": "Ustedes", "en": "you all",
				"distractors": [{"es": "Yo", "en": "I"}, {"es": "Tú", "en": "you"}]},
			{"role": "verb", "word_id": "sentir", "es": "sienten", "en": "feel",
				"distractors": [{"es": "siente", "en": "he/she feels"}, {"es": "siento", "en": "I feel"}]},
			{"role": "object", "word_id": "frio", "es": "frío", "en": "cold",
				"distractors": [{"es": "calor", "en": "heat"}, {"es": "miedo", "en": "fear"}]},
		],
		# Hand-crafted instead of "con fuerza": the storm's combined form
		# extends the sentence with a clause of its own.
		"combined": {
			"sentence_es": "Ustedes sienten frío y el hielo los golpea",
			"sentence_en": "You all feel cold and the ice hits you",
			"phrase": {
				"word_id": "hielo_golpea", "es": "y el hielo los golpea", "en": "and the ice hits them",
				"distractors": [
					{"es": "y el fuego los golpea", "en": "and the fire hits them"},
					{"es": "y el hielo lo golpea", "en": "and the ice hits him"},
				],
			},
		},
	},
	"furia": {
		"order_foil": "Yo fuerza gano", "order_pattern": "verb_before_object",
		"name": "Fury", "name_es": "Furia",
		"type": "buff", "target": "self", "source": "quest_1",
		"sentence_es": "Yo gano fuerza", "sentence_en": "I gain strength",
		# Accepted typed answers: first entry is the canonical sentence.
		"accepted_en": ["I gain strength", "I gain power", "I gain force", "I get stronger", "I am gaining strength", "I'm gaining strength"],
		"accepted_es": ["Yo gano fuerza", "Gano fuerza"],
		"mana_cost": 2, "base_accuracy": 30, "power": 0,
		"slots": [
			YO_SLOT,
			{"role": "verb", "word_id": "ganar", "es": "gano", "en": "gain",
				"distractors": [{"es": "ganas", "en": "you gain"}, {"es": "ganamos", "en": "we gain"}]},
			{"role": "object", "word_id": "fuerza", "es": "fuerza", "en": "strength",
				"distractors": [{"es": "fuego", "en": "fire"}, {"es": "miedo", "en": "fear"}]},
		],
	},
	"luz_curativa": {
		"order_foil": "Yo sano me", "order_pattern": "pronoun_before_verb",
		"name": "Healing Light", "name_es": "Luz Curativa",
		"type": "heal", "target": "self", "source": "quest_1",
		"sentence_es": "Yo me sano", "sentence_en": "I heal myself",
		# Accepted typed answers: first entry is the canonical sentence.
		"accepted_en": ["I heal myself", "I cure myself", "I am healing myself", "I'm healing myself", "I heal"],
		"accepted_es": ["Yo me sano", "Me sano"],
		"mana_cost": 3, "base_accuracy": 40, "power": 25,
		"slots": [
			YO_SLOT,
			{"role": "reflexive", "word_id": "me", "es": "me", "en": "myself",
				"distractors": [{"es": "te", "en": "yourself"}, {"es": "se", "en": "himself/herself"}]},
			{"role": "verb", "word_id": "sanar", "es": "sano", "en": "heal",
				"distractors": [{"es": "sanas", "en": "you heal"}, {"es": "sanamos", "en": "we heal"}]},
		],
	},
	# --- Week 2: adjective placement (noun THEN adjective, unlike English) ---
	"rayo_supremo": {
		"order_foil": "Yo disparo un supremo rayo", "order_pattern": "adjective_after_noun",
		"name": "Supreme Bolt", "name_es": "Rayo Supremo",
		"type": "attack", "target": "single", "source": "week2_bandits",
		"sentence_es": "Yo disparo un rayo supremo", "sentence_en": "I shoot a supreme lightning bolt",
		"accepted_en": ["I shoot a supreme lightning bolt", "I fire a supreme lightning bolt", "I shoot a supreme bolt", "I shoot a supreme bolt of lightning", "I am shooting a supreme lightning bolt", "I'm shooting a supreme lightning bolt"],
		"accepted_es": ["Yo disparo un rayo supremo", "Disparo un rayo supremo"],
		"mana_cost": 5, "base_accuracy": 15, "power": 34,
		"slots": [
			YO_SLOT,
			{"role": "verb", "word_id": "disparar", "es": "disparo", "en": "shoot",
				"distractors": [{"es": "disparas", "en": "you shoot"}, {"es": "disparan", "en": "they shoot"}]},
			{"role": "object", "word_id": "rayo_supremo", "es": "un rayo supremo", "en": "a supreme lightning bolt",
				"distractors": [{"es": "un supremo rayo", "en": "a supreme lightning bolt"}, {"es": "un rayo violento", "en": "a violent lightning bolt"}]},
		],
		"combined": {
			"sentence_es": "Yo disparo un rayo supremo con fuerza",
			"sentence_en": "I shoot a supreme lightning bolt with force",
			"phrase": FUERZA_PHRASE,
		},
	},
	"terremoto_violento": {
		"order_foil": "Tú sientes un violento terremoto", "order_pattern": "adjective_after_noun",
		"name": "Violent Quake", "name_es": "Terremoto Violento",
		"type": "attack", "target": "all", "source": "week2_jungle_beast",
		"sentence_es": "Tú sientes un terremoto violento", "sentence_en": "You feel a violent earthquake",
		"accepted_en": ["You feel a violent earthquake", "You are feeling a violent earthquake", "You feel a violent quake", "You feel a violent tremor"],
		"accepted_es": ["Tú sientes un terremoto violento", "Sientes un terremoto violento"],
		"mana_cost": 6, "base_accuracy": 12, "power": 16,
		"slots": [
			{"role": "subject", "word_id": "tu", "es": "Tú", "en": "you",
				"distractors": [{"es": "Yo", "en": "I"}, {"es": "Ustedes", "en": "you all"}]},
			{"role": "verb", "word_id": "sentir", "es": "sientes", "en": "feel",
				"distractors": [{"es": "siento", "en": "I feel"}, {"es": "sienten", "en": "they feel"}]},
			{"role": "object", "word_id": "terremoto_violento", "es": "un terremoto violento", "en": "a violent earthquake",
				"distractors": [{"es": "un violento terremoto", "en": "a violent earthquake"}, {"es": "un terremoto suave", "en": "a gentle earthquake"}]},
		],
		"combined": {
			"sentence_es": "Tú sientes un terremoto violento con fuerza",
			"sentence_en": "You feel a violent earthquake with force",
			"phrase": FUERZA_PHRASE,
		},
	},
	"salud_divina": {
		"order_foil": "Yo tengo divina salud", "order_pattern": "adjective_after_noun",
		"name": "Divine Health", "name_es": "Salud Divina",
		"type": "heal", "target": "self", "source": "week2_jungle_floor",
		"sentence_es": "Yo tengo salud divina", "sentence_en": "I have divine health",
		"accepted_en": ["I have divine health", "I have holy health", "I have divine well-being"],
		"accepted_es": ["Yo tengo salud divina", "Tengo salud divina"],
		"mana_cost": 4, "base_accuracy": 35, "power": 40,
		"slots": [
			YO_SLOT,
			{"role": "verb", "word_id": "tener", "es": "tengo", "en": "have",
				"distractors": [{"es": "tienes", "en": "you have"}, {"es": "tiene", "en": "he/she has"}]},
			{"role": "object", "word_id": "salud_divina", "es": "salud divina", "en": "divine health",
				"distractors": [{"es": "divina salud", "en": "divine health"}, {"es": "salud débil", "en": "weak health"}]},
		],
	},
	"muro_de_piedra": {
		"order_foil": "Yo protejo me", "order_pattern": "pronoun_before_verb",
		"name": "Stone Wall", "name_es": "Muro de Piedra",
		"type": "shield", "target": "self", "source": "tomas",
		"sentence_es": "Yo me protejo", "sentence_en": "I protect myself",
		# Accepted typed answers: first entry is the canonical sentence.
		"accepted_en": ["I protect myself", "I shield myself", "I defend myself", "I guard myself", "I am protecting myself", "I'm protecting myself"],
		"accepted_es": ["Yo me protejo", "Me protejo"],
		"mana_cost": 2, "base_accuracy": 25, "power": 20,
		"slots": [
			YO_SLOT,
			{"role": "reflexive", "word_id": "me", "es": "me", "en": "myself",
				"distractors": [{"es": "te", "en": "yourself"}, {"es": "se", "en": "himself/herself"}]},
			{"role": "verb", "word_id": "proteger", "es": "protejo", "en": "protect",
				"distractors": [{"es": "proteges", "en": "you protect"}, {"es": "protegemos", "en": "we protect"}]},
		],
	},
}

func has_spell(spell_id: String) -> bool:
	return SPELLS.has(spell_id)

func get_spell(spell_id: String) -> Dictionary:
	return SPELLS.get(spell_id, {})

func all_ids() -> Array:
	return SPELLS.keys()

## True for attacks that have an extended "combined" sentence (Furia targets).
func has_combined(spell_id: String) -> bool:
	return get_spell(spell_id).has("combined")

func type_color(spell_id: String) -> Color:
	return TYPE_COLORS.get(get_spell(spell_id).get("type", ""), Color.WHITE)

func effect_text(spell_id: String) -> String:
	var spell := get_spell(spell_id)
	var power: int = spell.get("power", 0)
	match spell.get("type", ""):
		"attack":
			return "Deals %d damage%s" % [power, " to every enemy" if spell.get("target") == "all" else ""]
		"shield": return "Absorbs %d damage" % power
		"heal": return "Restores %d HP" % power
		"buff":
			return "Your next attack does +%d%% damage (+%d%% with the extra question)" % [
				COMBINE_BONUS_WRONG, COMBINE_BONUS_RIGHT]
	return ""
