extends CanvasLayer
## The battle screen, shown over the world. Combat.start("encounter_id")
## runs a fight (see scripts/combat/encounters.gd) and emits `finished`
## when it ends. All the rules live in scripts/combat/combat_state.gd;
## this script just drives the turn flow and displays it.
##
## Turn flow: choose a spell -> (pick a target if needed) -> answer one
## question per word of the spell's sentence (plus one about the appended
## phrase if Furia is active), each right answer raising the hit chance ->
## accuracy roll -> effect -> enemies act, announcing their spell in Spanish
## (English follows a moment later) -> next round.
##
## Keys: 1-9/0 pick the numbered option or enemy, H hint, Backspace back,
## Enter continue.

signal finished(encounter_id: String, won: bool)

const Config := preload("res://scripts/combat/combat_config.gd")
const Encounters := preload("res://scripts/combat/encounters.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")

const DIGIT_KEYS := {
	KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4,
	KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9,
}
const RIGHT_COLOR := Color(0.45, 0.8, 0.5)
const WRONG_COLOR := Color(0.85, 0.4, 0.4)
const OPTION_COLOR := Color(0.24, 0.55, 0.72)
const ENEMY_HP_COLOR := Color(0.85, 0.36, 0.36)
const PLAYER_HP_COLOR := Color(0.36, 0.76, 0.46)
const MANA_COLOR := Color(0.36, 0.56, 0.95)

enum Phase { NONE, MENU, TARGET, QUIZ, RESULT, ENEMY, OVER }

const Fx := preload("res://scripts/ui/fx.gd")
var is_open := false
var state: CombatState
var phase := Phase.NONE

@onready var overlay: Control = $Overlay
@onready var title_label: Label = $Overlay/TitleLabel
@onready var turn_label: Label = $Overlay/TurnLabel
@onready var status_label: Label = $Overlay/StatusLabel
@onready var enemy_row: HBoxContainer = $Overlay/EnemyRow
@onready var hp_bar: ProgressBar = $Overlay/PlayerBox/HpBar
@onready var hp_label: Label = $Overlay/PlayerBox/HpLabel
@onready var mana_bar: ProgressBar = $Overlay/PlayerBox/ManaBar
@onready var mana_label: Label = $Overlay/PlayerBox/ManaLabel
@onready var prompt_label: Label = $Overlay/ActionPanel/ActionBox/PromptLabel
@onready var detail_label: Label = $Overlay/ActionPanel/ActionBox/DetailLabel
@onready var options_box: GridContainer = $Overlay/ActionPanel/ActionBox/OptionsBox
@onready var translation_label: Label = $Overlay/ActionPanel/ActionBox/TranslationLabel
@onready var feedback_label: Label = $Overlay/ActionPanel/ActionBox/FeedbackLabel
@onready var hint_button: Button = $Overlay/ActionPanel/ActionBox/ButtonRow/HintButton
@onready var back_button: Button = $Overlay/ActionPanel/ActionBox/ButtonRow/BackButton
@onready var next_button: Button = $Overlay/ActionPanel/ActionBox/ButtonRow/NextButton

var _rng := RandomNumberGenerator.new()
var _encounter_id := ""
var _enemy_ui: Array = []
var _hotkeys: Array = []
var _target_badges: Array = []
var _translation_tween: Tween

# current player action
var _spell_id := ""
var _target := 0
var _after_target: Callable
var _questions: Array = []
var _q_index := 0
var _correct_count := 0
var _combine_result := -1
var _hints_used := 0
var _q_hinted := false
var _eliminated: Array = []
var _answered := false
var _q_missed := false
var _q_started_msec := 0
var _enemy_queue: Array = []
var _first_refresh := true
var _last_hp: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
	_apply_style()
	hint_button.pressed.connect(_on_hint_pressed)
	back_button.pressed.connect(_show_menu)
	next_button.pressed.connect(_on_next_pressed)

