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
const MAX_TYPED_TRIES := 3   # the third miss reveals the answer
const HINT_COLOR := Color(0.95, 0.8, 0.45)
const HintLadder := preload("res://scripts/lesson/hint_ladder.gd")
const Distractors := preload("res://scripts/lesson/distractors.gd")
## Physical key -> option index, so 1-9 pick the first nine options and 0 the tenth.
const DIGIT_KEYS := {
	KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4,
	KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9,
}

const Fx := preload("res://scripts/ui/fx.gd")
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
@onready var keys_hint: Label = $Overlay/KeysHint

var _spell_id := ""
var _mode := ""
var _required := false
var _plan: Array = []
var _step := 0
var _lesson_mistakes := 0
var _ex_started_msec := 0
var _exercise_mistakes := 0
var _tier_up_name := ""
var _rng := RandomNumberGenerator.new()
## State of the exercise currently on screen.
var _ex: Dictionary = {}
## Option buttons on screen that number keys can press, in display order.
var _hotkeys: Array = []

func _ready() -> void:
	_rng.randomize()
	quit_button.pressed.connect(_abandon)
	continue_button.pressed.connect(_on_continue)
	SpellProgress.tier_up.connect(_on_tier_up)
	Spellbook.practice_requested.connect(start_practice)

# --- Entry points ----------------------------------------------------------

## `required` lessons hide the Quit button, so guaranteed spells can't be
## skipped; optional ones can be quit and retried later.
func start_learn(spell_id: String, required: bool = false) -> void:
	if SpellProgress.knows(spell_id):
		return
	_begin(spell_id, "learn", required)

func start_practice(spell_id: String) -> void:
	if not SpellProgress.knows(spell_id):
		return
	_begin(spell_id, "practice", false)

func _begin(spell_id: String, mode: String, required: bool) -> void:
	if is_open or not SpellBank.has_spell(spell_id):
		return
	_spell_id = spell_id
	_mode = mode
	_required = required
	quit_button.visible = not required
	var tier := SpellProgress.tier_index(spell_id) if mode == "practice" else 0
	_plan = LessonPlan.build_plan(spell_id, mode, tier, _rng)
	_step = 0
	_lesson_mistakes = 0
	_tier_up_name = ""
	is_open = true
	Fx.fade_in(overlay)

	var spell := SpellBank.get_spell(spell_id)
	if mode == "learn":
		title_label.text = "Learning: %s" % spell.name_es
	else:
		title_label.text = "Practice: %s  (%s)" % [spell.name_es, SpellProgress.tier_name(spell_id)]
	StudySession.log_event("lesson_started", {
		"spell_id": spell_id, "mode": mode, "tier": tier, "required": required,
	})
	_run_exercise()

# --- Flow ------------------------------------------------------------------

func _run_exercise() -> void:
	_clear_content()
	_ex = {}
	_hotkeys = []
	_exercise_mistakes = 0
	_ex_started_msec = Time.get_ticks_msec()
	continue_button.visible = false
	_set_feedback("")
	step_label.text = "Step %d / %d" % [_step + 1, _plan.size()]

	var spec: Dictionary = _plan[_step]
	if spec.kind in ["quiz", "fill_blank"]:
		spec.slot = _weighted_slot(SpellBank.get_spell(_spell_id))
	var typed: bool = spec.kind == "translate_type" or (spec.kind == "build" and spec.typed)
	keys_hint.text = "Type your answer, then press Enter" if typed \
		else "Number keys pick an option  -  Backspace undoes  -  Enter checks / continues"
	match spec.kind:
		"translate_tiles": _setup_translate_tiles()
		"translate_type": _setup_translate_type(spec)
		"build": _setup_build(spec)
		"quiz", "fill_blank", "listen_pick": _setup_choice(spec)
		"tile_reorder": _setup_tile_reorder()
		"contrast_pair": _setup_contrast_pair()

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
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit:
		focused.release_focus()
	_set_feedback(message, RIGHT_COLOR)
	continue_button.text = ("Continue" if _step + 1 < _plan.size() else "Finish") + "  [Enter]"
	continue_button.visible = true
	StudySession.log_event("lesson_exercise_done", {
		"spell_id": _spell_id, "kind": _ex.kind, "mistakes": _exercise_mistakes,
	})

