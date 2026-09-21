extends Node2D
## Quest 1: talk to Mira, search the market stalls for a clue, report
## back, get sent to Tomas. Quest 2 begins when Tomas points you at the
## ruins, which reveals the east exit. Dialogue content lives in the NPC
## scripts (scripts/world/npcs/*.gd) -- this scene just reacts to the
## actions those dialogues broadcast.
##
## The [DEV] button is a fast-path fallback for testing without walking
## the whole quest each time.

@onready var dev_continue_button: Button = $DevContinueButton
@onready var ruins_exit: Area2D = $RuinsExit

func _ready() -> void:
	add_to_group("gameplay_scene")
	GameState.set_quest_stage("quest_1")
	Dialogue.action_triggered.connect(_on_dialogue_action)
	ruins_exit.body_entered.connect(_on_ruins_exit_entered)
	dev_continue_button.pressed.connect(_on_dev_continue_pressed)

func _on_dialogue_action(action: String) -> void:
	match action:
		"start_quest_1":
			GameState.set_flag("quest_1_started", true)
			_reveal_search_spots()
		"start_quest_2_handoff":
			GameState.set_flag("quest_2_handoff", true)
		"start_quest_2":
			GameState.set_flag("quest_2_started", true)
			GameState.set_quest_stage("quest_2")
			_reveal_ruins_exit()

func _reveal_search_spots() -> void:
	for spot in get_tree().get_nodes_in_group("search_spots"):
		spot.visible = true
		spot.set_deferred("monitoring", true)

func _reveal_ruins_exit() -> void:
	ruins_exit.visible = true
	ruins_exit.set_deferred("monitoring", true)

func _on_ruins_exit_entered(body: Node) -> void:
	if body.is_in_group("player"):
		get_tree().change_scene_to_file("res://scenes/world/Ruins.tscn")

func _on_dev_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/PostSurvey.tscn")
