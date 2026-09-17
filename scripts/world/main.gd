extends Control
## Boot scene sanity check: confirms autoloads (PlayerProfile, GameState,
## WordBank) are wired up correctly. Replace with the real outskirts/intro
## scene once world content exists.

@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	var word_count := WordBank.all_word_ids().size()
	PlayerProfile.record_seen("fuerte")
	var hint_cost := PlayerProfile.get_hint_cost("fuerte")

	status_label.text = "PlazaPalabra -- boot OK\n" \
		+ "Word bank: %d words loaded\n" % word_count \
		+ "GameState.quest_stage: %s\n" % GameState.quest_stage \
		+ "GameState.hp: %d/%d\n" % [GameState.hp, GameState.MAX_HP] \
		+ "PlayerProfile hint cost for 'fuerte' (1st seen): %.0f%%" % (hint_cost * 100.0)