# --- Entry / exit ------------------------------------------------------------

func start(encounter_id: String) -> void:
	if is_open:
		return
	var enc := Encounters.get_encounter(encounter_id)
	if enc.is_empty():
		push_error("Unknown encounter: " + encounter_id)
		return
	if enc.get("use_book", false):
		if SpellProgress.book_total() == 0:
			Spellbook.open_with_note("Fill your spellbook before the fight: click spells on the left to copy them in.")
			return
		enc = enc.duplicate()
		enc.loadout = SpellProgress.book.duplicate()
	_encounter_id = encounter_id
	state = CombatState.new(enc, _rng, GameState.MAX_HP)
	GameState.hp = state.player_hp
	_first_refresh = true
	_last_hp = {}
	is_open = true
	Fx.fade_in(overlay)
	title_label.text = enc.title
	_build_enemies()
	StudySession.log_event("combat_started", {"encounter": encounter_id})
	_begin_player_turn()

func _end(won: bool) -> void:
	phase = Phase.OVER
	_clear_action()
	prompt_label.text = "Victory!" if won else "Defeated..."
	if won:
		Praise.celebrate("Victory!")
	_show_text(feedback_label, "You won the fight." if won else "You couldn't keep going.")
	next_button.text = "Continue  [Enter]"
	next_button.visible = true
	StudySession.log_event("combat_ended", {
		"encounter": _encounter_id, "won": won, "rounds": state.round_number, "hp_left": state.player_hp,
	})

func _close() -> void:
	var won := state.is_won()
	is_open = false
	Fx.fade_out(overlay)
	phase = Phase.NONE
	finished.emit(_encounter_id, won)

# --- Player turn -------------------------------------------------------------

func _begin_player_turn() -> void:
	state.begin_player_turn()
	turn_label.text = "Round %d" % state.round_number
	_refresh_all()
	_show_menu()

func _show_menu() -> void:
	phase = Phase.MENU
	_clear_action()
	options_box.columns = 2
	prompt_label.text = "Your turn - choose a spell"
	for id in SpellBank.all_ids():
		if state.uses_left(id) <= 0:
			continue
		var spell := SpellBank.get_spell(id)
		var b := _add_option("%s\n%s  -  %d mana  -  x%d left" % [
			spell.sentence_es, SpellBank.TYPE_LABELS[spell.type], spell.mana_cost, state.uses_left(id)],
			SpellBank.type_color(id).darkened(0.4), 58)
		b.disabled = not state.can_cast(id)
		b.pressed.connect(_on_spell_chosen.bind(id))
	if state.total_uses() == 0:
		var s := _add_option("Struggle\nA weak move - no mana, no quiz", Color(0.4, 0.4, 0.46), 58)
		s.pressed.connect(_on_struggle_chosen)
	elif not state.any_castable():
		var w := _add_option("Wait a turn\nNot enough mana - regain some", Color(0.4, 0.4, 0.46), 58)
		w.pressed.connect(_on_wait_chosen)
	_refresh_all()

func _on_spell_chosen(spell_id: String) -> void:
	_spell_id = spell_id
	_target = state.living()[0]
	if state.needs_target(spell_id):
		_begin_target_select(_begin_quiz)
	else:
		_begin_quiz()

func _on_struggle_chosen() -> void:
	_spell_id = ""
	_target = state.living()[0]
	if state.living().size() > 1:
		_begin_target_select(_resolve_struggle)
	else:
		_resolve_struggle()

func _on_wait_chosen() -> void:
	_spell_id = ""
	_show_result("You wait and gather yourself.", "")

func _begin_target_select(then: Callable) -> void:
	phase = Phase.TARGET
	_after_target = then
	_clear_action()
	prompt_label.text = "Choose a target"
	_show_text(detail_label, "Click an enemy, or press its number.")
	back_button.visible = true
	for i in state.living():
		_register_target(_enemy_ui[i].button)

