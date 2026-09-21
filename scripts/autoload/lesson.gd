extends CanvasLayer
## The lesson overlay: learn a new spell (translate -> build -> one cast
## question) or practice a known one (build + one extra exercise chosen by
## mastery tier). What each lesson contains is decided in
## scripts/lesson/lesson_plan.gd; this file runs the exercises.
##
## Wrong picks never block: the option is marked red and the player tries
## again, and a completed lesson always counts. Typed answers get two tries,
## then the answer is shown. Mistakes are logged per word.

signal lesson_finished(spell_id: String, mode: String)

const TextGrader := preload("res://scripts/lesson/text_grader.gd")
const LessonPlan := preload("res://scripts/lesson/lesson_plan.gd")

const CARD_TEXT := Color(0.1, 0.1, 0.12)
const CARD_EMPTY_TEXT := Color(0.55, 0.55, 0.6)
const CARD_ACTIVE := Color(0.95, 0.8, 0.35)
const CHOICE_COLOR := Color(0.24, 0.55, 0.72)
const WRONG_COLOR := Color(0.78, 0.32, 0.32)
const RIGHT_COLOR := Color(0.45, 0.8, 0.5)
const MAX_TILE_CHECKS := 3
const MAX_TYPED_TRIES := 2

var is_open := false

@onready var overlay: Control = $Overlay
@onready var title_label: Label = $Overlay/TitleLabel
@onready var step_label: Label = $Overlay/StepLabel
@onready var quit_button: Button = $Overlay/QuitButton
@onready var prompt_label: Label = $Overlay/Center/PromptLabel
@onready var guide_label: Label = $Overlay/Center/GuideLabel
@onready var content: VBoxContainer = $Overlay/Center/Content
@onready var feedback_label: Label = $Overlay/Center/FeedbackLabel
@onready var continue_button: Button = $Overlay/Center/ContinueButton
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

var _spell_id := ""
var _mode := ""
var _plan: Array = []
var _step := 0
var _lesson_mistakes := 0
var _exercise_mistakes := 0
var _tier_up_name := ""
var _rng := RandomNumberGenerator.new()
## State of the exercise currently on screen.
var _ex: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
	quit_button.pressed.connect(_abandon)
	continue_button.pressed.connect(_on_continue)
	SpellProgress.tier_up.connect(_on_tier_up)
	Spellbook.practice_requested.connect(start_practice)

# --- Entry points ----------------------------------------------------------

func start_learn(spell_id: String) -> void:
	if SpellProgress.knows(spell_id):
		return
	_begin(spell_id, "learn")

func start_practice(spell_id: String) -> void:
	if not SpellProgress.knows(spell_id):
		return
	_begin(spell_id, "practice")

func _begin(spell_id: String, mode: String) -> void:
	if is_open or not SpellBank.has_spell(spell_id):
		return
	_spell_id = spell_id
	_mode = mode
	var tier := SpellProgress.tier_index(spell_id) if mode == "practice" else 0
	_plan = LessonPlan.build_plan(spell_id, mode, tier, _rng)
	_step = 0
	_lesson_mistakes = 0
	_tier_up_name = ""
	is_open = true
	overlay.visible = true

	var spell := SpellBank.get_spell(spell_id)
	if mode == "learn":
		title_label.text = "Learning: %s" % spell.name_es
	else:
		title_label.text = "Practice: %s  (%s)" % [spell.name_es, SpellProgress.tier_name(spell_id)]
	StudySession.log_event("lesson_started", {"spell_id": spell_id, "mode": mode, "tier": tier})
	_run_exercise()

# --- Flow ------------------------------------------------------------------

func _run_exercise() -> void:
	_clear_content()
	_ex = {}
	_exercise_mistakes = 0
	continue_button.visible = false
	_set_feedback("")
	step_label.text = "Step %d / %d" % [_step + 1, _plan.size()]

	var spec: Dictionary = _plan[_step]
	match spec.kind:
		"translate_tiles": _setup_translate_tiles()
		"translate_type": _setup_translate_type(spec)
		"build": _setup_build(spec)
		"quiz", "fill_blank", "listen_pick": _setup_choice(spec)

func _on_continue() -> void:
	if _ex.get("kind", "") == "done":
		_close(true)
		return
	_step += 1
	if _step >= _plan.size():
		_finish()
	else:
		_run_exercise()

