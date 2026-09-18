extends Control
## Shared base for data-driven survey scenes. A subclass overrides
## _get_config() to supply its title, question list, output filename,
## and where to go next -- the UI is built procedurally from that data
## so adding/editing survey items never touches scene files.
##
## Question dict shape:
##   {"id": String, "type": "likert5"|"choice"|"text", "prompt": String,
##    "choices": Array[String]}  # "choices" only for type "choice"

@onready var title_label: Label = $VBox/Title
@onready var question_list: VBoxContainer = $VBox/Scroll/QuestionList
@onready var submit_button: Button = $VBox/SubmitButton

var _config: Dictionary
var _answer_controls: Dictionary = {}

func _get_config() -> Dictionary:
	return {"title": "Survey", "questions": [], "filename": "survey.json", "next_scene": ""}

func _ready() -> void:
	_config = _get_config()
	title_label.text = _config.title
	_build_ui(_config.questions)
	submit_button.pressed.connect(_on_submit_pressed)

func _build_ui(questions: Array) -> void:
	for q in questions:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var prompt := Label.new()
		prompt.text = q.prompt
		prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(prompt)

		match q.type:
			"likert5":
				var hbox := HBoxContainer.new()
				hbox.add_theme_constant_override("separation", 8)
				var group := ButtonGroup.new()
				var buttons: Array[Button] = []
				var anchors := ["1 (strongly disagree)", "2", "3", "4", "5 (strongly agree)"]
				for i in range(5):
					var b := Button.new()
					b.text = str(i + 1)
					b.tooltip_text = anchors[i]
					b.toggle_mode = true
					b.button_group = group
					b.custom_minimum_size = Vector2(44, 40)
					hbox.add_child(b)
					buttons.append(b)
				row.add_child(hbox)
				_answer_controls[q.id] = {"type": "likert5", "buttons": buttons}
			"choice":
				var opt := OptionButton.new()
				for c in q.choices:
					opt.add_item(c)
				row.add_child(opt)
				_answer_controls[q.id] = {"type": "choice", "control": opt}
			"text":
				var edit := LineEdit.new()
				edit.custom_minimum_size = Vector2(420, 0)
				row.add_child(edit)
				_answer_controls[q.id] = {"type": "text", "control": edit}

		question_list.add_child(row)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 16)
		question_list.add_child(spacer)

func _on_submit_pressed() -> void:
	var results := {}
	for id in _answer_controls.keys():
		var info: Dictionary = _answer_controls[id]
		match info.type:
			"likert5":
				var value := 0
				for i in info.buttons.size():
					if info.buttons[i].button_pressed:
						value = i + 1
				results[id] = value
			"choice":
				var opt: OptionButton = info.control
				results[id] = opt.get_item_text(opt.selected) if opt.selected >= 0 else ""
			"text":
				results[id] = info.control.text

	StudySession.save_json(_config.filename, results)
	StudySession.log_event("survey_submitted", {"file": _config.filename})
	if _config.next_scene != "":
		get_tree().change_scene_to_file(_config.next_scene)