func _on_enemy_pressed(index: int) -> void:
	if phase != Phase.TARGET or state.enemies[index].hp <= 0:
		return
	_target = index
	_after_target.call()

# --- Cast quiz ---------------------------------------------------------------

func _begin_quiz() -> void:
	var spell := SpellBank.get_spell(_spell_id)
	_questions = state.build_questions(_spell_id)
	_q_index = 0
	_correct_count = 0
	_combine_result = -1
	_hints_used = 0
	for slot in spell.slots:
		PlayerProfile.record_seen(slot.word_id)
	_show_question()

func _pending_cost() -> int:
	if phase != Phase.QUIZ:
		return 0
	return SpellBank.get_spell(_spell_id).mana_cost + _hints_used

func _show_question() -> void:
	phase = Phase.QUIZ
	_answered = false
	_q_missed = false
	_q_started_msec = Time.get_ticks_msec()
	_q_hinted = false
	_eliminated = []
	_clear_action()
	options_box.columns = 3
	var spell := SpellBank.get_spell(_spell_id)
	var q: Dictionary = _questions[_q_index]
	prompt_label.text = "%s  -  question %d of %d" % [spell.name_es, _q_index + 1, _questions.size()]
	if q.kind == "combine":
		_show_text(detail_label, "Fury! Extend the spell. What is \"%s\"?" % q.prompt)
	else:
		if q.direction == "es_to_en":
			_show_text(detail_label, "What does \"%s\" mean in English?" % q.prompt)
		else:
			_show_text(detail_label, "What is \"%s\" in Spanish?" % q.prompt)
	_show_text(translation_label, "Hit chance so far: %d%%" % state.accuracy(_spell_id, _correct_count))
	for option in q.options:
		var b := _add_option(option, OPTION_COLOR, 52)
		b.pressed.connect(_on_option_pressed.bind(b))
	hint_button.visible = true
	_update_hint_button()
	_refresh_all()

func _update_hint_button() -> void:
	hint_button.disabled = _answered or not state.can_cast(_spell_id, _hints_used + Config.HINT_MANA_COST)

func _on_hint_pressed() -> void:
	if phase != Phase.QUIZ or _answered or hint_button.disabled:
		return
	var q: Dictionary = _questions[_q_index]
	var removed := state.hint_target(q, _eliminated)
	if removed == "":
		return
	_eliminated.append(removed)
	_hints_used += Config.HINT_MANA_COST
	_q_hinted = true
	PlayerProfile.record_hint(q.word_id)
	StudySession.log_event("combat_hint", {"spell_id": _spell_id, "word_id": q.word_id})
	for b in _hotkeys:
		if b.text == removed:
			b.disabled = true
			_style_option(b, Color(0.3, 0.3, 0.34))
	_update_hint_button()
	_refresh_all()

