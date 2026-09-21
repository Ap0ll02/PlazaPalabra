extends Area2D
## Base for anything the player walks up to and presses interact (Enter/
## Space, Godot's built-in "ui_accept") on -- NPCs and searchable objects
## both extend this. Override _on_interact() in a subclass.
##
## While the player is in range a small "[Enter] <verb>" prompt floats above
## the object (a signifier for the interact key). Override _prompt_verb() to
## change the verb and _can_interact() to hide it once there's nothing left
## to do here.

const Fx := preload("res://scripts/ui/fx.gd")

var _player_in_range := false
var _prompt: Label
var _prompt_wanted := false
var _prompt_time := 0.0

func _ready() -> void:
	add_to_group("interactables")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_prompt()

func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.text = "[Enter] " + _prompt_verb()
	_prompt.add_theme_font_size_override("font_size", 16)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.14, 0.9)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	_prompt.add_theme_stylebox_override("normal", box)
	_prompt.z_index = 100
	_prompt.modulate.a = 0.0
	_prompt.visible = false
	add_child(_prompt)
	_prompt.position = Vector2(-_prompt.get_combined_minimum_size().x / 2.0, -_prompt_height())

## How far above the origin the prompt floats (NPCs raise it to clear their name).
func _prompt_height() -> float:
	return 64.0

func _prompt_verb() -> String:
	return "Interact"

func _can_interact() -> bool:
	return true

func _update_prompt(delta: float) -> void:
	var want := _player_in_range and _can_interact() and not _ui_busy()
	if want != _prompt_wanted:
		_prompt_wanted = want
		if want:
			Fx.fade_in(_prompt)
		else:
			Fx.fade_out(_prompt)
	if want:
		_prompt_time += delta
		_prompt.position.y = -_prompt_height() + sin(_prompt_time * 4.0) * 3.0

func _ui_busy() -> bool:
	return Dialogue.is_open or Spellbook.is_open or Lesson.is_open or Combat.is_open

func _process(delta: float) -> void:
	_update_prompt(delta)
	if _player_in_range and not _ui_busy() \
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
