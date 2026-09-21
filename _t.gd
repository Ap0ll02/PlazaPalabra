extends Node
func _ready():
	var ruins = load("res://scenes/world/Ruins.tscn").instantiate()
	add_child(ruins)
	await get_tree().process_frame
	ruins.player.position = Vector2(900, 300)
	ruins._on_combat_finished("sombra_boss", false)
	await get_tree().create_timer(0.3).timeout
	print("LOSS: dialogue=", Dialogue.is_open, " pos=", ruins.player.position, " flag=", GameState.has_flag("sombra_lost"))
	print("LOSS: sombra start node=", ruins.get_node("Sombra")._get_start_node())
	Dialogue._end_dialogue()
	ruins._on_combat_finished("sombra_boss", true)
	await get_tree().create_timer(0.3).timeout
	print("WIN: dialogue=", Dialogue.is_open, " pending=", ruins._pending_scene)
	get_tree().quit()
