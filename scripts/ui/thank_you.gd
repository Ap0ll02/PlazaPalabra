extends Control

@onready var data_dir_label: Label = $VBox/DataDirLabel
@onready var return_button: Button = $VBox/ReturnButton

func _ready() -> void:
	StudySession.write_session_summary()
	StudySession.log_event("session_complete")
	data_dir_label.text = "Session data: %s" % StudySession.get_data_dir()
	return_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)