func _on_option_pressed(button: Button) -> void:
	if phase != Phase.QUIZ or _answered:
		return
	var q: Dictionary = _questions[_q_index]
	var correct: bool = button.text == q.correct
	if not correct:
		# A miss: show the right answer, but the player still has to pick it
		# themselves to lock it in (self-generation, no accuracy credit).
		_q_missed = true
		if q.kind == "combine":
			_combine_result = 0
		PlayerProfile.record_error(q.word_id, q.es_of.get(button.text, button.text))
		Praise.wrong()
		StudySession.log_event("combat_answer", {
			"spell_id": _spell_id, "word_id": q.word_id, "correct": false, "hinted": _q_hinted,
			"latency_ms": Time.get_ticks_msec() - _q_started_msec,
		})
		for b in _hotkeys:
			if b.text == q.correct:
				_style_option(b, RIGHT_COLOR.darkened(0.3))
			else:
				b.disabled = true
				if b == button:
					_style_option(b, WRONG_COLOR.darkened(0.2))
		hint_button.disabled = true
		_show_text(feedback_label, "Not quite - it's \"%s\". Pick it to lock it in." % q.correct)
		feedback_label.add_theme_color_override("font_color", WRONG_COLOR)
		return

	_answered = true
	if _q_missed:
		# Recovered after a miss: no credit, but praise the effort.
		_show_text(feedback_label, "That's it! \"%s\" - you'll remember it now." % q.correct)
	else:
		PlayerProfile.record_correct(q.word_id, _q_hinted)
		if q.kind == "combine":
			_combine_result = 1
		else:
			_correct_count += 1
		if not _q_hinted:
			Praise.correct()
		StudySession.log_event("combat_answer", {
			"spell_id": _spell_id, "word_id": q.word_id, "correct": true, "hinted": _q_hinted,
			"latency_ms": Time.get_ticks_msec() - _q_started_msec,
		})
		_show_text(feedback_label, "Correct!")
	for b in _hotkeys:
		b.disabled = true
		if b.text == q.correct:
			_style_option(b, RIGHT_COLOR.darkened(0.3))
	feedback_label.add_theme_color_override("font_color", RIGHT_COLOR)
	_show_text(translation_label, "Hit chance now: %d%%" % state.accuracy(_spell_id, _correct_count))
	hint_button.disabled = true
	next_button.text = ("Next" if _q_index + 1 < _questions.size() else "Cast!") + "  [Enter]"
	next_button.visible = true

func _on_next_pressed() -> void:
	match phase:
		Phase.QUIZ:
			if _q_index + 1 < _questions.size():
				_q_index += 1
				_show_question()
			else:
				_resolve_cast()
		Phase.RESULT:
			_after_player_action()
		Phase.ENEMY:
			_after_enemy_action()
		Phase.OVER:
			_close()

# --- Resolution ----------------------------------------------------------------

func _resolve_cast() -> void:
	var result := state.resolve_cast(_spell_id, _correct_count, _combine_result, _target, _hints_used)
	GameState.hp = state.player_hp
	StudySession.log_event("combat_cast", {
		"spell_id": _spell_id, "correct": _correct_count, "combine": _combine_result,
		"accuracy": result.accuracy, "roll": result.roll, "hit": result.hit,
		"hints": _hints_used, "bonus_pct": result.bonus_pct,
	})
	var spell := SpellBank.get_spell(_spell_id)
	if result.hit and _correct_count >= _questions.size() - (1 if _combine_result >= 0 else 0) and _hints_used == 0:
		Praise.celebrate("Perfect cast!", false)
	var lines: Array = ["Hit chance %d%%  -  you rolled %d." % [result.accuracy, result.roll]]
	if not result.hit:
		lines.append("The spell fizzles! You lose the turn, but the spell stays in your book.")
	else:
		for ev in result.events:
			lines.append(_describe_event(ev))
		if result.bonus_pct > 0:
			lines.append("Fury bonus: +%d%% damage!" % result.bonus_pct)
	_show_result("\n".join(lines), spell.name_es)

func _resolve_struggle() -> void:
	var result := state.resolve_struggle(_target)
	StudySession.log_event("combat_struggle", {})
	_show_result(_describe_event(result.events[0]), "Struggle")

func _describe_event(ev: Dictionary) -> String:
	match ev.kind:
		"damage":
			var text := "%s takes %d damage." % [ev.name, ev.amount]
			if ev.absorbed > 0:
				text = "%s's shield absorbs %d. " % [ev.name, ev.absorbed] + text
			if ev.killed:
				text += " %s is defeated!" % ev.name
			return text
		"shield": return "A shield forms and will absorb %d damage." % ev.amount
		"heal": return "You recover %d HP." % ev.amount
		"fury": return "Fury! Your next attack will hit harder."
	return ""

