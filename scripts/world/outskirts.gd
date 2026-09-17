extends Node2D
## Stub for the tutorial start ("you wake up on the outskirts"). Movement,
## scavenging, and the walk into town get built here next.

func _ready() -> void:
	GameState.set_quest_stage("tutorial")
