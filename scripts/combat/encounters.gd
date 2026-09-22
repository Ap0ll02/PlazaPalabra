extends RefCounted
## Encounter definitions. Add an entry to make a new fight.
##
##   title          shown at the top of the battle screen
##   accuracy_bonus flat % added to every cast (used to soften the tutorial)
##   hp_floor       if > 0 the player can't drop below this HP (can't lose)
##   start_mana     mana on turn one (defaults to MANA_MAX)
##   loadout        spell_id -> number of uses this fight
##   use_book       true = ignore `loadout` and use the player's spellbook
##                  (SpellProgress.book); the fight can't start with it empty
##   win            "all" (every enemy) or "boss" (any enemy marked boss)
##   enemies        name, hp, color, boss (optional), spells: each a Spanish
##                  line `es`, its English `en`, a `kind` (attack / shield /
##                  heal) and a `power`

const ENCOUNTERS := {
	"bandit_tutorial": {
		"title": "Ambush!",
		"accuracy_bonus": 50,
		"hp_floor": 1,
		"start_mana": 8,
		"loadout": {"bola_de_fuego": 4},
		"win": "all",
		"enemies": [
			{
				"name": "Bandit", "hp": 50, "color": Color(0.55, 0.4, 0.3),
				"spells": [
					{"es": "¡Te golpeo!", "en": "I hit you!", "kind": "attack", "power": 6},
					{"es": "¡Te empujo!", "en": "I push you!", "kind": "attack", "power": 4},
				],
			},
		],
	},
	# --- Week 2 ---
	"bandits_week2": {
		"title": "Bandits in town!",
		"use_book": true,
		"win": "all",
		"enemies": [
			{"name": "Bandit", "hp": 14, "color": Color(0.55, 0.4, 0.3), "spells": [
				{"es": "¡Te golpeo!", "en": "I hit you!", "kind": "attack", "power": 5},
				{"es": "¡Te empujo!", "en": "I push you!", "kind": "attack", "power": 3},
			]},
			{"name": "Bandit Chief", "hp": 20, "color": Color(0.45, 0.32, 0.26), "spells": [
				{"es": "¡Te golpeo!", "en": "I hit you!", "kind": "attack", "power": 6},
				{"es": "¡Me protejo!", "en": "I protect myself!", "kind": "shield", "power": 8},
			]},
			{"name": "Bandit", "hp": 14, "color": Color(0.5, 0.42, 0.34), "spells": [
				{"es": "¡Te pateo!", "en": "I kick you!", "kind": "attack", "power": 5},
				{"es": "¡Te empujo!", "en": "I push you!", "kind": "attack", "power": 3},
			]},
		],
	},
	# Optional: the jaguar guards a scroll (Terremoto Violento).
	"jaguar_optional": {
		"title": "The Jaguar",
		"use_book": true,
		"win": "all",
		"enemies": [
			{"name": "Jaguar", "hp": 100, "color": Color(0.85, 0.6, 0.25), "spells": [
				{"es": "¡Te muerdo!", "en": "I bite you!", "kind": "attack", "power": 13},
				{"es": "¡Te araño!", "en": "I scratch you!", "kind": "attack", "power": 11},
				{"es": "¡Me protejo!", "en": "I protect myself!", "kind": "shield", "power": 12},
			]},
		],
	},
	# Sombra returns: more HP, bigger moves, and a stronger set below half HP
	# whose lines use this week's adjectives.
	"sombra_returns": {
		"title": "Sombra Returns",
		"use_book": true,
		"win": "boss",
		"enemies": [
			{
				"name": "Sombra", "hp": 85, "color": Color(0.3, 0.2, 0.42), "boss": true,
				"spells": [
					{"es": "¡Te golpeo!", "en": "I hit you!", "kind": "attack", "power": 9},
					{"es": "¡Te lanzo una piedra pesada!", "en": "I throw a heavy rock at you!", "kind": "attack", "power": 13},
					{"es": "¡Me protejo!", "en": "I protect myself!", "kind": "shield", "power": 15},
					{"es": "¡Me curo!", "en": "I heal myself!", "kind": "heal", "power": 10},
				],
				"phase2": {
					"hp_pct": 50, "es": "¡Ahora sí!", "en": "Now I'm serious!",
					"spells": [
						{"es": "¡Te golpeo con fuerza!", "en": "I hit you with force!", "kind": "attack", "power": 13},
						{"es": "¡Te lanzo un rayo violento!", "en": "I throw a violent lightning bolt at you!", "kind": "attack", "power": 16},
						{"es": "¡Me protejo!", "en": "I protect myself!", "kind": "shield", "power": 18},
						{"es": "¡Me curo!", "en": "I heal myself!", "kind": "heal", "power": 14},
					],
				},
			},
		],
	},
	# Boss: fights with the player's spellbook; defeating Sombra wins even if
	# the minions are still standing.
	"sombra_boss": {
		"title": "Sombra",
		"use_book": true,
		"win": "boss",
		"enemies": [
			{"name": "Thug", "hp": 20, "color": Color(0.5, 0.38, 0.32), "spells": [
				{"es": "¡Te golpeo!", "en": "I hit you!", "kind": "attack", "power": 4},
				{"es": "¡Te empujo!", "en": "I push you!", "kind": "attack", "power": 3},
			]},
			{
				"name": "Sombra", "hp": 60, "color": Color(0.35, 0.25, 0.45), "boss": true,
				"spells": [
					{"es": "¡Te golpeo!", "en": "I hit you!", "kind": "attack", "power": 7},
					{"es": "¡Te lanzo una piedra!", "en": "I throw a rock at you!", "kind": "attack", "power": 10},
					{"es": "¡Me protejo!", "en": "I protect myself!", "kind": "shield", "power": 12},
					{"es": "¡Me curo!", "en": "I heal myself!", "kind": "heal", "power": 10},
				],
			},
			{"name": "Lookout", "hp": 20, "color": Color(0.42, 0.45, 0.38), "spells": [
				{"es": "¡Te pateo!", "en": "I kick you!", "kind": "attack", "power": 5},
				{"es": "¡Te empujo!", "en": "I push you!", "kind": "attack", "power": 3},
			]},
		],
	},
}

static func get_encounter(encounter_id: String) -> Dictionary:
	return ENCOUNTERS.get(encounter_id, {})
