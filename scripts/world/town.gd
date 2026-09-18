extends Node2D
## Quest 1: talk to Mira, search the market stalls for a clue, report
## back, get sent to Tomas. Dialogue content lives in the NPC scripts
## (scripts/world/npcs/*.gd) -- this scene just reacts to the actions
## those dialogues broadcast.
##
## The [DEV] button is a fast-path fallback for testing without walking
## the whole quest each time; Tomas's dialogue is the "real" path and
## currently ends the same place until Quest 2 exists.

@onready var dev_continue_button: Button = $DevContinueButton

func _ready() -> void:
	GameState.set_quest_stage("quest_1")
	Dialogue.action_triggered.connect(_on_dialogue_action)
	dev_continue_button.pressed.connect(_on_dev_continue_pressed)

func _on_dialogue_action(action: String) -> void:
	match action:
		"start_quest_1":
			GameState.set_flag("quest_1_started", true)
			_reveal_search_spots()
		"start_quest_2_handoff":
			GameState.set_flag("quest_2_handoff", true)
		"quest_2_dev_bridge":
			get_tree().change_scene_to_file("res://scenes/ui/PostSurvey.tscn")

func _reveal_search_spots() -> void:
	for spot in get_tree().get_nodes_in_group("search_spots"):
		spot.visible = true
		spot.set_deferred("monitoring", true)

func _on_dev_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/PostSurvey.tscn")