func _finish() -> void:
	_clear_content()
	_hotkeys = []
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
	if _mode == "learn":
		Praise.celebrate("Spell learned!")
	elif _tier_up_name != "":
		Praise.celebrate("%s!" % _tier_up_name)
	elif _lesson_mistakes == 0:
		Praise.celebrate("Flawless!")
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
	Fx.fade_out(overlay)
	audio_player.stop()
	_clear_content()
	_hotkeys = []
	if completed:
		lesson_finished.emit(_spell_id, _mode)

func _on_tier_up(_spell_id_arg: String, tier_name: String) -> void:
	_tier_up_name = tier_name

func _mistake(word_id: String, chosen: String = "") -> void:
	_lesson_mistakes += 1
	_exercise_mistakes += 1
	PlayerProfile.record_error(word_id, chosen)
	Praise.wrong()
	StudySession.log_event("lesson_wrong", {
		"spell_id": _spell_id, "kind": _ex.get("kind", ""), "word_id": word_id,
		"latency_ms": Time.get_ticks_msec() - _ex_started_msec,
	})

func _log_hints(rungs: Array, word_id: String) -> void:
	for rung in rungs:
		StudySession.log_event("lesson_hint", {
			"spell_id": _spell_id, "kind": _ex.get("kind", ""), "word_id": word_id, "rung": rung,
		})

## Slot to quiz: random, but weighted toward words the player has missed.
func _weighted_slot(spell: Dictionary) -> int:
	var weights: Array = []
	var total := 0.0
	for slot in spell.slots:
		var w: float = 1.0 + 2.0 * PlayerProfile.weakness(slot.word_id)
		weights.append(w)
		total += w
	var roll := _rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1

## After a wrong pick among choices: the next rung of the ladder. The second
## rung also takes one remaining wrong option away.
func _choice_hint(spell: Dictionary, slot_i: int, miss: int) -> void:
	var slot: Dictionary = spell.slots[slot_i]
	var h := HintLadder.slot_hint(spell, slot_i, miss, false)
	var text: String = "Not quite. " + h.text
	if "drop_option" in h.rungs:
		var wrong: Array = _hotkeys.filter(func(b): return is_instance_valid(b) and not b.disabled and b.text != slot.es)
		if wrong.size() >= 2:
			var drop: Button = wrong[_rng.randi_range(0, wrong.size() - 1)]
			drop.disabled = true
			text += "   (One wrong option is gone.)"
	_log_hints(h.rungs, slot.word_id)
	_set_feedback(text, HINT_COLOR)

## One line about the word-order rule, but only from the second miss of it.
func _order_note(spell: Dictionary) -> String:
	var pattern: String = spell.get("order_pattern", "")
	if pattern == "":
		return ""
	var count := PlayerProfile.record_pattern_miss(pattern)
	return "
" + SpellBank.WORD_ORDER_NOTES[pattern] if count >= 2 else ""

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
	_hotkeys = []
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
			_register_hotkey(b)
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
		_set_feedback("You worked it out!" if _ex.tries > 0 else "", RIGHT_COLOR)
		_place_build(slot, true)
	else:
		_ex.tries += 1
		_mark_wrong(button)
		_mistake(slot.word_id, button.text)
		_choice_hint(SpellBank.get_spell(_spell_id), _ex.spec.order[_ex.pos], _ex.tries - 1)

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
	_mistake(slot.word_id, text)
	if _ex.tries >= MAX_TYPED_TRIES:
		_set_feedback("It was \"%s\" - you'll get it next time." % slot.es, HINT_COLOR)
		_place_build(slot, false)
	else:
		var h := HintLadder.slot_hint(SpellBank.get_spell(_spell_id), _ex.spec.order[_ex.pos], _ex.tries - 1, true)
		_log_hints(h.rungs, slot.word_id)
		_set_feedback("Not quite. " + h.text, HINT_COLOR)
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
		Praise.correct()
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

	_tile_ui(tiles, "en")

