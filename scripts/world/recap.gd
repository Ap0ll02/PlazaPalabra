extends Control
## Week-2 opener: reviews the words from the participant's linked Week-1
## session (StudySession.prior_word_ids) one at a time before moving into
## the harder extension content. This is the "recap" half of the recap +
## light-extension design -- a controlled re-exposure, not a test.

@onready var progress_label: Label = $VBox/ProgressLabel
@onready var word_label: Label = $VBox/WordLabel
@onready var definition_label: Label = $VBox/DefinitionLabel
@onready var example_label: Label = $VBox/ExampleLabel
@onready var next_button: Button = $VBox/NextButton

var _words: Array = []
var _index := 0

func _ready() -> void:
	next_button.pressed.connect(_on_next)
	_words = StudySession.prior_word_ids.duplicate()
	if _words.is_empty():
		StudySession.log_event("recap_skipped_no_prior_words")
		_go_to_extension.call_deferred()
		return
	_show_word()

func _show_word() -> void:
	var word_id: String = _words[_index]
	var word: Dictionary = WordBank.get_word(word_id)
	progress_label.text = "%d / %d" % [_index + 1, _words.size()]
	word_label.text = word.spanish
	definition_label.text = word.english
	example_label.text = "%s\n%s" % [word.example_es, word.example_en]
	PlayerProfile.record_seen(word_id)
	StudySession.log_event("recap_word_shown", {"word_id": word_id})

func _on_next() -> void:
	_index += 1
	if _index >= _words.size():
		_go_to_extension()
	else:
		_show_word()

func _go_to_extension() -> void:
	get_tree().change_scene_to_file("res://scenes/world/ExtensionContent.tscn")