func _exercise_complete(message: String) -> void:
	_ex.complete = true
	_set_feedback(message, RIGHT_COLOR)
	continue_button.text = "Continue" if _step + 1 < _plan.size() else "Finish"
	continue_button.visible = true
	StudySession.log_event("lesson_exercise_done", {
		"spell_id": _spell_id, "kind": _ex.kind, "mistakes": _exercise_mistakes,
	})

func _finish() -> void:
	_clear_content()
	var spell := SpellBank.get_spell(_spell_id)
	if _mode == "learn":
		SpellProgress.learn_spell(_spell_id)
		prompt_label.text = "You learned %s!" % spell.name_es
		guide_label.text = "%s\n(%s)" % [spell.sentence_es, spell.sentence_en]
		_set_feedback("It's in your spellbook now. Practice it there to make it stronger.", RIGHT_COLOR)
	else:
		SpellProgress.record_practice(_spell_id)
		prompt_label.text = "Practice complete!"
		guide_label.text = "%s  -  %s  (%d practices)" % [
			spell.name_es, SpellProgress.tier_name(_spell_id), SpellProgress.practice_count(_spell_id)]
		if _tier_up_name != "":
			_set_feedback("Tier up: %s!" % _tier_up_name, RIGHT_COLOR)
		else:
			_set_feedback("Mistakes this lesson: %d" % _lesson_mistakes, RIGHT_COLOR)
	step_label.text = ""
	continue_button.text = "Done"
	continue_button.visible = true
	_ex = {"kind": "done"}
	StudySession.log_event("lesson_completed", {
		"spell_id": _spell_id, "mode": _mode, "mistakes": _lesson_mistakes,
	})

func _abandon() -> void:
	StudySession.log_event("lesson_abandoned", {"spell_id": _spell_id, "mode": _mode, "step": _step})
	_close(false)

func _close(completed: bool) -> void:
	is_open = false
	overlay.visible = false
	audio_player.stop()
	_clear_content()
	if completed:
		lesson_finished.emit(_spell_id, _mode)

func _on_tier_up(_spell_id_arg: String, tier_name: String) -> void:
	_tier_up_name = tier_name

func _mistake(word_id: String) -> void:
	_lesson_mistakes += 1
	_exercise_mistakes += 1
	StudySession.log_event("lesson_wrong", {"spell_id": _spell_id, "kind": _ex.get("kind", ""), "word_id": word_id})

# --- Build exercise --------------------------------------------------------

func _setup_build(spec: Dictionary) -> void:
	var spell := SpellBank.get_spell(_spell_id)
	prompt_label.text = "Build the spell"
	if spec.guided:
		guide_label.text = "%s\n(%s)" % [spell.sentence_es, spell.sentence_en]
	else:
		guide_label.text = "Say it in Spanish: %s" % spell.sentence_en
	for slot in spell.slots:
		PlayerProfile.record_seen(slot.word_id)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 24)
	var cards: Array = []
	for i in spell.slots.size():
		var card := Button.new()
		card.custom_minimum_size = Vector2(230, 110)
		card.pressed.connect(_on_build_card_pressed.bind(i))
		card_row.add_child(card)
		cards.append(card)
	content.add_child(card_row)

	var choices_box := VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 10)
	choices_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(choices_box)

	_ex = {
		"kind": "build", "spec": spec, "placed": ["", "", ""], "pos": 0, "tries": 0,
		"cards": cards, "choices_box": choices_box, "complete": false,
	}
	_render_build()

func _render_build() -> void:
	var spell := SpellBank.get_spell(_spell_id)
	var spec: Dictionary = _ex.spec
	var order: Array = spec.order
	var pos: int = _ex.pos
	var active_slot: int = order[pos] if pos < order.size() else -1

	for i in _ex.cards.size():
		var card: Button = _ex.cards[i]
		var placed_text: String = _ex.placed[i]
		if placed_text != "":
			card.text = placed_text
			_style_card(card, false, CARD_TEXT)
		else:
			card.text = spell.slots[i].role
			_style_card(card, i == active_slot, CARD_EMPTY_TEXT)

	var box: VBoxContainer = _ex.choices_box
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

	if pos >= order.size():
		var prefix := feedback_label.text
		_exercise_complete(("%s\n" % prefix if prefix != "" else "") + "Spell built!  %s" % spell.sentence_es)
		return

	var slot: Dictionary = spell.slots[order[pos]]
	if spec.typed:
		_add_build_typed_input(box, slot)
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		for option in _choice_options(spell, order[pos], spec.choices):
			var b := Button.new()
			b.text = option
			b.custom_minimum_size = Vector2(230, 64)
			_style_choice(b)
			b.pressed.connect(_on_build_choice_pressed.bind(b))
			row.add_child(b)
		box.add_child(row)