func _show_result(text: String, title: String) -> void:
	phase = Phase.RESULT
	_clear_action()
	prompt_label.text = title if title != "" else "Your turn"
	_show_text(feedback_label, text)
	feedback_label.add_theme_color_override("font_color", Color.WHITE)
	next_button.text = "Continue  [Enter]"
	next_button.visible = true
	_refresh_all()

func _after_player_action() -> void:
	if state.is_won():
		_end(true)
	else:
		_enemy_queue = state.living()
		_next_enemy()

# --- Enemy phase ----------------------------------------------------------------

func _next_enemy() -> void:
	while not _enemy_queue.is_empty() and state.enemies[_enemy_queue[0]].hp <= 0:
		_enemy_queue.pop_front()
	if _enemy_queue.is_empty():
		state.end_round()
		_begin_player_turn()
		return
	var index: int = _enemy_queue.pop_front()
	var act := state.enemy_action(index)
	GameState.hp = state.player_hp
	StudySession.log_event("combat_enemy_action", {
		"enemy": act.name, "spell": act.spell.es, "taken": act.taken, "absorbed": act.absorbed,
	})
	phase = Phase.ENEMY
	_clear_action()
	prompt_label.text = "%s casts:" % act.name
	_show_text(detail_label, act.spell.es)

	var effect := ""
	match act.spell.kind:
		"attack":
			effect = "You take %d damage." % act.taken
			if act.absorbed > 0:
				effect = "Your shield absorbs %d. " % act.absorbed + effect
		"shield": effect = "%s raises a shield." % act.name
		"heal": effect = "%s recovers %d HP." % [act.name, act.gained]
	_show_text(feedback_label, effect)
	feedback_label.add_theme_color_override("font_color", Color.WHITE)
	_schedule_translation(act.spell.en)
	next_button.text = "Continue  [Enter]"
	next_button.visible = true
	_refresh_all()

## The English line fades in after a moment, so the player gets a chance to
## read the Spanish first.
func _schedule_translation(english: String) -> void:
	translation_label.text = ""
	translation_label.visible = false
	if _translation_tween:
		_translation_tween.kill()
	_translation_tween = create_tween()
	_translation_tween.tween_interval(Config.TRANSLATION_DELAY)
	_translation_tween.tween_callback(_reveal_translation.bind(english))

func _reveal_translation(english: String) -> void:
	_show_text(translation_label, "\"%s\"" % english)

func _after_enemy_action() -> void:
	if state.is_lost():
		_end(false)
	else:
		_next_enemy()

# --- Display ---------------------------------------------------------------------

func _build_enemies() -> void:
	for child in enemy_row.get_children():
		enemy_row.remove_child(child)
		child.queue_free()
	_enemy_ui = []
	for i in state.enemies.size():
		var e: Dictionary = state.enemies[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 272)
		b.focus_mode = Control.FOCUS_NONE
		var clear := StyleBoxFlat.new()
		clear.bg_color = Color(0, 0, 0, 0)
		clear.set_corner_radius_all(12)
		for s in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(s, clear)
		b.pressed.connect(_on_enemy_pressed.bind(i))

		var figure := Polygon2D.new()
		figure.polygon = PackedVector2Array([Vector2(0, -56), Vector2(34, 12), Vector2(20, 56), Vector2(-20, 56), Vector2(-34, 12)])
		figure.color = e.color
		figure.position = Vector2(100, 100)
		b.add_child(figure)

		var shadow := _shadow(Vector2(100, 160), 46)
		b.add_child(shadow)
		b.move_child(shadow, 0)

		var name_label := _label(e.name, 18, Vector2(0, 172), 200)
		var bar := ProgressBar.new()
		bar.position = Vector2(10, 204)
		bar.size = Vector2(180, 22)
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.max_value = e.max_hp
		_style_bar(bar, ENEMY_HP_COLOR)
		var hp := _label("", 14, Vector2(10, 204), 180)
		hp.size.y = 22
		hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_outline(hp)
		var tag := _label("", 14, Vector2(0, 232), 200)
		tag.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
		for node in [name_label, bar, hp, tag]:
			b.add_child(node)
		enemy_row.add_child(b)
		_enemy_ui.append({"button": b, "bar": bar, "hp": hp, "tag": tag, "figure": figure})

