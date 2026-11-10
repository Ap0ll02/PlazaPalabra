extends "res://scripts/ui/post_survey.gd"
## Final survey after the second gameplay portion.

func _get_config() -> Dictionary:
	var base_config := super._get_config()
	return {
		"title": "After the Second Portion",
		"questions": base_config.questions,
		"filename": "survey_post_final.json",
		"next_scene": "res://scenes/ui/RecallQuiz.tscn",
	}
