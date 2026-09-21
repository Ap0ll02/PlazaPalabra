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

## Week 2 tests the emphasized and standard recap words equally (so the
## arms can be compared fairly), plus the same number of never-missed words
## as a reference group. Falls back to the random pick if either arm is empty.
const MAX_PER_GROUP := 6

var _balanced := false
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
	_balanced = false
	if StudySession.visit_number > 1:
		var balanced := balanced_words(StudySession.recap_arm, StudySession.recap_never_missed, MAX_PER_GROUP)
		if not balanced.is_empty():
			_quiz_words = balanced
			_balanced = true

	if _quiz_words.size() < MIN_WORDS_FOR_QUIZ:
		StudySession.log_event("recall_quiz_skipped", {"seen_count": seen.size()})
		_finish.call_deferred()
		return

	_show_question()

## Pure: equal numbers from each recap arm, and up to that many never-missed
## words, shuffled together. [] when an arm is empty.
static func balanced_words(arms: Dictionary, never_missed: Array, max_per_group: int) -> Array:
	var emphasized: Array = arms.keys().filter(func(id): return arms[id] == "emphasized")
	var standard: Array = arms.keys().filter(func(id): return arms[id] == "standard")
	var k := mini(mini(emphasized.size(), standard.size()), max_per_group)
	if k == 0:
		return []
	emphasized.shuffle()
	standard.shuffle()
	var control: Array = never_missed.duplicate()
	control.shuffle()
	var words: Array = emphasized.slice(0, k) + standard.slice(0, k) + control.slice(0, mini(k, control.size()))
	words.shuffle()
	return words

## Which analysis group a quizzed word belongs to.
func _group_for(word_id: String) -> String:
	if StudySession.visit_number > 1:
		if StudySession.recap_arm.has(word_id):
			return StudySession.recap_arm[word_id]
		return "never_missed" if word_id in StudySession.recap_never_missed else "new_this_week"
	return "missed_w1" if PlayerProfile.get_stats(word_id).errors >= 1 else "clean_w1"

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
	var group := _group_for(word_id)
	var w1_errors: int = int(StudySession.prior_word_stats.get(word_id, {}).get("errors", 0))
	_results.append({
		"word_id": word_id, "chosen": chosen, "correct": is_correct, "is_review": is_review,
		"group": group, "week1_errors": w1_errors,
	})
	StudySession.log_event("recall_quiz_answer", {
		"word_id": word_id, "correct": is_correct, "is_review": is_review, "group": group,
	})

	_current_index += 1
	if _current_index >= _quiz_words.size():
		_finish()
	else:
		_show_question()

func _finish() -> void:
	var rows: Array = []
	for r in _results:
		rows.append([r.word_id, r.group, r.week1_errors, r.chosen, r.correct, r.is_review])
	StudySession.save_table("recall_quiz.csv",
		["word_id", "group", "week1_errors", "chosen", "correct", "is_review"], rows)
	StudySession.save_json("recall_quiz.json", {
		"balanced_by_recap_arm": _balanced,
		"total": _quiz_words.size(),
		"correct": _correct_count,
		"results": _results,
	})
	get_tree().change_scene_to_file(NEXT_SCENE)
