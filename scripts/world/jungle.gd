extends Node2D
## Week 2, part 2: the jungle. Two spells are hidden here: Salud Divina on
## the floor (a normal pickup) and Terremoto Violento, guarded by an
## optional jaguar. The clearing to the east is where Sombra waits.

@onready var jaguar: Area2D = $Jaguar
@onready var quake_scroll: Area2D = $QuakeScroll

var _pending_fight := false

func _ready() -> void:
	add_to_group("gameplay_scene")
	GameState.set_quest_stage("week2_jungle")
	Dialogue.action_triggered.connect(_on_dialogue_action)
	Dialogue.dialogue_ended.connect(_on_dialogue_ended)
	Combat.finished.connect(_on_combat_finished)
	$ClearingExit.body_entered.connect(_on_clearing_exit_entered)
	if GameState.has_flag("w2_jaguar_defeated"):
		_after_jaguar()
	else:
		quake_scroll.visible = false
		quake_scroll.monitoring = false

func _on_dialogue_action(action: String) -> void:
	if action == "start_jaguar_fight":
		_pending_fight = true

func _on_dialogue_ended() -> void:
	if _pending_fight:
		_pending_fight = false
		Combat.start("jaguar_optional")

func _on_combat_finished(encounter_id: String, won: bool) -> void:
	if encounter_id != "jaguar_optional":
		return
	if won:
		GameState.set_flag("w2_jaguar_defeated", true)
		_after_jaguar()
		Dialogue.show_message.call_deferred("The jaguar slinks away into the trees, leaving the shrine's scroll behind.")
	else:
		Dialogue.show_message.call_deferred("The jaguar drives you back. Catch your breath, check your spellbook, and try again.")

func _after_jaguar() -> void:
	jaguar.visible = false
	jaguar.monitoring = false
	quake_scroll.visible = true
	quake_scroll.set_deferred("monitoring", true)

func _on_clearing_exit_entered(body: Node) -> void:
	if body.is_in_group("player"):
		get_tree().change_scene_to_file("res://scenes/world/Clearing.tscn")
