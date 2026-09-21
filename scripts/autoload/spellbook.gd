extends CanvasLayer
## The spellbook: a HUD hint/button shown during exploration, and a
## two-page overlay (spell list on the left, details on the right) opened
## with B or by clicking the HUD button. Only opens in scenes in the
## "gameplay_scene" group and never over a dialogue.
##
## Practice lessons don't exist yet -- the Practice button emits
## practice_requested so the lesson builder can hook in later. The [DEV]
## buttons only appear in debug builds (editor runs), not exported ones.

signal practice_requested(spell_id: String)

var is_open := false

var _selected := ""

@onready var hud_button: Button = $HudButton
@onready var overlay: Control = $Overlay
@onready var close_button: Button = $Overlay/Book/CloseButton
@onready var spell_list: VBoxContainer = $Overlay/Book/LeftPage/SpellList
@onready var name_label: Label = $Overlay/Book/RightPage/NameLabel
@onready var type_label: Label = $Overlay/Book/RightPage/TypeLabel
@onready var sentence_es_label: Label = $Overlay/Book/RightPage/SentenceEs
@onready var sentence_en_label: Label = $Overlay/Book/RightPage/SentenceEn
@onready var stats_label: Label = $Overlay/Book/RightPage/StatsLabel
@onready var tier_label: Label = $Overlay/Book/RightPage/TierLabel
@onready var tier_bar: ProgressBar = $Overlay/Book/RightPage/TierBar
@onready var practice_button: Button = $Overlay/Book/RightPage/PracticeButton
@onready var practice_note: Label = $Overlay/Book/RightPage/PracticeNote
@onready var dev_row: HBoxContainer = $Overlay/Book/RightPage/DevRow
@onready var dev_practice_button: Button = $Overlay/Book/RightPage/DevRow/DevPracticeButton
@onready var dev_learn_all_button: Button = $Overlay/Book/RightPage/DevRow/DevLearnAllButton
@onready var dev_lesson_button: Button = $Overlay/Book/RightPage/DevRow/DevLessonButton

func _ready() -> void:
	overlay.visible = false
	hud_button.visible = false
	dev_row.visible = OS.is_debug_build()
	hud_button.pressed.connect(toggle)
	close_button.pressed.connect(close)
	practice_button.pressed.connect(_on_practice_pressed)
	dev_practice_button.pressed.connect(_on_dev_practice_pressed)
	dev_learn_all_button.pressed.connect(_on_dev_learn_all_pressed)
	dev_lesson_button.pressed.connect(_on_dev_lesson_pressed)
	SpellProgress.spells_changed.connect(_on_spells_changed)

func _process(_delta: float) -> void:
	hud_button.visible = _in_gameplay_scene()

func _input(event: InputEvent) -> void:
	if Lesson.is_open:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_B:
		toggle()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE and is_open:
		close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	elif _can_open():
		open()

func open() -> void:
	is_open = true
	overlay.visible = true
	StudySession.log_event("spellbook_opened")
	_refresh()

func close() -> void:
	is_open = false
	overlay.visible = false
	StudySession.log_event("spellbook_closed")

func _in_gameplay_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.is_in_group("gameplay_scene")

func _can_open() -> bool:
	return _in_gameplay_scene() and not Dialogue.is_open

func _on_spells_changed() -> void:
	if is_open:
		_refresh()

func _refresh() -> void:
	for child in spell_list.get_children():
		child.queue_free()

	var known := SpellProgress.known_ids()
	if _selected == "" or not SpellProgress.knows(_selected):
		_selected = known[0] if known.size() > 0 else ""

	for id in SpellBank.all_ids():
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if SpellProgress.knows(id):
			b.text = "  " + SpellBank.get_spell(id).sentence_es
			b.add_theme_color_override("font_color", SpellBank.type_color(id))
			b.pressed.connect(_select.bind(id))
		else:
			b.text = "  ???"
			b.disabled = true
		spell_list.add_child(b)

	_show_details(_selected)

func _select(spell_id: String) -> void:
	_selected = spell_id
	practice_note.text = ""
	_show_details(spell_id)

func _show_details(spell_id: String) -> void:
	var has_spell := spell_id != ""
	for node in [name_label, type_label, sentence_es_label, sentence_en_label,
			stats_label, tier_label, tier_bar, practice_button]:
		node.visible = has_spell
	dev_practice_button.disabled = not has_spell
	if not has_spell:
		practice_note.text = "You haven't learned any spells yet."
		return

	var spell := SpellBank.get_spell(spell_id)
	var color := SpellBank.type_color(spell_id)
	name_label.text = "%s  (%s)" % [spell.name_es, spell.name]
	type_label.text = "%s, %s  -  %s" % [
		SpellBank.TYPE_LABELS[spell.type], SpellBank.TARGET_LABELS[spell.target],
		SpellBank.effect_text(spell_id),
	]
	type_label.add_theme_color_override("font_color", color)
	sentence_es_label.text = spell.sentence_es
	sentence_en_label.text = spell.sentence_en

	var accuracies: Array = []
	for correct in range(SpellBank.STEP_BONUSES.size() + 1):
		accuracies.append("%d%%" % SpellProgress.accuracy_for_correct(spell_id, correct))
	stats_label.text = "Mana cost: %d\nAccuracy by correct answers (0 to 3): %s\nLoadout copies: %d" % [
		spell.mana_cost, "  ->  ".join(accuracies), SpellProgress.max_copies(spell_id),
	]
	if SpellBank.has_combined(spell_id):
		stats_label.text += "\nAfter Furia: %s" % spell.combined.sentence_es

	var count := SpellProgress.practice_count(spell_id)
	var next := SpellProgress.next_tier_threshold(spell_id)
	if next < 0:
		tier_label.text = "%s  (%d practices) - highest tier" % [SpellProgress.tier_name(spell_id), count]
		tier_bar.min_value = 0
		tier_bar.max_value = 1
		tier_bar.value = 1
	else:
		var tier_start: int = SpellBank.TIER_THRESHOLDS[SpellProgress.tier_index(spell_id)]
		tier_label.text = "%s  (%d / %d practices to %s)" % [
			SpellProgress.tier_name(spell_id), count, next,
			SpellBank.TIER_NAMES[SpellProgress.tier_index(spell_id) + 1],
		]
		tier_bar.min_value = tier_start
		tier_bar.max_value = next
		tier_bar.value = count

func _on_practice_pressed() -> void:
	if practice_requested.get_connections().is_empty():
		practice_note.text = "Practice lessons are coming soon."
	else:
		practice_requested.emit(_selected)

func _on_dev_practice_pressed() -> void:
	if _selected != "":
		SpellProgress.record_practice(_selected)

func _on_dev_learn_all_pressed() -> void:
	for id in SpellBank.all_ids():
		SpellProgress.learn_spell(id)

func _on_dev_lesson_pressed() -> void:
	for id in SpellBank.all_ids():
		if not SpellProgress.knows(id):
			Lesson.start_learn(id)
			return