func _add_build_typed_input(box: VBoxContainer, slot: Dictionary) -> void:
	var hint := Label.new()
	hint.text = "Type the Spanish for the highlighted slot  (%s: \"%s\")" % [slot.role, slot.en]
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var edit := _add_type_row(box, _on_build_typed_submitted)
	edit.placeholder_text = "Spanish word"

func _on_build_card_pressed(slot_i: int) -> void:
	if _ex.get("kind", "") != "build" or _ex.complete:
		return
	var order: Array = _ex.spec.order
	var p := order.find(slot_i)
	if p == -1 or _ex.placed[slot_i] == "":
		return
	# Later choices depend on earlier ones, so undoing one clears the rest.
	for k in range(p, order.size()):
		_ex.placed[order[k]] = ""
	_ex.pos = p
	_ex.tries = 0
	_set_feedback("")
	StudySession.log_event("lesson_undo", {"spell_id": _spell_id})
	_render_build()

func _on_build_choice_pressed(button: Button) -> void:
	if _ex.get("kind", "") != "build" or _ex.complete:
		return
	var slot: Dictionary = _current_build_slot()
	if button.text == slot.es:
		_set_feedback("")
		_place_build(slot, true)
	else:
		_ex.tries += 1
		_mark_wrong(button)
		_mistake(slot.word_id)
		_set_feedback("Not quite - try another.", WRONG_COLOR)

func _on_build_typed_submitted(text: String, edit: LineEdit) -> void:
	if _ex.get("kind", "") != "build" or _ex.complete:
		return
	var slot: Dictionary = _current_build_slot()
	var result := TextGrader.grade(text, [slot.es], true, slot.es.length() >= 5)
	if result.correct:
		_set_feedback(_nudge_text(result), RIGHT_COLOR)
		_place_build(slot, true)
		return
	_ex.tries += 1
	_mistake(slot.word_id)
	if _ex.tries >= MAX_TYPED_TRIES:
		_set_feedback("It was \"%s\"." % slot.es, WRONG_COLOR)
		_place_build(slot, false)
	else:
		_set_feedback("Not quite - try again.", WRONG_COLOR)
		edit.clear()
		edit.grab_focus()

func _current_build_slot() -> Dictionary:
	var spell := SpellBank.get_spell(_spell_id)
	var slot: Dictionary = spell.slots[_ex.spec.order[_ex.pos]]
	return slot

## Fills the active slot. `credit` is false when the answer was revealed.
func _place_build(slot: Dictionary, credit: bool) -> void:
	if credit and _ex.tries == 0:
		PlayerProfile.record_correct(slot.word_id, false)
	var slot_i: int = _ex.spec.order[_ex.pos]
	_ex.placed[slot_i] = slot.es
	_ex.pos += 1
	_ex.tries = 0
	_render_build()

# --- Translate exercises ---------------------------------------------------

func _setup_translate_tiles() -> void:
	var spell := SpellBank.get_spell(_spell_id)
	prompt_label.text = "Translate into English"
	guide_label.text = spell.sentence_es
	for slot in spell.slots:
		PlayerProfile.record_seen(slot.word_id)

	var words: Array = Array(spell.sentence_en.split(" "))
	var lowered: Array = words.map(func(w): return w.to_lower())
	var decoys: Array = []
	for id in SpellBank.all_ids():
		if id == _spell_id:
			continue
		for w in SpellBank.get_spell(id).sentence_en.split(" "):
			if not lowered.has(w.to_lower()) and not decoys.has(w):
				decoys.append(w)
	decoys.shuffle()
	var tiles: Array = words.duplicate()
	tiles.append_array(decoys.slice(0, 3))
	tiles.shuffle()

	var answer_row := HBoxContainer.new()
	answer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	answer_row.custom_minimum_size = Vector2(0, 64)
	answer_row.add_theme_constant_override("separation", 10)
	content.add_child(answer_row)

	var bank := HBoxContainer.new()
	bank.alignment = BoxContainer.ALIGNMENT_CENTER
	bank.add_theme_constant_override("separation", 10)
	content.add_child(bank)
	for word in tiles:
		var tile := Button.new()
		tile.text = word
		tile.custom_minimum_size = Vector2(90, 52)
		_style_choice(tile)
		tile.pressed.connect(_on_tile_pressed.bind(tile))
		bank.add_child(tile)

	var check := Button.new()
	check.text = "Check"
	check.custom_minimum_size = Vector2(160, 48)
	check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	check.pressed.connect(_on_tiles_check)
	content.add_child(check)

	_ex = {
		"kind": "tiles", "answer_row": answer_row, "bank": bank, "check": check,
		"placed": [], "wrong_checks": 0, "complete": false,
	}

