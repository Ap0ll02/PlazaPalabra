extends CanvasLayer
## Generic, data-driven dialogue box. Any NPC/interactable just hands it a
## dialogue dict + a starting node id -- no scene/UI changes needed to
## add or edit dialogue content, only the data.
##
## Dialogue dict shape (see scripts/world/npcs/*.gd for real examples):
##   {
##     "node_id": {
##       "speaker": String,        # optional, falls back to the default
##                                 # speaker passed to start()
##       "text": String,
##       "on_enter": String,       # optional action name, broadcast via
##                                 # action_triggered when this node shows
##       "next": String,           # node id to advance to ("end" or "" closes)
##       "choices": [              # optional; if present, "next" is ignored
##         {"text": String, "next": String},
##         ...
##       ],
##     },
##     ...
##   }

signal action_triggered(action: String)
signal dialogue_ended

var is_open: bool = false

@onready var panel: Panel = $Panel
@onready var speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var text_label: Label = $Panel/VBox/TextLabel
@onready var choices_container: VBoxContainer = $Panel/VBox/ChoicesContainer
@onready var continue_button: Button = $Panel/VBox/ContinueButton

var _dialogue: Dictionary = {}
var _default_speaker: String = ""
var _pending_next: String = ""

func _ready() -> void:
	panel.visible = false
	continue_button.pressed.connect(_on_continue_pressed)

func _process(_delta: float) -> void:
	if is_open and continue_button.visible and Input.is_action_just_pressed("ui_accept"):
		_on_continue_pressed()

## Starts a full dialogue tree at `start_node`. `default_speaker` is used
## for any node that doesn't set its own "speaker".
func start(dialogue_data: Dictionary, start_node: String = "start", default_speaker: String = "") -> void:
	_dialogue = dialogue_data
	_default_speaker = default_speaker
	is_open = true
	panel.visible = true
	_show_node(start_node)

## Convenience for a single throwaway line (item flavor text, etc.) --
## still goes through the same box so all narrative text looks consistent.
func show_message(text: String, speaker: String = "") -> void:
	start({"start": {"text": text, "next": "end"}}, "start", speaker)

func _show_node(node_id: String) -> void:
	if node_id == "" or node_id == "end" or not _dialogue.has(node_id):
		_end_dialogue()
		return

	var node: Dictionary = _dialogue[node_id]
	speaker_label.text = node.get("speaker", _default_speaker)
	speaker_label.visible = speaker_label.text != ""
	text_label.text = node.get("text", "")

	if node.has("on_enter"):
		action_triggered.emit(node.on_enter)

	_clear_choices()
	var choices: Array = node.get("choices", [])
	if choices.size() > 0:
		continue_button.visible = false
		choices_container.visible = true
		for choice in choices:
			var b := Button.new()
			b.text = choice.text
			b.pressed.connect(_show_node.bind(choice.get("next", "end")))
			choices_container.add_child(b)
	else:
		choices_container.visible = false
		continue_button.visible = true
		_pending_next = node.get("next", "end")

func _on_continue_pressed() -> void:
	_show_node(_pending_next)

func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()

func _end_dialogue() -> void:
	is_open = false
	panel.visible = false
	_dialogue = {}
	dialogue_ended.emit()
