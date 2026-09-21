extends CanvasLayer
## Positive feedback: a correct-in-a-row counter, escalating praise words,
## and confetti at milestones and flawless runs. Purely feedback -- it never
## changes damage, accuracy or practice credit -- and one streak runs across
## lessons and combat. A wrong answer resets it gently (the best run stays).
##
## Callers: Praise.correct() on a first-try right answer, Praise.wrong() on a
## miss, Praise.celebrate("Flawless!") for big moments. Everything is short
## (under ~1s) and non-blocking.

signal streak_changed(streak: int)

const Fx := preload("res://scripts/ui/fx.gd")

## Streak lengths that get a confetti burst and an "N in a row" banner.
const MILESTONES := [5, 10, 15, 20, 25, 30, 40, 50]
const CONFETTI_COLORS := [
	Color(0.98, 0.78, 0.25), Color(0.95, 0.4, 0.45), Color(0.4, 0.75, 0.95),
	Color(0.5, 0.85, 0.5), Color(0.8, 0.55, 0.95),
]

var streak := 0
var best := 0

var _pill: Label
var _pop: Label
var _pop_tween: Tween
var _pill_tween: Tween
var _break_note_until := 0.0
var _pill_shown := false

func _ready() -> void:
	layer = 30
	_pill = Label.new()
	_pill.position = Vector2(28, 64)
	_pill.add_theme_font_size_override("font_size", 18)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.4)
	box.set_corner_radius_all(14)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	_pill.add_theme_stylebox_override("normal", box)
	_pill.visible = false
	add_child(_pill)

	_pop = Label.new()
	_pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_pop.position = Vector2(0, 110)
	_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pop.add_theme_constant_override("outline_size", 8)
	_pop.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.visible = false
	add_child(_pop)
	_refresh_pill()

func _process(_delta: float) -> void:
	var want: bool = Lesson.is_open or Combat.is_open
	if want != _pill_shown:
		_pill_shown = want
		if want:
			Fx.fade_in(_pill)
		else:
			Fx.fade_out(_pill)

# --- Public API --------------------------------------------------------------------

## A first-try correct answer.
func correct() -> void:
	streak += 1
	best = maxi(best, streak)
	StudySession.log_event("streak", {"streak": streak})
	_refresh_pill()
	streak_changed.emit(streak)
	if MILESTONES.has(streak):
		_show_pop("%d in a row!" % streak, 1.35, Color(1.0, 0.85, 0.3))
		_confetti(0.35)
	else:
		_show_pop(_word_for(streak), _size_for(streak), _color_for(streak))

## A miss. Resets the streak, kindly.
func wrong() -> void:
	if streak == 0:
		return
	var ended := streak
	streak = 0
	StudySession.log_event("streak_broken", {"ended_at": ended, "best": best})
	streak_changed.emit(streak)
	if ended >= 3:
		_pill.text = "Streak ended at %d  -  best %d. Nice run!" % [ended, best]
		_break_note_until = Time.get_ticks_msec() / 1000.0 + 2.2
		get_tree().create_timer(2.3).timeout.connect(_refresh_pill)
	else:
		_refresh_pill()

## A big moment: flawless lesson, perfect cast, spell learned, victory.
func celebrate(text: String, big: bool = true) -> void:
	_show_pop(text, 1.6 if big else 1.3, Color(1.0, 0.85, 0.3))
	_confetti(0.5 if big else 0.3)

# --- Internals ------------------------------------------------------------------------

func _word_for(n: int) -> String:
	if n >= 10: return "Unstoppable!"
	if n >= 7: return "Amazing!"
	if n >= 5: return "Excellent!"
	if n >= 3: return "Great!"
	if n == 2: return "Nice!"
	return "Correct!"

func _size_for(n: int) -> float:
	return 1.0 + minf(n, 10) * 0.03

func _color_for(n: int) -> Color:
	if n >= 5: return Color(1.0, 0.85, 0.3)
	if n >= 3: return Color(0.55, 0.9, 0.55)
	return Color(0.75, 0.95, 0.8)

func _refresh_pill() -> void:
	if Time.get_ticks_msec() / 1000.0 < _break_note_until:
		return
	_pill.text = "Streak  %d      Best  %d" % [streak, best]
	_pill.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if streak >= 3 else Color.WHITE)
	if _pill_shown and streak > 0:
		_pill.pivot_offset = _pill.size / 2.0
		if _pill_tween:
			_pill_tween.kill()
		_pill.scale = Vector2(1.18, 1.18)
		_pill_tween = create_tween()
		_pill_tween.tween_property(_pill, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pill_tween.finished.connect(func(): _pill_tween = null)

func _show_pop(text: String, size_scale: float, color: Color) -> void:
	_pop.text = text
	_pop.add_theme_font_size_override("font_size", 44)
	_pop.add_theme_color_override("font_color", color)
	_pop.reset_size()
	_pop.position.x = get_viewport().get_visible_rect().size.x / 2.0 - _pop.size.x / 2.0
	_pop.pivot_offset = _pop.size / 2.0
	if _pop_tween:
		_pop_tween.kill()
	_pop.visible = true
	_pop.modulate.a = 1.0
	_pop.scale = Vector2(0.5, 0.5)
	_pop.position.y = 250.0
	_pop_tween = create_tween()
	_pop_tween.tween_property(_pop, "scale", Vector2(size_scale, size_scale), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.parallel().tween_property(_pop, "position:y", 226.0, 0.7)
	_pop_tween.tween_interval(0.25)
	_pop_tween.tween_property(_pop, "modulate:a", 0.0, 0.3)
	_pop_tween.tween_callback(func(): _pop.visible = false)

func _confetti(amount_scale: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x / 2.0, 200)
	p.one_shot = true
	p.emitting = true
	p.amount = int(90 * amount_scale * 2.0)
	p.lifetime = 1.4
	p.explosiveness = 0.95
	p.direction = Vector2(0, 1)
	p.spread = 70.0
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 520.0
	p.gravity = Vector2(0, 700)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(180, 10)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(range(CONFETTI_COLORS.size()).map(func(i): return i / float(CONFETTI_COLORS.size() - 1)))
	gradient.colors = PackedColorArray(CONFETTI_COLORS)
	p.color_initial_ramp = gradient
	add_child(p)
	get_tree().create_timer(2.2).timeout.connect(p.queue_free)