# --- Look ---------------------------------------------------------------------------

func _box(color: Color, radius: int = 10, border: int = 0, border_color: Color = Color.WHITE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	return sb

func _style_bar(bar: ProgressBar, fill: Color) -> void:
	bar.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.5), 8, 2, Color(1, 1, 1, 0.14)))
	bar.add_theme_stylebox_override("fill", _box(fill, 8))

func _outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))

## Eases a bar to its new value (or jumps if not animating).
func _set_bar(bar: ProgressBar, max_value: float, value: float, animate: bool) -> void:
	bar.max_value = max_value
	if bar.has_meta("fx"):
		var old = bar.get_meta("fx")
		if old is Tween and old.is_valid():
			old.kill()
	if not animate:
		bar.value = value
		return
	var t := bar.create_tween()
	t.tween_property(bar, "value", value, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bar.set_meta("fx", t)

## A soft ground shadow under a fighter.
func _shadow(center: Vector2, radius: float) -> Polygon2D:
	var poly := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		points.append(Vector2(cos(a) * radius, sin(a) * radius * 0.28))
	poly.polygon = points
	poly.color = Color(0, 0, 0, 0.3)
	poly.position = center
	return poly

## Flashes a figure red when its HP went down since the last refresh.
func _flash_if_hurt(key, hp: int, figure: CanvasItem) -> void:
	if _last_hp.has(key) and hp < _last_hp[key] and is_instance_valid(figure):
		var t := figure.create_tween()
		figure.modulate = Color(2.2, 0.5, 0.5)
		t.tween_property(figure, "modulate", Color.WHITE, 0.4)
	_last_hp[key] = hp

## One-time styling of the scene's static pieces (bars, panels, backdrop).
func _apply_style() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.17, 0.2, 0.32))
	grad.set_color(1, Color(0.08, 0.09, 0.15))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	var sky := TextureRect.new()
	sky.texture = tex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(sky)
	overlay.move_child(sky, 1)
	$Overlay/Backdrop.visible = false

	var ground: ColorRect = $Overlay/Ground
	ground.color = Color(0.12, 0.13, 0.19)
	var edge := ColorRect.new()
	edge.color = Color(1, 1, 1, 0.08)
	edge.size = Vector2(1280, 2)
	ground.add_child(edge)

	var pill := _box(Color(0, 0, 0, 0.35), 16)
	pill.content_margin_top = 3
	pill.content_margin_bottom = 3
	turn_label.add_theme_stylebox_override("normal", pill)
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	_outline(title_label)

	var panel: Panel = $Overlay/ActionPanel
	panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.11, 0.16, 0.97), 18, 2, Color(0.4, 0.5, 0.75, 0.35)))

	_style_bar(hp_bar, PLAYER_HP_COLOR)
	_style_bar(mana_bar, MANA_COLOR)
	for l in [hp_label, mana_label]:
		_outline(l)
	var player_shadow := _shadow($Overlay/PlayerBox/Figure.position + Vector2(0, 52), 46)
	$Overlay/PlayerBox.add_child(player_shadow)
	$Overlay/PlayerBox.move_child(player_shadow, 0)

	_style_option(hint_button, Color(0.3, 0.32, 0.42))
	_style_option(back_button, Color(0.3, 0.32, 0.42))
	_style_option(next_button, OPTION_COLOR)

