extends "res://scripts/ui/survey_base.gd"
## Standard SUS (System Usability Scale) items + the custom items drafted
## in the design doc (perceived learning, hint helpfulness, combat
## clarity, error tolerance, cognitive load, engagement, open-ended).

const QUESTIONS := [
	{"id": "sus_1", "type": "likert5", "prompt": "I think that I would like to use this system frequently."},
	{"id": "sus_2", "type": "likert5", "prompt": "I found the system unnecessarily complex."},
	{"id": "sus_3", "type": "likert5", "prompt": "I thought the system was easy to use."},
	{"id": "sus_4", "type": "likert5", "prompt": "I think that I would need the support of a technical person to be able to use this system."},
	{"id": "sus_5", "type": "likert5", "prompt": "I found the various functions in this system were well integrated."},
	{"id": "sus_6", "type": "likert5", "prompt": "I thought there was too much inconsistency in this system."},
	{"id": "sus_7", "type": "likert5", "prompt": "I would imagine that most people would learn to use this system very quickly."},
	{"id": "sus_8", "type": "likert5", "prompt": "I found the system very cumbersome to use."},
	{"id": "sus_9", "type": "likert5", "prompt": "I felt very confident using the system."},
	{"id": "sus_10", "type": "likert5", "prompt": "I needed to learn a lot of things before I could get going with this system."},
	{"id": "perceived_learning", "type": "likert5", "prompt": "I feel more confident recognizing basic Spanish words after playing."},
	{"id": "hint_helpfulness", "type": "likert5", "prompt": "The hints helped me learn, rather than just letting me skip the word."},
	{"id": "combat_clarity", "type": "likert5", "prompt": "I understood what each part of the sentence (subject, verb, object) was doing in combat."},
	{"id": "error_tolerance", "type": "likert5", "prompt": "I felt comfortable guessing even when I wasn't sure of a word."},
	{"id": "cognitive_load", "type": "likert5", "prompt": "Building sentences in combat felt mentally demanding (1 = not at all, 5 = extremely)."},
	{"id": "engagement", "type": "likert5", "prompt": "I would want to keep playing if there were more of the game."},
	{"id": "open_confusing", "type": "text", "prompt": "What was confusing, if anything?"},
	{"id": "open_enjoyed", "type": "text", "prompt": "What did you enjoy most?"},
]

func _get_config() -> Dictionary:
	return {
		"title": "A Few Questions About Your Experience",
		"questions": QUESTIONS,
		"filename": "survey_post.json",
		"next_scene": "res://scenes/ui/RecallQuiz.tscn",
	}
