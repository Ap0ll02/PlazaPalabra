extends Area2D
## Base for anything the player walks up to and presses interact (Enter/
## Space, Godot's built-in "ui_accept") on -- NPCs and searchable objects
## both extend this. Override _on_interact() in a subclass.

var _player_in_range := false

func _ready() -> void:
	add_to_group("interactables")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if _player_in_range and not Dialogue.is_open and not Spellbook.is_open \
			and Engine.get_process_frames() != Dialogue.closed_frame \
			and Input.is_action_just_pressed("ui_accept"):
		_on_interact()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false

func _on_interact() -> void:
	pass # override in subclass
