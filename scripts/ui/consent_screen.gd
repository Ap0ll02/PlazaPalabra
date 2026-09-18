extends Control
## PLACEHOLDER consent text -- swap in the real IRB-approved language
## before running an actual study session.

@onready var agree_button: Button = $Margin/VBox/ButtonRow/AgreeButton
@onready var decline_button: Button = $Margin/VBox/ButtonRow/DeclineButton

func _ready() -> void:
	agree_button.pressed.connect(_on_agree)
	decline_button.pressed.connect(_on_decline)

func _on_agree() -> void:
	StudySession.log_event("consent_given")
	get_tree().change_scene_to_file("res://scenes/ui/PreSurvey.tscn")

func _on_decline() -> void:
	StudySession.log_event("consent_declined")
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
