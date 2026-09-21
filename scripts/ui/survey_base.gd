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
var _warning: Label

const PLACEHOLDER := "Choose one..."

func _get_config() -> Dictionary:
	return {"title": "Survey", "questions": [], "filename": "survey.json", "next_scene": ""}

func _ready() -> void:
	_config = _get_config()
	title_label.text = _config.title
	_build_ui(_config.questions)
	submit_button.pressed.connect(_on_submit_pressed)
	_warning = Label.new()
	_warning.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4))
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	submit_button.get_parent().add_child(_warning)
	submit_button.get_parent().move_child(_warning, submit_button.get_index())

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
				# A placeholder first entry, so an untouched dropdown can't be
				# mistaken for a real answer.
				opt.add_item(PLACEHOLDER)
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

## Number of rating/choice questions still unanswered (text answers are optional).
func _unanswered_count() -> int:
	var count := 0
	for id in _answer_controls:
		var info: Dictionary = _answer_controls[id]
		match info.type:
			"likert5":
				if not info.buttons.any(func(b): return b.button_pressed):
					count += 1
			"choice":
				if info.control.selected <= 0:
					count += 1
	return count

func _on_submit_pressed() -> void:
	var missing := _unanswered_count()
	if missing > 0:
		_warning.text = "Please answer every question (%d left)." % missing
		return
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
				results[id] = opt.get_item_text(opt.selected) if opt.selected > 0 else ""
			"text":
				results[id] = info.control.text

	StudySession.save_json(_config.filename, results)
	var rows: Array = []
	for q in _config.questions:
		rows.append([q.id, q.type, q.prompt, results.get(q.id, "")])
	StudySession.save_table(_config.filename.get_basename() + ".csv", ["question_id", "type", "prompt", "answer"], rows)
	StudySession.log_event("survey_submitted", {"file": _config.filename})
	if _config.next_scene != "":
		get_tree().change_scene_to_file(_config.next_scene)
