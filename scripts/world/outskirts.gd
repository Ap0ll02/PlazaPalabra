extends Node2D
## Stub for the tutorial start ("you wake up on the outskirts"). Movement,
## scavenging, and the walk into town get built here next.
##
## The dev-only continue button exists purely so the consent -> pre-survey
## -> [gameplay] -> post-survey -> recall quiz -> thank-you pipeline is
## testable end to end before quests/tutorial gameplay exist. Remove it
## once the real Ending beat can trigger PostSurvey.tscn itself.

@onready var dev_continue_button: Button = $DevContinueButton

func _ready() -> void:
	GameState.set_quest_stage("tutorial")
	dev_continue_button.pressed.connect(_on_dev_continue_pressed)

func _on_dev_continue_pressed() -> void:
	# Simulate a little gameplay so the recall quiz has something to ask.
	for word_id in ["roca", "agua", "lanzar", "fuerte"]:
		PlayerProfile.record_seen(word_id)
	get_tree().change_scene_to_file("res://scenes/ui/PostSurvey.tscn")
