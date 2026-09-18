extends Node2D
## Stub for Quest 1 (the theft/NPC). The [DEV] bridge exists purely so the
## consent -> ... -> post-survey pipeline stays testable before quest
## content exists -- remove once the real Ending beat triggers
## PostSurvey.tscn itself.

@onready var dev_continue_button: Button = $DevContinueButton

func _ready() -> void:
	GameState.set_quest_stage("quest_1")
	dev_continue_button.pressed.connect(_on_dev_continue_pressed)

func _on_dev_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/PostSurvey.tscn")
