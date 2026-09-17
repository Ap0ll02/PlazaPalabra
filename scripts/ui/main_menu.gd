extends Control

@onready var play_button: Button = $CenterContainer/VBox/PlayButton
@onready var settings_button: Button = $CenterContainer/VBox/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBox/QuitButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.grab_focus()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/Intro.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SettingsMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
