extends Node
## Static spell data + the tuning numbers for spells and mastery. All the
## numbers you'd want to tweak while playtesting are in the "Tuning"
## section; spells are plain dictionaries below it, so adding one (e.g.
## the still-undecided third attack) means adding one entry to SPELLS.
##
## Each spell is a 3-slot sentence (subject / verb / object). The same
## three slots drive the lesson builder and the cast quiz (one question per
## slot). `word_id` links a slot to WordBank so per-word mastery tracking
## works; `distractors` are the wrong-but-plausible options shown next to
## the correct one.
##
## power meaning by type:
##   attack -> damage dealt       shield -> damage absorbed
##   heal   -> HP restored        buff   -> % bonus on the next attack

# --- Tuning -------------------------------------------------------------

## Accuracy added for the 1st, 2nd, 3rd correct cast-quiz answer.
const STEP_BONUSES := [35, 25, 15]

## Mastery tiers, keyed by number of practice builds. Parallel arrays.
const TIER_NAMES := ["Novice", "Adept", "Advanced", "Master", "Grandmaster"]
const TIER_THRESHOLDS := [0, 4, 10, 15, 25]
## Flat accuracy added to a spell's base accuracy at each tier.
const TIER_ACCURACY_BONUS := [0, 5, 10, 15, 20]
## How many copies of the spell fit in a loadout at each tier.
const TIER_COPIES := [1, 2, 3, 4, 5]

const TYPE_LABELS := {
	"attack": "Attack", "shield": "Shield", "heal": "Heal", "buff": "Buff",
}
const TYPE_COLORS := {
	"attack": Color(0.9, 0.4, 0.35),
	"shield": Color(0.4, 0.6, 0.95),
	"heal": Color(0.45, 0.8, 0.5),
	"buff": Color(0.95, 0.8, 0.35),
}

# --- Spells -------------------------------------------------------------
# "source" records where the player learns it (data only, for now).

const SPELLS := {
	"rock_throw": {
		"name": "Rock Throw", "type": "attack", "source": "tutorial",
		"sentence_es": "Yo lanzo una roca", "sentence_en": "I throw a rock",
		"mana_cost": 2, "base_accuracy": 30, "power": 12,
		"slots": [
			{"role": "subject", "word_id": "yo", "es": "Yo", "en": "I",
				"distractors": [{"es": "Tú", "en": "you"}, {"es": "Ustedes", "en": "you all"}]},
			{"role": "verb", "word_id": "lanzar", "es": "lanzo", "en": "throw",
				"distractors": [{"es": "lanzas", "en": "you throw"}, {"es": "lanzamos", "en": "we throw"}]},
			{"role": "object", "word_id": "roca", "es": "una roca", "en": "a rock",
				"distractors": [{"es": "un árbol", "en": "a tree"}, {"es": "una nota", "en": "a note"}]},
		],
	},
	"arrow_shot": {
		"name": "Arrow Shot", "type": "attack", "source": "tomas",
		"sentence_es": "Yo disparo una flecha", "sentence_en": "I shoot an arrow",
		"mana_cost": 3, "base_accuracy": 20, "power": 20,
		"slots": [
			{"role": "subject", "word_id": "yo", "es": "Yo", "en": "I",
				"distractors": [{"es": "Tú", "en": "you"}, {"es": "Ustedes", "en": "you all"}]},
			{"role": "verb", "word_id": "disparar", "es": "disparo", "en": "shoot",
				"distractors": [{"es": "disparas", "en": "you shoot"}, {"es": "disparan", "en": "they shoot"}]},
			{"role": "object", "word_id": "flecha", "es": "una flecha", "en": "an arrow",
				"distractors": [{"es": "una roca", "en": "a rock"}, {"es": "una flor", "en": "a flower"}]},
		],
	},
	"drink_water": {
		"name": "Drink Water", "type": "heal", "source": "quest_1",
		"sentence_es": "Yo bebo agua", "sentence_en": "I drink water",
		"mana_cost": 3, "base_accuracy": 40, "power": 20,
		"slots": [
			{"role": "subject", "word_id": "yo", "es": "Yo", "en": "I",
				"distractors": [{"es": "Tú", "en": "you"}, {"es": "Ustedes", "en": "you all"}]},
			{"role": "verb", "word_id": "beber", "es": "bebo", "en": "drink",
				"distractors": [{"es": "bebes", "en": "you drink"}, {"es": "bebemos", "en": "we drink"}]},
			{"role": "object", "word_id": "agua", "es": "agua", "en": "water",
				"distractors": [{"es": "pan", "en": "bread"}, {"es": "fuego", "en": "fire"}]},
		],
	},
	"raise_shield": {
		"name": "Raise Shield", "type": "shield", "source": "tomas",
		"sentence_es": "Yo levanto un escudo", "sentence_en": "I raise a shield",
		"mana_cost": 2, "base_accuracy": 25, "power": 15,
		"slots": [
			{"role": "subject", "word_id": "yo", "es": "Yo", "en": "I",
				"distractors": [{"es": "Tú", "en": "you"}, {"es": "Ustedes", "en": "you all"}]},
			{"role": "verb", "word_id": "levantar", "es": "levanto", "en": "raise",
				"distractors": [{"es": "levantas", "en": "you raise"}, {"es": "levantamos", "en": "we raise"}]},
			{"role": "object", "word_id": "escudo", "es": "un escudo", "en": "a shield",
				"distractors": [{"es": "una espada", "en": "a sword"}, {"es": "un árbol", "en": "a tree"}]},
		],
	},
	"strength_potion": {
		"name": "Strength Potion", "type": "buff", "source": "quest_1",
		"sentence_es": "Yo bebo una poción de fuerza", "sentence_en": "I drink a strength potion",
		"mana_cost": 3, "base_accuracy": 25, "power": 50,
		"slots": [
			{"role": "subject", "word_id": "yo", "es": "Yo", "en": "I",
				"distractors": [{"es": "Tú", "en": "you"}, {"es": "Ustedes", "en": "you all"}]},
			{"role": "verb", "word_id": "beber", "es": "bebo", "en": "drink",
				"distractors": [{"es": "bebes", "en": "you drink"}, {"es": "bebemos", "en": "we drink"}]},
			{"role": "object", "word_id": "pocion_fuerza", "es": "una poción de fuerza", "en": "a strength potion",
				"distractors": [{"es": "una poción de fuego", "en": "a fire potion"}, {"es": "una flecha", "en": "an arrow"}]},
		],
	},
}

func has_spell(spell_id: String) -> bool:
	return SPELLS.has(spell_id)

func get_spell(spell_id: String) -> Dictionary:
	return SPELLS.get(spell_id, {})

func all_ids() -> Array:
	return SPELLS.keys()

func type_color(spell_id: String) -> Color:
	return TYPE_COLORS.get(get_spell(spell_id).get("type", ""), Color.WHITE)

func effect_text(spell_id: String) -> String:
	var spell := get_spell(spell_id)
	var power: int = spell.get("power", 0)
	match spell.get("type", ""):
		"attack": return "Deals %d damage" % power
		"shield": return "Absorbs %d damage" % power
		"heal": return "Restores %d HP" % power
		"buff": return "Next attack +%d%% damage" % power
	return ""