func _on_tile_pressed(tile: Button) -> void:
	if _ex.get("kind", "") != "tiles" or _ex.complete:
		return
	tile.disabled = true
	var placed := Button.new()
	placed.text = tile.text
	placed.custom_minimum_size = Vector2(90, 52)
	_style_choice(placed)
	placed.pressed.connect(_on_placed_tile_pressed.bind(placed, tile))
	_ex.answer_row.add_child(placed)
	_ex.placed.append(placed)

func _on_placed_tile_pressed(placed: Button, tile: Button) -> void:
	if _ex.get("kind", "") != "tiles" or _ex.complete:
		return
	tile.disabled = false
	_ex.placed.erase(placed)
	_ex.answer_row.remove_child(placed)
	placed.queue_free()

func _on_tiles_check() -> void:
	if _ex.get("kind", "") != "tiles" or _ex.complete:
		return
	var spell := SpellBank.get_spell(_spell_id)
	var built := " ".join(_ex.placed.map(func(b): return b.text))
	if TextGrader.grade(built, spell.accepted_en, false, false).correct:
		_credit_sentence(spell)
		_exercise_complete("Correct!  %s" % spell.sentence_en)
		return
	_ex.wrong_checks += 1
	_mistake("")
	if _ex.wrong_checks >= MAX_TILE_CHECKS:
		_exercise_complete("The sentence is: %s" % spell.sentence_en)
		_set_feedback("The sentence is: %s" % spell.sentence_en, WRONG_COLOR)
	else:
		_set_feedback("Not quite - rearrange the words and check again.", WRONG_COLOR)

func _setup_translate_type(spec: Dictionary) -> void:
	var spell := SpellBank.get_spell(_spell_id)
	var lang: String = spec.lang
	if lang == "en":
		prompt_label.text = "Translate into English"
		guide_label.text = spell.sentence_es
	else:
		prompt_label.text = "Translate into Spanish"
		guide_label.text = spell.sentence_en
	for slot in spell.slots:
		PlayerProfile.record_seen(slot.word_id)
	_ex = {"kind": "type", "lang": lang, "tries": 0, "complete": false}
	var edit := _add_type_row(content, _on_translate_submitted)
	edit.placeholder_text = "Type your translation"

func _on_translate_submitted(text: String, edit: LineEdit) -> void:
	if _ex.get("kind", "") != "type" or _ex.complete:
		return
	var spell := SpellBank.get_spell(_spell_id)
	var spanish: bool = _ex.lang == "es"
	var accepted: Array = spell.accepted_es if spanish else spell.accepted_en
	var result := TextGrader.grade(text, accepted, spanish, true)
	if result.correct:
		if _ex.tries == 0:
			_credit_sentence(spell)
		_exercise_complete(_nudge_text(result) if result.nudge != "" else "Correct!")
		return
	_ex.tries += 1
	_mistake("")
	if _ex.tries >= MAX_TYPED_TRIES:
		_exercise_complete("")
		_set_feedback("The answer is: %s" % accepted[0], WRONG_COLOR)
	else:
		_set_feedback("Not quite - try again.", WRONG_COLOR)
		edit.clear()
		edit.grab_focus()

func _credit_sentence(spell: Dictionary) -> void:
	for slot in spell.slots:
		PlayerProfile.record_correct(slot.word_id, false)

func _nudge_text(result: Dictionary) -> String:
	if result.nudge == "":
		return ""
	return "Correct - watch the spelling: %s" % result.nudge

# --- Choice exercises: quiz / fill-in-the-blank / listen-and-pick -----------

func _setup_choice(spec: Dictionary) -> void:
	var spell := SpellBank.get_spell(_spell_id)
	var slot_i: int = spec.slot
	var slot: Dictionary = spell.slots[slot_i]
	PlayerProfile.record_seen(slot.word_id)
	_ex = {"kind": spec.kind, "slot_i": slot_i, "tries": 0, "complete": false}

	match spec.kind:
		"quiz":
			prompt_label.text = "What is this in Spanish?"
			guide_label.text = "\"%s\"" % slot.en
		"fill_blank":
			prompt_label.text = "Fill in the blank"
			var parts: Array = []
			for i in spell.slots.size():
				parts.append("_____" if i == slot_i else spell.slots[i].es)
			guide_label.text = "%s\n(%s)" % [" ".join(parts), spell.sentence_en]
		"listen_pick":
			prompt_label.text = "Which word did you hear?"
			guide_label.text = ""
			var play := Button.new()
			play.text = "Play again"
			play.custom_minimum_size = Vector2(160, 48)
			play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			play.pressed.connect(_play_slot_audio.bind(slot.es))
			content.add_child(play)
			_play_slot_audio(slot.es)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	for option in _choice_options(spell, slot_i, spec.get("choices", 3)):
		var b := Button.new()
		b.text = option
		b.custom_minimum_size = Vector2(230, 64)
		_style_choice(b)
		b.pressed.connect(_on_choice_pressed.bind(b))
		row.add_child(b)
	content.add_child(row)

