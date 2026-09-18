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
	dev_skip_button.pressed.connect(_on_dev_skip_pressed)

func _on_dev_skip_pressed() -> void:
	StudySession.log_event("survey_dev_skipped", {"file": _get_config().filename})
	get_tree().change_scene_to_file(_get_config().next_scene)
