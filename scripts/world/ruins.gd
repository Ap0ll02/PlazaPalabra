extends Node2D
## Quest 2: the ruins. One optional hidden scroll (Tormenta de Hielo, see
## the IceScroll node) and Sombra, who starts the boss fight when spoken to.
##
## Fight flow: Sombra's dialogue -> (if the spellbook is nearly empty, a
## one-time "fill it first?" prompt) -> Combat "sombra_boss". Win: closing
## lines then the post-survey. Loss: back to the entrance, talk to Sombra
## again to retry.

const MIN_BOOK_SLOTS := 3
const ENTRANCE := Vector2(80, 380)

const NUDGE := {
	"start": {
		"text": "Your spellbook only has a few spells in it. Fill it up before facing Sombra?",
		"choices": [
			{"text": "Open my spellbook", "next": "open"},
			{"text": "Fight anyway", "next": "go"},
		],
	},
	"open": {"text": "Take your time. Talk to him when you're ready.", "on_enter": "open_book", "next": "end"},
	"go": {"text": "Here goes nothing.", "on_enter": "start_boss_fight", "next": "end"},
}

const WIN := {
	"start": {
		"speaker": "Sombra", "portrait": "sombra_angry",
		"text": "Tch... enough! Take your coins back. Who taught you to talk like that?",
		"next": "end",
	},
}

const LOSS := {
	"start": {
		"speaker": "Sombra", "portrait": "sombra_smug",
		"text": "Ha! Come back when you can string a sentence together.",
		"next": "end",
	},
}

var _pending_fight := false
var _pending_open_book := false
var _pending_scene := ""
var _nudged := false

@onready var player: Node2D = $Player

func _ready() -> void:
	add_to_group("gameplay_scene")
	GameState.set_quest_stage("quest_2")
	Dialogue.action_triggered.connect(_on_dialogue_action)
	Dialogue.dialogue_ended.connect(_on_dialogue_ended)
	Combat.finished.connect(_on_combat_finished)

func _on_dialogue_action(action: String) -> void:
	match action:
		"start_boss_fight": _pending_fight = true
		"open_book": _pending_open_book = true

# Everything waits for the dialogue box to close so overlays never stack.
func _on_dialogue_ended() -> void:
	if _pending_open_book:
		_pending_open_book = false
		Spellbook.open()
	elif _pending_fight:
		_pending_fight = false
		if SpellProgress.book_total() < MIN_BOOK_SLOTS and SpellProgress.book_total() > 0 and not _nudged:
			_nudged = true
			Dialogue.start(NUDGE)
		else:
			Combat.start("sombra_boss")
	elif _pending_scene != "":
		get_tree().change_scene_to_file(_pending_scene)

func _on_combat_finished(encounter_id: String, won: bool) -> void:
	if encounter_id != "sombra_boss":
		return
	if won:
		GameState.set_flag("sombra_defeated", true)
		GameState.set_quest_stage("boss")
		_pending_scene = "res://scenes/ui/PostSurvey.tscn"
		Dialogue.start.call_deferred(WIN)
	else:
		GameState.set_flag("sombra_lost", true)
		player.position = ENTRANCE
		Dialogue.start.call_deferred(LOSS)
