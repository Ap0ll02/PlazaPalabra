extends Control
## First-time participants get an auto-generated code to write down and
## bring back; returning participants type that code back in so their
## Week-2 session links to Week-1's data. No blocking validation if the
## code doesn't match anything -- Recap.tscn just shows nothing to recap
## and the mismatch is visible to the researcher in the event log.

@onready var first_time_button: Button = $VBox/ModeRow/FirstTimeButton
@onready var return_button: Button = $VBox/ModeRow/ReturnButton
@onready var code_label: Label = $VBox/CodeLabel
@onready var code_edit: LineEdit = $VBox/CodeEdit
@onready var adult_label: Label = $VBox/AdultLabel
@onready var adult_choice: OptionButton = $VBox/AdultChoice
@onready var warning_label: Label = $VBox/WarningLabel
@onready var continue_button: Button = $VBox/ContinueButton

var _is_first_time := true
var _suggested_code := ""

func _ready() -> void:
	_suggested_code = StudySession.generate_participant_code()
	first_time_button.pressed.connect(func(): _set_mode(true))
	return_button.pressed.connect(func(): _set_mode(false))
	continue_button.pressed.connect(_on_continue)
	adult_choice.add_item("Choose one...")
	adult_choice.add_item("Yes")
	adult_choice.add_item("No")
	adult_choice.item_selected.connect(_on_adult_selected)
	warning_label.visible = false
	_set_mode(true)

func _set_mode(is_first: bool) -> void:
	_is_first_time = is_first
	first_time_button.button_pressed = is_first
	return_button.button_pressed = not is_first
	adult_label.visible = not is_first
	adult_choice.visible = not is_first
	adult_choice.select(0)
	warning_label.visible = false
	if is_first:
		code_edit.text = _suggested_code
		code_label.text = "Your participant code -- write this down, you'll need it for the follow-up session in about a week:"
	else:
		code_edit.text = ""
		code_label.text = "Enter your participant code from your first session:"

func _on_adult_selected(index: int) -> void:
	if index == 2:
		StudySession.reset_for_new_session()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_continue() -> void:
	if not _is_first_time and adult_choice.selected != 1:
		warning_label.text = "Please confirm that you are 18 or older."
		warning_label.visible = true
		return
	var code := code_edit.text.strip_edges().to_upper()
	if code == "":
		warning_label.text = "Please enter a participant code."
		warning_label.visible = true
		return

	if _is_first_time:
		StudySession.pending_first_visit_code = code
		get_tree().change_scene_to_file("res://scenes/ui/PreSurvey.tscn")
	else:
		StudySession.configure(code, 2)
		get_tree().change_scene_to_file("res://scenes/world/Recap.tscn")
