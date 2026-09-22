extends Node2D
## Week 2, part 1: you come back to town with Mira's money and find her
## surrounded by three bandits. Beat them, return the money, learn Rayo
## Morado from the scroll one of them dropped, discover Tomas is missing,
## and head into the jungle. All the dialogue is in the dicts below, so
## editing the story is editing text.

const AMBUSH := {
	"start": {
		"text": "You return to town with Mira's stolen coins, and stop short. Mira is surrounded by three bandits!",
		"next": "bandit",
	},
	"bandit": {
		"speaker": "Bandit", "portrait": "bandit",
		"text": "Well, well, look who's here! Hand over those coins and maybe we leave the lady alone.",
		"next": "mira",
	},
	"mira": {
		"speaker": "Mira", "portrait": "mira_worried",
		"text": "Please be careful! There are three of them!",
		"next": "fight",
	},
	"fight": {
		"speaker": "Bandit", "portrait": "bandit",
		"text": "Get them!",
		"on_enter": "start_w2_fight",
		"next": "end",
	},
	"retry": {
		"speaker": "Bandit", "portrait": "bandit",
		"text": "Ha! Had enough already? Then give us the coins!",
		"on_enter": "start_w2_fight",
		"next": "end",
	},
}

const THANKS := {
	"start": {
		"speaker": "Mira", "portrait": "mira_relieved",
		"text": "You did it! You beat them all! And you found my money?",
		"next": "give",
	},
	"give": {
		"text": "You hand Mira the coins.",
		"on_enter": "give_money",
		"next": "thank",
	},
	"thank": {
		"speaker": "Mira", "portrait": "mira_relieved",
		"text": "Thank you, truly! I wish I could repay you properly...",
		"next": "scroll",
	},
	"scroll": {
		"speaker": "Mira", "portrait": "mira",
		"text": "Wait! One of the bandits dropped a scroll when he ran. Please, take it. Maybe it can help you.",
		"on_enter": "give_scroll",
		"next": "end",
	},
}

const TOMAS_MISSING := {
	"start": {
		"speaker": "Mira", "portrait": "mira",
		"text": "Thank you again. Oh... where is Tomas? He was here just this morning.",
		"next": "taken",
	},
	"taken": {
		"speaker": "Mira", "portrait": "mira_sad",
		"text": "One of the bandits said he was taken. I have no idea what happened to him.",
		"next": "ask",
	},
	"ask": {
		"speaker": "Mira", "portrait": "mira_worried",
		"text": "Please, will you look for him? The jungle path to the east is where the bandits came from.",
		"on_enter": "reveal_jungle",
		"next": "end",
	},
}

@onready var jungle_exit: Area2D = $JungleExit
@onready var bandits: Node2D = $Bandits

var _pending := ""

func _ready() -> void:
	add_to_group("gameplay_scene")
	GameState.set_quest_stage("week2_town")
	Dialogue.action_triggered.connect(_on_dialogue_action)
	Dialogue.dialogue_ended.connect(_on_dialogue_ended)
	Combat.finished.connect(_on_combat_finished)
	Lesson.lesson_finished.connect(_on_lesson_finished)
	jungle_exit.body_entered.connect(_on_jungle_exit_entered)
	if GameState.has_flag("w2_bandits_defeated"):
		bandits.visible = false
		if GameState.has_flag("w2_tomas_missing"):
			_reveal_jungle()
	else:
		_start_ambush.call_deferred("start")

func _start_ambush(node: String) -> void:
	bandits.visible = true
	Dialogue.start(AMBUSH, node, "")

func _on_dialogue_action(action: String) -> void:
	match action:
		"start_w2_fight": _pending = "fight"
		"give_money": GameState.set_flag("w2_money_returned", true)
		"give_scroll": _pending = "scroll"
		"reveal_jungle":
			GameState.set_flag("w2_tomas_missing", true)
			_reveal_jungle()

# Everything waits for the dialogue box to close so overlays never stack.
func _on_dialogue_ended() -> void:
	match _pending:
		"fight":
			_pending = ""
			Combat.start("bandits_week2")
		"scroll":
			_pending = ""
			if SpellProgress.knows("rayo_morado"):
				Dialogue.start.call_deferred(TOMAS_MISSING)
			else:
				Lesson.start_learn("rayo_morado", true)

func _on_combat_finished(encounter_id: String, won: bool) -> void:
	if encounter_id != "bandits_week2":
		return
	if won:
		GameState.set_flag("w2_bandits_defeated", true)
		bandits.visible = false
		Dialogue.start.call_deferred(THANKS)
	else:
		_start_ambush.call_deferred("retry")

func _on_lesson_finished(spell_id: String, mode: String) -> void:
	if mode == "learn" and spell_id == "rayo_morado":
		Dialogue.start.call_deferred(TOMAS_MISSING)

func _reveal_jungle() -> void:
	jungle_exit.visible = true
	jungle_exit.set_deferred("monitoring", true)

func _on_jungle_exit_entered(body: Node) -> void:
	if body.is_in_group("player") and GameState.has_flag("w2_tomas_missing"):
		get_tree().change_scene_to_file("res://scenes/world/Jungle.tscn")
