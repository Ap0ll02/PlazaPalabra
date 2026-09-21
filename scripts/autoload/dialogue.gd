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
##       "portrait": String,       # optional portrait id (e.g. "mira_worried"),
##                                 # falls back to the default portrait passed
##                                 # to start(). Loads
##                                 # res://assets/portraits/<id>.png; if the
##                                 # file doesn't exist yet, a labeled
##                                 # placeholder shows instead.
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

const PORTRAIT_DIR := "res://assets/portraits/"
const TEXT_LEFT_WITH_PORTRAIT := 190.0
const TEXT_LEFT_NO_PORTRAIT := 20.0

var is_open: bool = false
## Frame the last dialogue closed on. Interactables ignore input on that
## frame so the Enter press that closed a dialogue can't reopen it.
var closed_frame: int = -1

@onready var panel: Panel = $Panel
@onready var vbox: VBoxContainer = $Panel/VBox
@onready var speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var text_label: Label = $Panel/VBox/TextLabel
@onready var choices_container: VBoxContainer = $Panel/VBox/ChoicesContainer
@onready var continue_button: Button = $Panel/VBox/ContinueButton
@onready var portrait_frame: Control = $Panel/PortraitFrame
@onready var portrait_texture: TextureRect = $Panel/PortraitFrame/Portrait
@onready var portrait_placeholder: ColorRect = $Panel/PortraitFrame/Placeholder
@onready var portrait_placeholder_label: Label = $Panel/PortraitFrame/Placeholder/Label

var _dialogue: Dictionary = {}
var _default_speaker: String = ""
var _default_portrait: String = ""
const Fx := preload("res://scripts/ui/fx.gd")

var _pending_next: String = ""

func _ready() -> void:
	panel.visible = false
	continue_button.pressed.connect(_on_continue_pressed)

func _process(_delta: float) -> void:
	if is_open and continue_button.visible and Input.is_action_just_pressed("ui_accept"):
		_on_continue_pressed()

## Starts a full dialogue tree at `start_node`. `default_speaker` and
## `default_portrait` are used for any node that doesn't set its own.
func start(dialogue_data: Dictionary, start_node: String = "start", default_speaker: String = "", default_portrait: String = "") -> void:
	_dialogue = dialogue_data
	_default_speaker = default_speaker
	_default_portrait = default_portrait
	is_open = true
	Fx.fade_in(panel)
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
	Fx.fade_text(text_label, node.get("text", ""))
	_set_portrait(node.get("portrait", _default_portrait))

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

func _set_portrait(portrait_id: String) -> void:
	if portrait_id == "":
		portrait_frame.visible = false
		vbox.offset_left = TEXT_LEFT_NO_PORTRAIT
		return

	portrait_frame.visible = true
	vbox.offset_left = TEXT_LEFT_WITH_PORTRAIT

	var path := PORTRAIT_DIR + portrait_id + ".png"
	if ResourceLoader.exists(path):
		portrait_texture.texture = load(path)
		portrait_texture.visible = true
		portrait_placeholder.visible = false
	else:
		# Stable per-id color so placeholder poses are distinguishable.
		var hue := float(portrait_id.hash() % 360) / 360.0
		portrait_placeholder.color = Color.from_hsv(hue, 0.35, 0.55)
		portrait_placeholder_label.text = portrait_id.replace("_", "\n")
		portrait_texture.visible = false
		portrait_placeholder.visible = true

func _on_continue_pressed() -> void:
	_show_node(_pending_next)

func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()

func _end_dialogue() -> void:
	is_open = false
	closed_frame = Engine.get_process_frames()
	Fx.fade_out(panel)
	_dialogue = {}
	dialogue_ended.emit()
