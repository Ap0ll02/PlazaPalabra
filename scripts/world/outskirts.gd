extends Node2D
## Tutorial: movement + scavenging first nouns, gated entrance into town.

const MIN_ITEMS_TO_PROCEED := 3

@onready var progress_label: Label = $CanvasLayer/ProgressLabel
@onready var toast_label: Label = $CanvasLayer/ToastLabel
@onready var town_entrance: Area2D = $TownEntrance

var _items_collected := 0
var _toast_tween: Tween

func _ready() -> void:
	add_to_group("gameplay_scene")
	GameState.set_quest_stage("tutorial")
	toast_label.modulate.a = 0.0
	_update_progress_label()
	for item in get_tree().get_nodes_in_group("scavenge_items"):
		item.collected.connect(_on_item_collected)
	town_entrance.body_entered.connect(_on_town_entrance_entered)

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
	return ""

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
