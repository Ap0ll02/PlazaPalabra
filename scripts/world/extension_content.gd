extends Node2D
## Stub for the Week-2 "recap survives -> harder content" extension.
## Once combat exists, this becomes a harder variant of it (added
## vocabulary, tougher enemy) rather than a bespoke new scene -- the
## whole point of "light extension" is reusing Week-1's systems, not
## authoring a second quest arc.

@onready var dev_continue_button: Button = $DevContinueButton

func _ready() -> void:
	dev_continue_button.pressed.connect(_on_dev_continue_pressed)

func _on_dev_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/FollowUpSurvey.tscn")
