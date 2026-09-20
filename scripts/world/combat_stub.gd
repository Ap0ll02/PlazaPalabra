extends Node2D
## Placeholder for the boss fight (sentence-building combat). Replace this
## scene with the real combat system. The [DEV] button stands in for
## "win the fight" so the study pipeline stays testable end to end.

@onready var dev_win_button: Button = $DevWinButton

func _ready() -> void:
	GameState.set_quest_stage("boss")
	dev_win_button.pressed.connect(_on_dev_win_pressed)

func _on_dev_win_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/PostSurvey.tscn")