func _tile_ui(tiles: Array, mode: String) -> void:
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
		_register_hotkey(tile)

	var check := Button.new()
	check.text = "Check"
	check.custom_minimum_size = Vector2(160, 48)
	check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	check.pressed.connect(_on_tiles_check)
	content.add_child(check)

	_ex = {
		"kind": "tiles", "mode": mode, "answer_row": answer_row, "bank": bank, "check": check,
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
	var reorder: bool = _ex.mode == "es_order"
	var target: String = spell.sentence_es if reorder else spell.accepted_en[0]
	var ok: bool = built.to_lower() == target.to_lower() if reorder \
		else TextGrader.grade(built, spell.accepted_en, false, false).correct
	if ok:
		if _ex.wrong_checks == 0:
			_credit_sentence(spell)
			Praise.correct()
		_exercise_complete(("Correct!  %s" if _ex.wrong_checks == 0 else "You worked it out!  %s") % target)
		return
	_ex.wrong_checks += 1
	_mistake("", built)
	var note: String = _order_note(spell) if reorder else ""
	if _ex.wrong_checks >= MAX_TILE_CHECKS:
		_exercise_complete("")
		_set_feedback("The sentence is: %s%s" % [target, note], HINT_COLOR)
	else:
		var cue := HintLadder.sentence_cue(target, _ex.wrong_checks - 1)
		_log_hints(["sentence_cue"], "")
		_set_feedback("Not quite - rearrange and check again. %s%s" % [cue, note], HINT_COLOR)

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
			Praise.correct()
		_exercise_complete(_nudge_text(result) if result.nudge != "" else ("Correct!" if _ex.tries == 0 else "You worked it out!"))
		return
	_ex.tries += 1
	_mistake("", text)
	if _ex.tries >= MAX_TYPED_TRIES:
		_exercise_complete("")
		_set_feedback("The answer is: %s" % accepted[0], HINT_COLOR)
	else:
		_log_hints(["sentence_cue"], "")
		_set_feedback("Not quite. %s" % HintLadder.sentence_cue(accepted[0], _ex.tries - 1), HINT_COLOR)
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
		_register_hotkey(b)
	content.add_child(row)

func _on_choice_pressed(button: Button) -> void:
	if not _ex.has("slot_i") or _ex.complete:
		return
	var spell := SpellBank.get_spell(_spell_id)
	var slot: Dictionary = spell.slots[_ex.slot_i]
	if button.text == slot.es:
		if _ex.tries == 0:
			PlayerProfile.record_correct(slot.word_id, false)
			Praise.correct()
		_exercise_complete("%s  %s = %s" % ["Correct!" if _ex.tries == 0 else "You worked it out!", slot.es, slot.en])
	else:
		_ex.tries += 1
		_mark_wrong(button)
		_mistake(slot.word_id, button.text)
		_choice_hint(spell, _ex.slot_i, _ex.tries - 1)

func _play_slot_audio(spanish: String) -> void:
	var path := LessonPlan.audio_path(spanish)
	if path != "":
		audio_player.stream = load(path)
		audio_player.play()

# --- Word-order exercises ------------------------------------------------------

func _setup_tile_reorder() -> void:
	var spell := SpellBank.get_spell(_spell_id)
	prompt_label.text = "Put the words in order"
	guide_label.text = spell.sentence_en
	for slot in spell.slots:
		PlayerProfile.record_seen(slot.word_id)
	var words: Array = Array(spell.sentence_es.split(" "))
	var tiles: Array = words.duplicate()
	for attempt in 20:
		tiles.shuffle()
		if tiles != words:
			break
	_tile_ui(tiles, "es_order")

func _setup_contrast_pair() -> void:
	var spell := SpellBank.get_spell(_spell_id)
	prompt_label.text = "Which sentence is correct?"
	guide_label.text = spell.sentence_en
	for slot in spell.slots:
		PlayerProfile.record_seen(slot.word_id)
	_ex = {"kind": "contrast", "tries": 0, "complete": false}
	var options: Array = [spell.sentence_es, spell.order_foil]
	options.shuffle()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	for option in options:
		var b := Button.new()
		b.text = option
		b.custom_minimum_size = Vector2(340, 64)
		_style_choice(b)
		b.pressed.connect(_on_contrast_pressed.bind(b))
		row.add_child(b)
		_register_hotkey(b)
	content.add_child(row)

func _on_contrast_pressed(button: Button) -> void:
	if _ex.get("kind", "") != "contrast" or _ex.complete:
		return
	var spell := SpellBank.get_spell(_spell_id)
	if button.text == spell.sentence_es:
		if _ex.tries == 0:
			for slot in spell.slots:
				PlayerProfile.record_correct(slot.word_id, false)
			Praise.correct()
		_exercise_complete("%s  %s" % ["Correct!" if _ex.tries == 0 else "You worked it out!", spell.sentence_es])
		return
	_ex.tries += 1
	_mark_wrong(button)
	_mistake("", button.text)
	_set_feedback("Not quite - look at where each word goes.%s" % _order_note(spell), HINT_COLOR)

# --- Keyboard ----------------------------------------------------------------

## Registers `button` as the next number-key option and draws its number in
## the top-left corner (1-9, then 0 for the tenth).
func _register_hotkey(button: Button) -> void:
	_hotkeys.append(button)
	if _hotkeys.size() > DIGIT_KEYS.size():
		return
	var badge := Label.new()
	badge.text = str(_hotkeys.size() % 10)
	badge.position = Vector2(9, 3)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	button.add_child(badge)

func _input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey and event.pressed and not event.echo):
		return
	# While typing an answer the keys belong to the text box.
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var key: int = event.physical_keycode
	if DIGIT_KEYS.has(key):
		var i: int = DIGIT_KEYS[key]
		if i < _hotkeys.size() and is_instance_valid(_hotkeys[i]) and not _hotkeys[i].disabled:
			_hotkeys[i].pressed.emit()
		get_viewport().set_input_as_handled()
	elif key == KEY_BACKSPACE:
		_keyboard_undo()
		get_viewport().set_input_as_handled()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		_keyboard_confirm()
		get_viewport().set_input_as_handled()

func _keyboard_undo() -> void:
	if _ex.get("complete", true):
		return
	match _ex.get("kind", ""):
		"build":
			if _ex.pos > 0:
				_on_build_card_pressed(_ex.spec.order[_ex.pos - 1])
		"tiles":
			if not _ex.placed.is_empty():
				_ex.placed.back().pressed.emit()

func _keyboard_confirm() -> void:
	if continue_button.visible:
		continue_button.pressed.emit()
	elif _ex.get("kind", "") == "tiles" and not _ex.complete:
		_on_tiles_check()

# --- Shared helpers --------------------------------------------------------

## The correct answer plus wrong options chosen by Distractors (this player's
## past confusions first), `count` options in all, shuffled.
func _choice_options(spell: Dictionary, slot_i: int, count: int) -> Array:
	var slot: Dictionary = spell.slots[slot_i]
	var options: Array = [slot.es]
	for d in Distractors.wrong_options(slot, count, _rng):
		options.append(d.es)
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
	feedback_label.add_theme_color_override("font_color", color)
	Fx.fade_text(feedback_label, text, 0.2)

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
