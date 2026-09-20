extends Node2D
## Quest 2: explore the ruins, pick up scrolls that teach the words the
## boss fight leans on, then confront Sombra. Sombra won't engage until
## enough scrolls are collected (see npcs/sombra_npc.gd).

@onready var progress_label: Label = $CanvasLayer/ProgressLabel
@onready var toast_label: Label = $CanvasLayer/ToastLabel
@onready var sombra: Node = $Sombra

var _toast_tween: Tween
var _pending_scene := ""

func _ready() -> void:
	GameState.set_quest_stage("quest_2")
	toast_label.modulate.a = 0.0
	_update_progress_label()
	for item in get_tree().get_nodes_in_group("scavenge_items"):
		item.collected.connect(_on_scroll_collected)
	Dialogue.action_triggered.connect(_on_dialogue_action)
	Dialogue.dialogue_ended.connect(_on_dialogue_ended)

func _on_scroll_collected(word_id: String) -> void:
	var count := int(GameState.flags.get("ruins_scrolls", 0)) + 1
	GameState.set_flag("ruins_scrolls", count)
	_update_progress_label()
	var word: Dictionary = WordBank.get_word(word_id)
	_show_toast("Learned: %s (%s)" % [word.spanish, word.english])

func _update_progress_label() -> void:
	var count := int(GameState.flags.get("ruins_scrolls", 0))
	progress_label.text = "Scrolls found: %d / %d" % [count, sombra.SCROLLS_REQUIRED]

func _on_dialogue_action(action: String) -> void:
	if action == "start_boss_fight":
		# Wait for the dialogue to close before leaving, otherwise the box
		# stays open over the next scene.
		_pending_scene = "res://scenes/world/Combat.tscn"

func _on_dialogue_ended() -> void:
	if _pending_scene != "":
		get_tree().change_scene_to_file(_pending_scene)

func _show_toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