func _on_choice_pressed(button: Button) -> void:
	if not _ex.has("slot_i") or _ex.complete:
		return
	var spell := SpellBank.get_spell(_spell_id)
	var slot: Dictionary = spell.slots[_ex.slot_i]
	if button.text == slot.es:
		if _ex.tries == 0:
			PlayerProfile.record_correct(slot.word_id, false)
		_exercise_complete("Correct!  %s = %s" % [slot.es, slot.en])
	else:
		_ex.tries += 1
		_mark_wrong(button)
		_mistake(slot.word_id)
		_set_feedback("Not quite - try another.", WRONG_COLOR)

func _play_slot_audio(spanish: String) -> void:
	var path := LessonPlan.audio_path(spanish)
	if path != "":
		audio_player.stream = load(path)
		audio_player.play()

# --- Shared helpers --------------------------------------------------------

## The correct answer plus the slot's own distractors, topped up from other
## spells' words in the same role (and EXTRA_DISTRACTORS) up to `count`.
func _choice_options(spell: Dictionary, slot_i: int, count: int) -> Array:
	var slot: Dictionary = spell.slots[slot_i]
	var options: Array = [slot.es]
	for d in slot.distractors:
		if not options.has(d.es):
			options.append(d.es)
	if options.size() < count:
		var pool: Array = []
		for id in SpellBank.all_ids():
			for other in SpellBank.get_spell(id).slots:
				if other.role == slot.role and not options.has(other.es) and not pool.has(other.es):
					pool.append(other.es)
		for extra in SpellBank.EXTRA_DISTRACTORS.get(slot.role, []):
			if not options.has(extra.es) and not pool.has(extra.es):
				pool.append(extra.es)
		pool.shuffle()
		while options.size() < count and not pool.is_empty():
			options.append(pool.pop_back())
	options.shuffle()
	return options

## A LineEdit + Check button row; Enter or the button submit through `handler`
## (signature: text, edit).
func _add_type_row(parent: Control, handler: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(420, 48)
	edit.add_theme_font_size_override("font_size", 20)
	edit.text_submitted.connect(func(text: String): handler.call(text, edit))
	var submit := Button.new()
	submit.text = "Check"
	submit.custom_minimum_size = Vector2(120, 48)
	submit.pressed.connect(func(): handler.call(edit.text, edit))
	row.add_child(edit)
	row.add_child(submit)
	parent.add_child(row)
	edit.grab_focus()
	return edit

func _set_feedback(text: String, color: Color = Color.WHITE) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", color)

func _clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _stylebox(color: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_width)
	sb.border_color = border
	sb.set_content_margin_all(10)
	return sb

func _apply_button_style(button: Button, normal: StyleBoxFlat, disabled: StyleBoxFlat, text_color: Color, disabled_text: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", disabled)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, text_color)
	button.add_theme_color_override("font_disabled_color", disabled_text)
	button.add_theme_font_size_override("font_size", 22)

func _style_card(button: Button, active: bool, text_color: Color) -> void:
	var border := CARD_ACTIVE if active else Color(0, 0, 0, 0)
	var normal := _stylebox(Color.WHITE, 18, border, 5 if active else 0)
	_apply_button_style(button, normal, normal, text_color, text_color)

func _style_choice(button: Button) -> void:
	var normal := _stylebox(CHOICE_COLOR, 12)
	var disabled := _stylebox(CHOICE_COLOR.darkened(0.45), 12)
	_apply_button_style(button, normal, disabled, Color.WHITE, Color(1, 1, 1, 0.45))

func _mark_wrong(button: Button) -> void:
	var red := _stylebox(WRONG_COLOR, 12)
	button.add_theme_stylebox_override("disabled", red)
	button.add_theme_color_override("font_disabled_color", Color.WHITE)
	button.disabled = true
