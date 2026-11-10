extends Control
## One participant code links all gameplay in the same session.

@onready var code_label: Label = $VBox/CodeLabel
@onready var code_edit: LineEdit = $VBox/CodeEdit
@onready var adult_label: Label = $VBox/AdultLabel
@onready var adult_choice: OptionButton = $VBox/AdultChoice
@onready var warning_label: Label = $VBox/WarningLabel
@onready var continue_button: Button = $VBox/ContinueButton

var _suggested_code := ""

func _ready() -> void:
	_suggested_code = StudySession.generate_participant_code()
	$VBox/Title.text = "Participant code"
	$VBox/ModeRow.hide()
	adult_label.hide()
	adult_choice.hide()
	code_edit.text = _suggested_code
	code_label.text = "Your participant code for this study:"
	continue_button.pressed.connect(_on_continue)
	warning_label.visible = false

func _on_continue() -> void:
	var code := code_edit.text.strip_edges().to_upper()
	if code == "":
		warning_label.text = "Please enter a participant code."
		warning_label.visible = true
		return

	StudySession.pending_participant_code = code
	get_tree().change_scene_to_file("res://scenes/ui/PreSurvey.tscn")
