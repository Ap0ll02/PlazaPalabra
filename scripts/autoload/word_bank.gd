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
	"nota": {
		"spanish": "nota", "english": "note", "role": "noun",
		"example_es": "Encuentro una nota.", "example_en": "I find a note.",
	},
	"ustedes": {
		"spanish": "ustedes", "english": "you all", "role": "pronoun",
		"example_es": "Ustedes sienten frío.", "example_en": "You all feel cold.",
	},
	"sentir": {
		"spanish": "sentir", "english": "to feel", "role": "verb",
		"example_es": "Ustedes sienten frío.", "example_en": "You all feel cold.",
	},
	"frio": {
		"spanish": "frío", "english": "cold", "role": "noun",
		"example_es": "Ustedes sienten frío.", "example_en": "You all feel cold.",
	},
	"bola_fuego": {
		"spanish": "bola de fuego", "english": "fireball", "role": "noun",
		"example_es": "Yo lanzo una bola de fuego.", "example_en": "I throw a fireball.",
	},
	"rayo": {
		"spanish": "rayo", "english": "lightning bolt", "role": "noun",
		"example_es": "Yo disparo un rayo.", "example_en": "I shoot a lightning bolt.",
	},
	"ganar": {
		"spanish": "ganar", "english": "to gain", "role": "verb",
		"example_es": "Yo gano fuerza.", "example_en": "I gain strength.",
	},
	"fuerza": {
		"spanish": "fuerza", "english": "strength", "role": "noun",
		"example_es": "Yo gano fuerza.", "example_en": "I gain strength.",
	},
	"me": {
		"spanish": "me", "english": "myself", "role": "pronoun",
		"example_es": "Yo me sano.", "example_en": "I heal myself.",
	},
	"sanar": {
		"spanish": "sanar", "english": "to heal", "role": "verb",
		"example_es": "Yo me sano.", "example_en": "I heal myself.",
	},
	"proteger": {
		"spanish": "proteger", "english": "to protect", "role": "verb",
		"example_es": "Yo me protejo.", "example_en": "I protect myself.",
	},
	"con_fuerza": {
		"spanish": "con fuerza", "english": "with force", "role": "phrase",
		"example_es": "Yo lanzo una bola de fuego con fuerza.", "example_en": "I throw a fireball with force.",
	},
	"hielo_golpea": {
		"spanish": "y el hielo los golpea", "english": "and the ice hits them", "role": "phrase",
		"example_es": "Ustedes sienten frío y el hielo los golpea.", "example_en": "You all feel cold and the ice hits you.",
	},
	"yo": {
		"spanish": "yo", "english": "I", "role": "pronoun",
		"example_es": "Yo lanzo una bola de fuego.", "example_en": "I throw a fireball.",
	},
	"disparar": {
		"spanish": "disparar", "english": "to shoot", "role": "verb",
		"example_es": "Yo disparo un rayo.", "example_en": "I shoot a lightning bolt.",
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
