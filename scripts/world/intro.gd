extends Node2D
## Rocket-landing cutscene, told as 5 shots rather than one continuous pan:
##   1. Wide establishing -- horizontal flight past the planet
##   2. Closer pass -- alarm begins
##   3. New angle -- atmosphere entry, vertical descent begins
##   4. Impact
##   5. Aftermath -- equipment failure, fade out
## Shots are hard-cut (quick black flash) rather than cross-faded, so it
## reads as camera cuts instead of one static continuous shot. Rocket/
## planet are placeholder shapes. Audio nodes are wired up but left
## streamless until real VO/SFX assets exist.

const GROUND_Y := 560.0
const NEXT_SCENE := "res://scenes/world/Outskirts.tscn"
const CUT_HALF_DURATION := 0.12

@onready var space_layer: Node2D = $SpaceLayer
@onready var planet: Node2D = $SpaceLayer/Planet
@onready var atmosphere_glow: Node2D = $AtmosphereGlow
@onready var ground_layer: Node2D = $GroundLayer
@onready var rocket: Node2D = $Rocket

@onready var flash: ColorRect = $CanvasLayer/ImpactFlash
@onready var fade: ColorRect = $CanvasLayer/FadeToBlack
@onready var caption: Label = $CanvasLayer/CaptionLabel
@onready var skip_button: Button = $CanvasLayer/SkipButton

@onready var sfx_engine: AudioStreamPlayer = $SfxEngine
@onready var sfx_alarm: AudioStreamPlayer = $SfxAlarm
@onready var sfx_impact: AudioStreamPlayer = $SfxImpact

var _skipped := false

func _ready() -> void:
	skip_button.pressed.connect(_on_skip_pressed)
	caption.visible = Settings.captions_enabled
	caption.text = ""
	ground_layer.visible = false
	atmosphere_glow.visible = false
	_play_sequence()

func _on_skip_pressed() -> void:
	_skipped = true
	_goto_next_scene()

func _set_caption(text: String) -> void:
	caption.text = text
	caption.visible = Settings.captions_enabled and text != ""

## Quick black flash used as a hard cut between shots -- hides the
## instant reposition/visibility swap that happens mid-flash.
func _hard_cut(setup: Callable) -> void:
	var out_tween := create_tween()
	out_tween.tween_property(fade, "color:a", 1.0, CUT_HALF_DURATION)
	await out_tween.finished
	setup.call()
	var in_tween := create_tween()
	in_tween.tween_property(fade, "color:a", 0.0, CUT_HALF_DURATION)
	await in_tween.finished

func _play_sequence() -> void:
	# --- Shot 1: wide establishing, flying horizontally past the planet ---
	space_layer.visible = true
	rocket.rotation = deg_to_rad(90)
	rocket.scale = Vector2(0.6, 0.6)
	rocket.position = Vector2(-80, 260)
	planet.position = Vector2(980, 560)
	planet.scale = Vector2(1.0, 1.0)
	_set_caption("Approaching orbit...")
	if sfx_engine.stream:
		sfx_engine.play()

	# Constant cruise speed -- no ease in/out, so it's already at full
	# speed when the next shot cuts in (see note on shot 2).
	var shot1 := create_tween()
	shot1.tween_property(rocket, "position:x", 1360, 2.2).set_trans(Tween.TRANS_LINEAR)
	await shot1.finished
	if _skipped:
		return

	# --- Shot 2: closer pass, alarm begins ---
	await _hard_cut(func():
		rocket.position = Vector2(120, 300)
		rocket.rotation = deg_to_rad(95)
		rocket.scale = Vector2(0.85, 0.85)
		planet.position = Vector2(760, 640)
		planet.scale = Vector2(1.6, 1.6)
		_set_caption("Warning: hull integrity failing")
		if sfx_alarm.stream:
			sfx_alarm.play()
	)
	# Same idea: constant speed straight through, no easing at the cut
	# boundary, so the reposition reads as "same flight, new angle" rather
	# than a stop-and-restart.
	var shot2 := create_tween()
	shot2.tween_property(rocket, "position:x", 760, 1.3).set_trans(Tween.TRANS_LINEAR)
	shot2.parallel().tween_property(rocket, "position:y", 340, 1.3).set_trans(Tween.TRANS_LINEAR)
	await shot2.finished
	if _skipped:
		return

	# --- Shot 3: new angle, atmosphere entry, descent begins ---
	await _hard_cut(func():
		atmosphere_glow.visible = true
		rocket.position = Vector2(640, 30)
		rocket.rotation = 0.0
		rocket.scale = Vector2(1.0, 1.0)
		_set_caption("Atmosphere entry -- brace!")
	)
	# Accelerating fall (ease in, never ease out) -- it's still speeding up
	# right when shot 4 cuts in, so the descent never visibly stalls.
	var shot3 := create_tween()
	shot3.tween_property(rocket, "position:y", 380, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	shot3.chain().tween_property(rocket, "rotation", deg_to_rad(-8), 0.25)
	shot3.chain().tween_property(rocket, "rotation", deg_to_rad(8), 0.25)
	shot3.chain().tween_property(rocket, "rotation", deg_to_rad(-3), 0.25)
	await shot3.finished
	if _skipped:
		return

	# --- Shot 4: impact ---
	await _hard_cut(func():
		space_layer.visible = false
		atmosphere_glow.visible = false
		ground_layer.visible = true
		rocket.position = Vector2(640, 120)
		rocket.rotation = deg_to_rad(4)
	)
	# Picks up at the fast speed shot 3 ended at (linear, not another
	# slow-start ease-in) -- final approach reads as one continuous fall.
	var shot4 := create_tween()
	shot4.tween_property(rocket, "position:y", GROUND_Y, 0.45).set_trans(Tween.TRANS_LINEAR)
	await shot4.finished
	if _skipped:
		return

	_impact()
	await get_tree().create_timer(0.9).timeout
	if _skipped:
		return

	# --- Shot 5: aftermath, equipment failure, fade out ---
	_set_caption("...system error. Translator offline.")
	await get_tree().create_timer(1.6).timeout
	if _skipped:
		return

	_goto_next_scene()

func _impact() -> void:
	if sfx_engine.stream:
		sfx_engine.stop()
	if sfx_impact.stream:
		sfx_impact.play()

	flash.color.a = 0.85
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.4)

	var shake := create_tween()
	var base_pos := position
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 6:
		var offset := Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8))
		shake.tween_property(self, "position", base_pos + offset, 0.05)
	shake.tween_property(self, "position", base_pos, 0.05)

func _goto_next_scene() -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(fade, "color:a", 1.0, 0.7)
	await fade_tween.finished
	get_tree().change_scene_to_file(NEXT_SCENE)
