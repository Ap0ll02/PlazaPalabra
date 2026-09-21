extends RefCounted
## Encounter definitions. Add an entry to make a new fight.
##
##   title          shown at the top of the battle screen
##   accuracy_bonus flat % added to every cast (used to soften the tutorial)
##   hp_floor       if > 0 the player can't drop below this HP (can't lose)
##   start_mana     mana on turn one (defaults to MANA_MAX)
##   loadout        spell_id -> number of uses this fight
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
}

static func get_encounter(encounter_id: String) -> Dictionary:
	return ENCOUNTERS.get(encounter_id, {})
