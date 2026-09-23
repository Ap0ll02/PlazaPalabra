extends Control

@onready var menu_panel: PanelContainer = $MenuPanel
@onready var play_button: Button = $MenuPanel/Margin/VBox/PlayButton
@onready var settings_button: Button = $MenuPanel/Margin/VBox/SettingsButton
@onready var quit_button: Button = $MenuPanel/Margin/VBox/QuitButton

func _ready() -> void:
	menu_panel.modulate.a = 0.0
	menu_panel.position.x += 24.0
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.grab_focus()
	var reveal := create_tween().set_parallel(true)
	reveal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(menu_panel, "modulate:a", 1.0, 0.28)
	reveal.tween_property(menu_panel, "position:x", menu_panel.position.x - 24.0, 0.34)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ConsentScreen.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SettingsMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
