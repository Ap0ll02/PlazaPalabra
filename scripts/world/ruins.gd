extends Node2D
## Quest 2: the ruins. One optional hidden scroll (Tormenta de Hielo, see
## the IceScroll node) and Sombra, who starts the boss fight when spoken to.

var _pending_scene := ""

func _ready() -> void:
	add_to_group("gameplay_scene")
	GameState.set_quest_stage("quest_2")
	Dialogue.action_triggered.connect(_on_dialogue_action)
	Dialogue.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_action(action: String) -> void:
	if action == "start_boss_fight":
		# Wait for the dialogue to close before leaving, otherwise the box
		# stays open over the next scene.
		_pending_scene = "res://scenes/world/Combat.tscn"

func _on_dialogue_ended() -> void:
	if _pending_scene != "":
		get_tree().change_scene_to_file(_pending_scene)
