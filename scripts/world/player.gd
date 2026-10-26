extends CharacterBody2D
## Simple top-down movement, WASD or arrow keys. Reads raw key state
## rather than custom input actions -- one less thing to misconfigure by
## hand, and remapping isn't a concern for this demo.

const SPEED := 220.0
const BOUNDS := Rect2(20, 20, 1240, 680)
const BOB_HEIGHT := 3.0
const BOB_CYCLES_PER_SECOND := 5.5
const BOB_SETTLE_SPEED := 18.0
@onready var visual = $Visual
var _bob_phase := 0.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	if Dialogue.is_open or Spellbook.is_open or Lesson.is_open or Combat.is_open:
		velocity = Vector2.ZERO
		_update_bob(delta, false)
		move_and_slide()
		return

	var dir := Vector2.ZERO
	var speed_mult = 1.0

	if Input.is_physical_key_pressed(KEY_SHIFT):
		speed_mult = 1.4
	else:
		speed_mult = 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir.length() > 0.0:
		if abs(dir.x) >= abs(dir.y) and dir.x != 0.0:
			visual.set_facing("right" if dir.x > 0.0 else "left")
		else:
			visual.set_facing("front" if dir.y > 0.0 else "back")
		dir = dir.normalized()

	_update_bob(delta, dir != Vector2.ZERO)
	velocity = dir * SPEED * speed_mult
	move_and_slide()
	position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
	position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)

func _update_bob(delta: float, moving: bool) -> void:
	if moving:
		_bob_phase += delta * TAU * BOB_CYCLES_PER_SECOND
		visual.position.y = sin(_bob_phase) * BOB_HEIGHT
	else:
		visual.position.y = move_toward(visual.position.y, 0.0, BOB_SETTLE_SPEED * delta)
