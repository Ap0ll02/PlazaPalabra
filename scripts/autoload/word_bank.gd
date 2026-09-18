extends Node
## Curated word bank, grouped by grammatical/combat role (see design doc
## sec. 03 combat + sec. 06 AI hooks: the AI layer SELECTS from this bank,
## it does not generate vocabulary freely). Placeholder starter content --
## expand per scene as quest content is authored.
##
## role values: "noun", "attack", "blade", "trap", "shield", "heal"

## word_id -> { spanish, english, role, example_es, example_en }
var _words: Dictionary = {
	"roca": {
		"spanish": "roca", "english": "rock", "role": "noun",
		"example_es": "Encuentro una roca.", "example_en": "I find a rock.",
	},
	"agua": {
		"spanish": "agua", "english": "water", "role": "noun",
		"example_es": "Necesito agua.", "example_en": "I need water.",
	},
	"arbol": {
		"spanish": "árbol", "english": "tree", "role": "noun",
		"example_es": "Hay un árbol aquí.", "example_en": "There is a tree here.",
	},
	"lanzar": {
		"spanish": "lanzar", "english": "to throw", "role": "attack",
		"example_es": "Yo lanzo la roca.", "example_en": "I throw the rock.",
	},
	"golpear": {
		"spanish": "golpear", "english": "to hit", "role": "attack",
		"example_es": "Yo golpeo al monstruo.", "example_en": "I hit the monster.",
	},
	"fuertemente": {
		"spanish": "fuertemente", "english": "forcefully", "role": "blade",
		"example_es": "Yo lanzo la roca fuertemente.", "example_en": "I throw the rock forcefully.",
	},
	"rapidamente": {
		"spanish": "rápidamente", "english": "quickly", "role": "blade",
		"example_es": "Yo golpeo rápidamente.", "example_en": "I hit quickly.",
	},
	"fuerte": {
		"spanish": "fuerte", "english": "strong", "role": "trap",
		"example_es": "El monstruo es fuerte.", "example_en": "The monster is strong.",
	},
	"debil": {
		"spanish": "débil", "english": "weak", "role": "trap",
		"example_es": "El monstruo es débil.", "example_en": "The monster is weak.",
	},
	"bloquear": {
		"spanish": "bloquear", "english": "to block", "role": "shield",
		"example_es": "Yo voy a bloquear el ataque.", "example_en": "I will block the attack.",
	},
	"descansar": {
		"spanish": "descansar", "english": "to rest", "role": "heal",
		"example_es": "Yo descanso.", "example_en": "I rest.",
	},
	"sentirse_mejor": {
		"spanish": "sentirme mejor", "english": "to feel better", "role": "heal",
		"example_es": "Yo me siento mejor.", "example_en": "I feel better.",
	},
}

func get_word(word_id: String) -> Dictionary:
	return _words.get(word_id, {})

func get_words_by_role(role: String) -> Array:
	var result: Array = []
	for word_id in _words:
		if _words[word_id].role == role:
			result.append(word_id)
	return result

func all_word_ids() -> Array:
	return _words.keys()
