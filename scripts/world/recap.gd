extends Control
## Week-2 opener: reviews the words from the participant's linked Week-1
## session before the harder extension content.
##
## Every prior word gets a single "standard" card. Words the participant
## MISSED in Week 1 were randomly split into two arms by StudySession
## (assign_recap_arms): the "emphasized" arm additionally gets two spaced
## retrieval rounds (pick the English for the Spanish word) with a
## scaffolded hint ladder; the "standard" arm gets only the card. The
## random split is what lets Week 2 say whether targeting errors helps.
##
## Everything is logged per word with its arm so exposure can be analyzed:
## recap_word_shown (cards) and recap_retrieval (practice) events.

const RIGHT_COLOR := Color(0.45, 0.8, 0.5)
const HINT_COLOR := Color(0.95, 0.8, 0.45)
const ROLE_TYPES := {
	"noun": "noun (a thing)", "verb": "verb (an action)", "pronoun": "pronoun",
	"phrase": "phrase", "attack": "attack word", "heal": "healing word",
	"shield": "shield word", "blade": "blade word", "trap": "trap word",
}

@onready var progress_label: Label = $VBox/ProgressLabel
@onready var word_label: Label = $VBox/WordLabel
@onready var definition_label: Label = $VBox/DefinitionLabel
@onready var example_label: Label = $VBox/ExampleLabel
@onready var next_button: Button = $VBox/NextButton

var _items: Array = []
var _index := 0
var _misses := 0
var _solved := false
var _started_msec := 0
var _choice_box: VBoxContainer
var _feedback: Label
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	next_button.pressed.connect(_on_next)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 8)
	$VBox.add_child(_choice_box)
	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_font_size_override("font_size", 16)
	$VBox.add_child(_feedback)

	_items = build_items(StudySession.prior_word_ids, StudySession.recap_arm, _rng)
	if _items.is_empty():
		StudySession.log_event("recap_skipped_no_prior_words")
		_go_to_extension.call_deferred()
		return
	_show_item()

## Pure: the sequence of recap screens. Cards for every word (shuffled),
## then two retrieval rounds over the emphasized words only.
static func build_items(word_ids: Array, arms: Dictionary, rng: RandomNumberGenerator) -> Array:
	var ids: Array = word_ids.duplicate()
	_shuffle(ids, rng)
	var items: Array = []
	for id in ids:
		items.append({"kind": "card", "word_id": id})
	var emphasized: Array = ids.filter(func(id): return arms.get(id, "") == "emphasized")
	var last := ""
	for round_number in [1, 2]:
		_shuffle(emphasized, rng)
		if emphasized.size() > 1 and emphasized[0] == last:
			var tmp = emphasized[0]
			emphasized[0] = emphasized[-1]
			emphasized[-1] = tmp
		for id in emphasized:
			items.append({"kind": "retrieve", "word_id": id, "round": round_number})
		if not emphasized.is_empty():
			last = emphasized[-1]
	return items

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp

func _show_item() -> void:
	var item: Dictionary = _items[_index]
	var word: Dictionary = WordBank.get_word(item.word_id)
	progress_label.text = "%d / %d" % [_index + 1, _items.size()]
	_started_msec = Time.get_ticks_msec()
	_misses = 0
	_solved = false
	_clear_choices()
	_feedback.text = ""
	PlayerProfile.record_seen(item.word_id)
	word_label.text = word.spanish
	if item.kind == "card":
		definition_label.text = word.english
		definition_label.visible = true
		example_label.text = "%s\n%s" % [word.example_es, word.example_en]
		example_label.visible = true
		next_button.visible = true
		next_button.text = "Next"
		StudySession.log_event("recap_word_shown", {
			"word_id": item.word_id, "arm": StudySession.recap_arm.get(item.word_id, "none"),
		})
		return
	# Retrieval: pick the English meaning.
	progress_label.text = "Practice round %d   -   %d / %d" % [item.round, _index + 1, _items.size()]
	definition_label.visible = false
	example_label.visible = false
	next_button.visible = false
	for option in _options_for(item.word_id):
		var b := Button.new()
		b.text = option
		b.custom_minimum_size = Vector2(0, 46)
		b.pressed.connect(_on_option_pressed.bind(b, item))
		_choice_box.add_child(b)

func _options_for(word_id: String) -> Array:
	var word: Dictionary = WordBank.get_word(word_id)
	var others: Array = WordBank.all_word_ids().filter(func(id): return id != word_id)
	_shuffle(others, _rng)
	# Same-role words are the most tempting distractors, so prefer them.
	var same: Array = others.filter(func(id): return WordBank.get_word(id).role == word.role)
	var rest: Array = others.filter(func(id): return WordBank.get_word(id).role != word.role)
	var options: Array = [word.english]
	for id in same + rest:
		var english: String = WordBank.get_word(id).english
		if options.size() >= 4:
			break
		if not options.has(english):
			options.append(english)
	_shuffle(options, _rng)
	return options

func _on_option_pressed(button: Button, item: Dictionary) -> void:
	if _solved:
		return
	var word: Dictionary = WordBank.get_word(item.word_id)
	if button.text == word.english:
		_solved = true
		var first_try := _misses == 0
		if first_try:
			PlayerProfile.record_correct(item.word_id, false)
			Praise.correct()
		for b in _choice_box.get_children():
			b.disabled = true
		button.add_theme_color_override("font_disabled_color", RIGHT_COLOR)
		_feedback.add_theme_color_override("font_color", RIGHT_COLOR)
		_feedback.text = ("Correct!  %s = %s" if first_try else "You worked it out!  %s = %s") % [word.spanish, word.english]
		StudySession.log_event("recap_retrieval", {
			"word_id": item.word_id, "arm": "emphasized", "round": item.round,
			"misses": _misses, "first_try": first_try,
			"latency_ms": Time.get_ticks_msec() - _started_msec,
		})
		next_button.text = "Next"
		next_button.visible = true
		return
	# Wrong: scaffolded ladder (role cue, then the word in a sentence).
	_misses += 1
	button.disabled = true
	PlayerProfile.record_error(item.word_id, word.spanish)
	Praise.wrong()
	var cue: String
	var rung: String
	if _misses == 1:
		cue = "It's a %s." % ROLE_TYPES.get(word.role, "word")
		rung = "role"
	else:
		cue = "See it in use:  %s" % _blank_example(word)
		rung = "example"
	StudySession.log_event("recap_hint", {"word_id": item.word_id, "rung": rung})
	_feedback.add_theme_color_override("font_color", HINT_COLOR)
	_feedback.text = "Not quite. " + cue

## The Spanish example sentence with the word blanked out when it appears.
func _blank_example(word: Dictionary) -> String:
	var sentence: String = word.example_es
	var stem: String = word.spanish.left(maxi(3, word.spanish.length() - 2))
	var idx := sentence.to_lower().find(stem.to_lower())
	if idx == -1:
		return sentence
	var end := idx
	while end < sentence.length() and sentence[end] != " " and not sentence[end] in [".", ",", "!", "?"]:
		end += 1
	return sentence.substr(0, idx) + "_____" + sentence.substr(end)

func _clear_choices() -> void:
	for child in _choice_box.get_children():
		_choice_box.remove_child(child)
		child.queue_free()

func _on_next() -> void:
	_index += 1
	if _index >= _items.size():
		_go_to_extension()
	else:
		_show_item()

func _go_to_extension() -> void:
	get_tree().change_scene_to_file("res://scenes/world/ExtensionContent.tscn")
