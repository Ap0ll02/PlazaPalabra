extends Node2D
## Tutorial: movement + scavenging first nouns, gated entrance into town.

const MIN_ITEMS_TO_PROCEED := 3

## The ambush that follows learning the first spell. Ends in the tutorial fight.
const BANDIT_DIALOGUE := {
	"start": {
		"speaker": "Bandit", "portrait": "bandit",
		"text": "Hey, you! That scroll is mine now. Hand it over!",
		"next": "fight",
	},
	"fight": {
		"speaker": "Bandit", "portrait": "bandit",
		"text": "No? Then I'll take it the hard way!",
		"on_enter": "start_bandit_fight",
		"next": "end",
	},
}

@onready var progress_label: Label = $CanvasLayer/ProgressLabel
@onready var toast_label: Label = $CanvasLayer/ToastLabel
@onready var town_entrance: Area2D = $TownEntrance
@onready var bandit: Node2D = $Bandit

var _items_collected := 0
var _toast_tween: Tween
var _pending_fight := false

func _ready() -> void:
	add_to_group("gameplay_scene")
	GameState.set_quest_stage("tutorial")
	toast_label.modulate.a = 0.0
	_update_progress_label()
	for item in get_tree().get_nodes_in_group("scavenge_items"):
		item.collected.connect(_on_item_collected)
	town_entrance.body_entered.connect(_on_town_entrance_entered)
	Lesson.lesson_finished.connect(_on_lesson_finished)
	Dialogue.action_triggered.connect(_on_dialogue_action)
	Dialogue.dialogue_ended.connect(_on_dialogue_ended)
	Combat.finished.connect(_on_combat_finished)

func _on_item_collected(word_id: String) -> void:
	_items_collected += 1
	_update_progress_label()
	var word: Dictionary = WordBank.get_word(word_id)
	_show_toast("Learned: %s (%s)" % [word.spanish, word.english])

func _update_progress_label() -> void:
	progress_label.text = "Items found: %d / %d" % [_items_collected, MIN_ITEMS_TO_PROCEED]

## Why the player can't enter town yet, or "" if they can.
func _entry_blocker() -> String:
	if _items_collected < MIN_ITEMS_TO_PROCEED:
		return "Find a few more things before heading into town."
	if not SpellProgress.knows("bola_de_fuego"):
		return "That glowing scroll near the wreck... you should look at it first."
	if not GameState.has_flag("bandit_defeated"):
		return "You can't leave with that bandit still around."
	return ""

# --- The ambush --------------------------------------------------------------

func _on_lesson_finished(spell_id: String, mode: String) -> void:
	if mode == "learn" and spell_id == "bola_de_fuego" and not GameState.has_flag("bandit_defeated"):
		_start_ambush.call_deferred()

func _start_ambush() -> void:
	bandit.visible = true
	Dialogue.start(BANDIT_DIALOGUE, "start", "Bandit", "bandit")

func _on_dialogue_action(action: String) -> void:
	if action == "start_bandit_fight":
		_pending_fight = true

# The fight waits for the dialogue box to close so the two never overlap.
func _on_dialogue_ended() -> void:
	if _pending_fight:
		_pending_fight = false
		Combat.start("bandit_tutorial")

func _on_combat_finished(encounter_id: String, won: bool) -> void:
	if encounter_id != "bandit_tutorial":
		return
	if won:
		GameState.set_flag("bandit_defeated", true)
		bandit.visible = false
		Dialogue.show_message("The bandit scrambles off into the wreckage, clutching his bruises. The scroll is yours to keep.")
	else:
		_start_ambush.call_deferred()

func _on_town_entrance_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var blocker := _entry_blocker()
	if blocker == "":
		get_tree().change_scene_to_file("res://scenes/world/Town.tscn")
	else:
		_show_toast(blocker)

func _show_toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
