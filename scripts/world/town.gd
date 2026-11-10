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

## Spells Tomas is teaching, learned one lesson after another.
const TOMAS_SPELLS := ["rayo", "muro_de_piedra"]

var _pending_lessons: Array = []
var _pending_spar := 0

func _ready() -> void:
	add_to_group("gameplay_scene")
	GameState.set_quest_stage("quest_1")
	Dialogue.action_triggered.connect(_on_dialogue_action)
	Dialogue.dialogue_ended.connect(_on_dialogue_ended)
	Lesson.lesson_finished.connect(_on_lesson_finished)
	Combat.finished.connect(_on_combat_finished)
	ruins_exit.body_entered.connect(_on_ruins_exit_entered)
	dev_continue_button.visible = OS.is_debug_build()   # hidden in study (release) builds
	dev_continue_button.pressed.connect(_on_dev_continue_pressed)

func _on_dialogue_action(action: String) -> void:
	match action:
		"start_quest_1":
			GameState.set_flag("quest_1_started", true)
			_reveal_search_spots()
		"start_quest_2_handoff":
			GameState.set_flag("quest_2_handoff", true)
		"teach_spells":
			for id in TOMAS_SPELLS:
				if not SpellProgress.knows(id) and not _pending_lessons.has(id):
					_pending_lessons.append(id)
		"start_quest_2":
			GameState.set_flag("quest_2_started", true)
			GameState.set_quest_stage("quest_2")
			_reveal_ruins_exit()

# Lessons wait for the dialogue to close so the two overlays never stack.
func _on_dialogue_ended() -> void:
	if _pending_spar > 0:
		var spar := _pending_spar
		_pending_spar = 0
		Combat.start("tomas_spar_%d" % spar)
	else:
		_start_next_lesson()

func _on_lesson_finished(_spell_id: String, mode: String) -> void:
	if mode == "learn":
		_start_next_lesson.call_deferred()

func _start_next_lesson() -> void:
	if Lesson.is_open or Dialogue.is_open:
		return
	if not _pending_lessons.is_empty():
		Lesson.start_learn(_pending_lessons.pop_front(), true)
		return
	if GameState.has_flag("quest_2_started") and not GameState.has_flag("tomas_spars_done") and not GameState.has_flag("tomas_spar_1_done"):
		_pending_spar = 1
		Dialogue.show_message("You need practice for such a tough enemy. Fight me!", "Tomas")

func _on_combat_finished(encounter_id: String, won: bool) -> void:
	if not encounter_id.begins_with("tomas_spar") or not won:
		return
	if encounter_id == "tomas_spar_1":
		GameState.set_flag("tomas_spar_1_done")
		_pending_spar = 2
		Dialogue.show_message("Good. Let's try once more before you face Sombra.", "Tomas")
	else:
		GameState.set_flag("tomas_spars_done")
		Dialogue.show_message("Well done, amigo. Now you're ready for Sombra.", "Tomas")

func _reveal_search_spots() -> void:
	for spot in get_tree().get_nodes_in_group("search_spots"):
		spot.visible = true
		spot.set_deferred("monitoring", true)

func _reveal_ruins_exit() -> void:
	ruins_exit.visible = true
	ruins_exit.set_deferred("monitoring", true)

func _on_ruins_exit_entered(body: Node) -> void:
	if body.is_in_group("player") and GameState.has_flag("tomas_spars_done"):
		get_tree().change_scene_to_file("res://scenes/world/Ruins.tscn")

func _on_dev_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/PostSurvey.tscn")
