extends Area2D
## Walk-over-to-collect scavenge item. Records the word as seen
## (PlayerProfile already logs this as telemetry) and disappears.

signal collected(word_id: String)

@export var word_id: String = ""

var _collected := false

func _ready() -> void:
	add_to_group("scavenge_items")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	PlayerProfile.record_seen(word_id)
	collected.emit(word_id)
	queue_free()
