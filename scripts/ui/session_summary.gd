extends Control
## The end-of-session "your results" screen, shown after the surveys and the
## recall quiz (so it can't bias any answers). Deliberately all-positive:
## no red numbers, and a word to focus on is framed as a next step. The
## stats come from PlayerProfile, SpellProgress, Praise and the recall quiz
## result that RecallQuiz leaves on StudySession.
##
## Built in code so the stats cards are easy to add or reorder.

const Fx := preload("res://scripts/ui/fx.gd")
const SpellIcons := preload("res://scripts/ui/spell_icons.gd")
const NEXT_SCENE := "res://scenes/ui/ThankYou.tscn"
const MIN_ANSWERS_FOR_ACCURACY := 5
const GOLD := Color(1.0, 0.85, 0.3)

var _cards: Array = []

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	root.add_child(_label("Your results", 40, GOLD, true))
	root.add_child(_label(_headline(), 20, Color(1, 1, 1, 0.85), true))

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 18)
	root.add_child(stats)
	for stat in _stats():
		var card := _stat_card(stat.value, stat.caption)
		stats.add_child(card)
		_cards.append(card)

	var spells := _spell_cards()
	if not spells.get_child_count() == 0:
		root.add_child(_label("Your spells", 16, Color(1, 1, 1, 0.6), true))
		root.add_child(spells)

	var focus := _focus_line()
	if focus != "":
		root.add_child(_label(focus, 17, Color(0.75, 0.9, 1.0), true))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)
	root.add_child(_return_panel())

	var button := Button.new()
	button.text = "Continue  [Enter]"
	button.custom_minimum_size = Vector2(240, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_continue)
	root.add_child(button)
	button.grab_focus()

	StudySession.log_event("summary_shown", {
		"words": _words_met(), "best_streak": Praise.best, "accuracy": _accuracy(),
	})
	_reveal()
	Praise.celebrate("Great work!", false)

# --- Content -------------------------------------------------------------------------

func _words_met() -> int:
	return WordBank.all_word_ids().filter(func(id): return PlayerProfile.has_seen(id)).size()

func _accuracy() -> int:
	var total: int = Praise.total_correct + Praise.total_wrong
	return -1 if total < MIN_ANSWERS_FOR_ACCURACY else int(round(100.0 * Praise.total_correct / total))

func _headline() -> String:
	if StudySession.visit_number > 1:
		return "Welcome back, and thank you for coming back. Here is how this session went."
	return "You played through the whole adventure. Here is what you achieved."

func _stats() -> Array:
	var out: Array = [{"value": str(_words_met()), "caption": "Spanish words met"}]
	if StudySession.last_recall_total > 0:
		out.append({
			"value": "%d / %d" % [StudySession.last_recall_correct, StudySession.last_recall_total],
			"caption": "words remembered in the quiz",
		})
	out.append({"value": str(Praise.best), "caption": "best streak in a row"})
	var accuracy := _accuracy()
	if accuracy >= 0:
		out.append({"value": "%d%%" % accuracy, "caption": "right on the first try"})
	return out

func _spell_cards() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var progress := SpellProgress.snapshot()
	for id in SpellBank.all_ids():
		if not progress.has(id):
			continue
		var color := SpellBank.type_color(id)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(150, 0)
		panel.add_theme_stylebox_override("panel", _box(color.darkened(0.6), 14))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		var tex := SpellIcons.get_icon(id)
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.custom_minimum_size = Vector2(44, 44)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			if SpellIcons.is_line_art(id):
				icon.modulate = color.lightened(0.25)
			col.add_child(icon)
		var name_label := _label(SpellBank.get_spell(id).name_es, 14, Color.WHITE, true)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var tier_label := _label(progress[id].tier, 13, GOLD, true)
		tier_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		col.add_child(name_label)
		col.add_child(tier_label)
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 10)
		margin.add_child(col)
		panel.add_child(margin)
		row.add_child(panel)
		_cards.append(panel)
	return row

## One positively framed word to focus on next time (the most-missed one).
func _focus_line() -> String:
	var worst := ""
	var worst_errors := 0
	for id in WordBank.all_word_ids():
		var errors: int = PlayerProfile.get_stats(id).errors
		if errors > worst_errors:
			worst_errors = errors
			worst = id
	if worst == "" or worst_errors < 2:
		return ""
	var word: Dictionary = WordBank.get_word(worst)
	return "Next time, try to spot \"%s\" (%s): a little more practice and it's yours." % [word.spanish, word.english]

func _return_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.07), 14))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	margin.add_child(col)
	panel.add_child(margin)
	if StudySession.visit_number > 1:
		col.add_child(_label("Thank you for being part of this study!", 20, GOLD, true))
		return panel
	col.add_child(_label("Bring this code back in about a week for harder challenges:", 16, Color(1, 1, 1, 0.8), true))
	col.add_child(_label(StudySession.participant_code, 38, GOLD, true))
	return panel

# --- Widgets ---------------------------------------------------------------------------

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb

func _label(text: String, size: int, color: Color, centered: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _stat_card(value: String, caption: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 108)
	panel.add_theme_stylebox_override("panel", _box(Color(0.22, 0.36, 0.47), 18))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_label(value, 40, Color.WHITE, true))
	col.add_child(_label(caption, 15, Color(1, 1, 1, 0.8), true))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_child(col)
	panel.add_child(margin)
	return panel

## Cards pop in one after another.
func _reveal() -> void:
	for i in _cards.size():
		var card: Control = _cards[i]
		card.modulate.a = 0.0
		card.scale = Vector2(0.85, 0.85)
		var t := card.create_tween()
		t.tween_interval(0.15 * i)
		t.tween_callback(func(): card.pivot_offset = card.size / 2.0)
		t.tween_property(card, "modulate:a", 1.0, 0.25)
		t.parallel().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_continue() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_on_continue()
