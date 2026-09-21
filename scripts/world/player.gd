extends CharacterBody2D
## Simple top-down movement, WASD or arrow keys. Reads raw key state
## rather than custom input actions -- one less thing to misconfigure by
## hand, and remapping isn't a concern for this demo.

const SPEED := 220.0
const BOUNDS := Rect2(20, 20, 1240, 680)

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	if Dialogue.is_open or Spellbook.is_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir.length() > 0.0:
		dir = dir.normalized()

	velocity = dir * SPEED
	move_and_slide()
	position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
	position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)
