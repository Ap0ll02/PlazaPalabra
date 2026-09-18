extends "res://scripts/ui/post_survey.gd"
## Week-2 survey: same SUS + custom items as the Week-1 post-survey, plus
## one item specific to the recap's effectiveness.

const RECAP_ITEM := {
	"id": "recap_helpful", "type": "likert5",
	"prompt": "The recap at the start of today's session helped me remember what I'd learned before.",
}

func _get_config() -> Dictionary:
	var base_config := super._get_config()
	var combined: Array = base_config.questions.duplicate()
	combined.append(RECAP_ITEM)
	return {
		"title": "A Few Questions About Today's Session",
		"questions": combined,
		"filename": "survey_post_visit%d.json" % StudySession.visit_number,
		"next_scene": "res://scenes/ui/RecallQuiz.tscn",
	}
