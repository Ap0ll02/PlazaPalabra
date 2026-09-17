extends Control

@onready var volume_slider: HSlider = $CenterContainer/VBox/VolumeRow/VolumeSlider
@onready var captions_check: CheckButton = $CenterContainer/VBox/CaptionsRow/CaptionsCheck
@onready var back_button: Button = $CenterContainer/VBox/BackButton

func _ready() -> void:
	volume_slider.value = Settings.master_volume
	captions_check.button_pressed = Settings.captions_enabled

	volume_slider.value_changed.connect(Settings.set_master_volume)
	captions_check.toggled.connect(Settings.set_captions_enabled)
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
