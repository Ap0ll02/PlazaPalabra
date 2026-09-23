extends "res://scripts/ui/survey_base.gd"
## Baseline questions -- prior language/gaming experience, for
## contextualizing individual differences in the post-session results.

const QUESTIONS := [
	{"id": "age_range", "type": "choice", "prompt": "What is your age range?",
		"choices": ["Under 18", "18-24", "25-34", "35-44", "45+"]},
	{"id": "prior_spanish", "type": "choice", "prompt": "How would you describe your prior experience with Spanish?",
		"choices": ["None", "A little (a few words/phrases)", "Some (took a class, can hold a basic conversation)", "Fluent or native speaker"]},
	{"id": "gaming_experience", "type": "choice", "prompt": "How often do you play video games?",
		"choices": ["Rarely or never", "A few times a month", "A few times a week", "Daily"]},
	{"id": "language_app_experience", "type": "choice", "prompt": "Have you used a language-learning app before (e.g. Duolingo)?",
		"choices": ["Never", "Tried it briefly", "Used it regularly for a while", "Use one regularly now"]},
]

func _get_config() -> Dictionary:
	return {
		"title": "Before You Begin",
		"questions": QUESTIONS,
		"filename": "survey_pre.json",
		"next_scene": "res://scenes/world/Intro.tscn",
	}

@onready var dev_skip_button: Button = $DevSkipButton

func _ready() -> void:
	super._ready()
	var age_choice: OptionButton = _answer_controls["age_range"].control
	age_choice.item_selected.connect(_on_age_selected)
	dev_skip_button.visible = OS.is_debug_build()   # hidden in study (release) builds
	dev_skip_button.pressed.connect(_on_dev_skip_pressed)

func _on_age_selected(index: int) -> void:
	var age_choice: OptionButton = _answer_controls["age_range"].control
	if age_choice.get_item_text(index) == "Under 18":
		StudySession.reset_for_new_session()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_submit_pressed() -> void:
	if _unanswered_count() > 0:
		super._on_submit_pressed()
		return
	if StudySession.pending_first_visit_code != "":
		StudySession.configure(StudySession.pending_first_visit_code, 1)
	super._on_submit_pressed()

func _on_dev_skip_pressed() -> void:
	if StudySession.pending_first_visit_code != "":
		StudySession.configure(StudySession.pending_first_visit_code, 1)
	StudySession.log_event("survey_dev_skipped", {"file": _get_config().filename})
	get_tree().change_scene_to_file(_get_config().next_scene)