func _label(text: String, size: int, pos: Vector2, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	return l

func _refresh_all() -> void:
	var animate := not _first_refresh
	_set_bar(hp_bar, state.player_max_hp, state.player_hp, animate)
	hp_label.text = "HP %d / %d" % [state.player_hp, state.player_max_hp]
	_flash_if_hurt("player", state.player_hp, $Overlay/PlayerBox/Figure)
	var pending := _pending_cost()
	_set_bar(mana_bar, Config.MANA_MAX, maxi(0, state.mana - pending), animate)
	mana_label.text = "Mana %d / %d" % [state.mana, Config.MANA_MAX] if pending == 0 \
		else "Mana %d / %d   (this cast: -%d)" % [state.mana, Config.MANA_MAX, pending]

	var status: Array = []
	if state.fury_pending:
		status.append("Fury ready: your next attack hits harder")
	if state.shield > 0:
		status.append("Shield: absorbs %d" % state.shield)
	status_label.text = "\n".join(status)

	for i in _enemy_ui.size():
		var e: Dictionary = state.enemies[i]
		var ui: Dictionary = _enemy_ui[i]
		_set_bar(ui.bar, e.max_hp, e.hp, animate)
		_flash_if_hurt(i, e.hp, ui.figure)
		ui.hp.text = "HP %d / %d" % [e.hp, e.max_hp] if e.hp > 0 else "Defeated"
		ui.tag.text = "Shield %d" % e.shield if e.shield > 0 else ""
		ui.button.modulate.a = 1.0 if e.hp > 0 else 0.3
	_first_refresh = false

func _show_text(label: Label, text: String) -> void:
	Fx.fade_text(label, text)

func _clear_action() -> void:
	if _translation_tween:
		_translation_tween.kill()
	for child in options_box.get_children():
		options_box.remove_child(child)
		child.queue_free()
	for badge in _target_badges:
		if is_instance_valid(badge):
			badge.queue_free()
	_target_badges = []
	_hotkeys = []
	for label in [detail_label, translation_label, feedback_label]:
		_show_text(label, "")
	hint_button.visible = false
	back_button.visible = false
	next_button.visible = false

func _add_option(text: String, color: Color, height: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	_style_option(b, color)
	options_box.add_child(b)
	_register_hotkey(b, false)
	return b

func _style_option(button: Button, color: Color) -> void:
	var normal := _box(color, 12, 2, color.lightened(0.25))
	var hover := _box(color.lightened(0.14), 12, 2, color.lightened(0.5))
	var pressed := _box(color.darkened(0.15), 12, 2, color.lightened(0.25))
	var dim := _box(color.darkened(0.4), 12, 2, color.darkened(0.2))
	for st in [normal, hover, pressed, dim]:
		st.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", dim)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(c, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	button.add_theme_font_size_override("font_size", 18)

func _register_target(button: Button) -> void:
	_register_hotkey(button, true)

## Registers a number-key option and draws its number in the top-left corner.
func _register_hotkey(button: Button, is_target: bool) -> void:
	_hotkeys.append(button)
	if _hotkeys.size() > DIGIT_KEYS.size():
		return
	var badge := Label.new()
	badge.text = str(_hotkeys.size() % 10)
	badge.position = Vector2(8, 8)
	badge.custom_minimum_size = Vector2(22, 22)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	badge.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.35), 6))
	button.add_child(badge)
	if is_target:
		_target_badges.append(badge)

# --- Keyboard ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode
	if DIGIT_KEYS.has(key):
		var i: int = DIGIT_KEYS[key]
		if i < _hotkeys.size() and is_instance_valid(_hotkeys[i]) and not _hotkeys[i].disabled:
			_hotkeys[i].pressed.emit()
		get_viewport().set_input_as_handled()
	elif key == KEY_H:
		if hint_button.visible:
			_on_hint_pressed()
		get_viewport().set_input_as_handled()
	elif key == KEY_BACKSPACE:
		if back_button.visible:
			back_button.pressed.emit()
		get_viewport().set_input_as_handled()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		if next_button.visible:
			next_button.pressed.emit()
		get_viewport().set_input_as_handled()
