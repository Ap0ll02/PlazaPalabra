extends Control
## Objective learning check: quizzes only words the player actually
## encountered this session (via PlayerProfile), multiple-choice against
## distractors from the rest of the word bank. Skips gracefully if too
## few words were seen (e.g. while quests/tutorial don't exist yet).

const MIN_WORDS_FOR_QUIZ := 3
const QUIZ_LENGTH := 8
const NEXT_SCENE := "res://scenes/ui/ThankYou.tscn"

@onready var question_label: Label = $VBox/QuestionLabel
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var choice_buttons: Array[Button] = [
	$VBox/Choices/Choice0, $VBox/Choices/Choice1,
	$VBox/Choices/Choice2, $VBox/Choices/Choice3,
]

var _quiz_words: Array = []
var _current_index := 0
var _correct_count := 0
var _current_options: Array = []
var _current_correct: String = ""
var _results: Array = []

func _ready() -> void:
	for i in choice_buttons.size():
		choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))

	var seen: Array = WordBank.all_word_ids().filter(func(id): return PlayerProfile.has_seen(id))
	seen.shuffle()
	_quiz_words = seen.slice(0, min(seen.size(), QUIZ_LENGTH))

	if _quiz_words.size() < MIN_WORDS_FOR_QUIZ:
		StudySession.log_event("recall_quiz_skipped", {"seen_count": seen.size()})
		_finish.call_deferred()
		return

	_show_question()

func _show_question() -> void:
	var word_id: String = _quiz_words[_current_index]
	var word: Dictionary = WordBank.get_word(word_id)
	question_label.text = "What does \"%s\" mean in English?" % word.spanish
	progress_label.text = "%d / %d" % [_current_index + 1, _quiz_words.size()]
	_current_correct = word.english

	var options: Array = [word.english]
	var distractor_pool: Array = WordBank.all_word_ids().filter(func(id): return id != word_id)
	distractor_pool.shuffle()
	for i in min(3, distractor_pool.size()):
		options.append(WordBank.get_word(distractor_pool[i]).english)
	options.shuffle()
	_current_options = options

	for i in choice_buttons.size():
		if i < options.size():
			choice_buttons[i].visible = true
			choice_buttons[i].text = options[i]
		else:
			choice_buttons[i].visible = false

func _on_choice_pressed(index: int) -> void:
	var chosen: String = _current_options[index]
	var is_correct: bool = chosen == _current_correct
	if is_correct:
		_correct_count += 1

	var word_id: String = _quiz_words[_current_index]
	var is_review: bool = word_id in StudySession.prior_word_ids
	_results.append({"word_id": word_id, "chosen": chosen, "correct": is_correct, "is_review": is_review})
	StudySession.log_event("recall_quiz_answer", {"word_id": word_id, "correct": is_correct, "is_review": is_review})

	_current_index += 1
	if _current_index >= _quiz_words.size():
		_finish()
	else:
		_show_question()

func _finish() -> void:
	StudySession.save_json("recall_quiz.json", {
		"total": _quiz_words.size(),
		"correct": _correct_count,
		"results": _results,
	})
	get_tree().change_scene_to_file(NEXT_SCENE)
