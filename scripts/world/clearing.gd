extends Node2D
## Week 2, finale: Sombra is back, stronger. Beat him to free Tomas; the
## story ends here (placeholder closing lines -- edit the dicts) and the
## session continues to the follow-up survey. Losing sends you back to the
## edge of the clearing; talk to Sombra again to retry.

const ENTRANCE := Vector2(80, 380)

const WIN := {
	"start": {
		"speaker": "Sombra", "portrait": "sombra_angry",
		"text": "Impossible... You speak better than you did before.",
		"next": "cage",
	},
	"cage": {
		"speaker": "Sombra", "portrait": "sombra_smug",
		"text": "Fine. Take your old man. The cage is open. But I wasn't working alone...",
		"next": "tomas",
	},
	"tomas": {
		"speaker": "Tomas", "portrait": "tomas",
		"text": "You came all the way out here for me. Thank you. Sombra was only a piece of something bigger.",
		"next": "hook",
	},
	"hook": {
		"speaker": "Tomas", "portrait": "tomas_serious",
		"text": "But that is a story for another day. Let's go home.",
		"next": "end",
	},
}

const LOSS := {
	"start": {
		"speaker": "Sombra", "portrait": "sombra_smug",
		"text": "Ha! Is that all? Practice, then come back.",
		"next": "end",
	},
}

@onready var player: Node2D = $Player
@onready var tomas: Node2D = $Tomas
@onready var cage: Node2D = $Cage

var _pending_scene := ""
var _pending_fight := false

func _ready() -> void:
	add_to_group("gameplay_scene")
	GameState.set_quest_stage("week2_final")
	Dialogue.action_triggered.connect(_on_dialogue_action)
	Dialogue.dialogue_ended.connect(_on_dialogue_ended)
	Combat.finished.connect(_on_combat_finished)

func _on_dialogue_action(action: String) -> void:
	if action == "start_final_fight":
		_pending_fight = true

func _on_dialogue_ended() -> void:
	if _pending_fight:
		_pending_fight = false
		Combat.start("sombra_returns")
	elif _pending_scene != "":
		get_tree().change_scene_to_file(_pending_scene)

func _on_combat_finished(encounter_id: String, won: bool) -> void:
	if encounter_id != "sombra_returns":
		return
	if won:
		GameState.set_flag("w2_sombra_defeated", true)
		cage.visible = false
		_pending_scene = "res://scenes/ui/FollowUpSurvey.tscn"
		Dialogue.start.call_deferred(WIN)
	else:
		GameState.set_flag("w2_sombra_lost", true)
		player.position = ENTRANCE
		Dialogue.start.call_deferred(LOSS)
