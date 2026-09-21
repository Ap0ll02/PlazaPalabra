extends CanvasLayer
## The spellbook: a HUD button shown during exploration, and a two-page
## overlay opened with B or the button. Left page = library of every spell
## you know (click one to copy it into your book). Right page = the book
## itself (SpellBank.BOOK_SLOTS slots; click a filled slot to remove that
## copy) and the details of whichever spell you're pointing at. The book is
## what you carry into fights. Only opens in scenes in the "gameplay_scene"
## group and never over a dialogue. The [DEV] buttons only appear in debug
## builds (editor runs), not exported ones.

signal practice_requested(spell_id: String)

const SpellIcons := preload("res://scripts/ui/spell_icons.gd")

const Fx := preload("res://scripts/ui/fx.gd")
var is_open := false

var _selected := ""

@onready var hud_button: Button = $HudButton
@onready var overlay: Control = $Overlay
@onready var close_button: Button = $Overlay/Book/CloseButton
@onready var spell_list: VBoxContainer = $Overlay/Book/LeftPage/SpellList
@onready var slot_grid: GridContainer = $Overlay/Book/RightPage/SlotGrid
@onready var book_header: Label = $Overlay/Book/RightPage/BookHeader
@onready var note_label: Label = $Overlay/Book/RightPage/NoteLabel
@onready var name_label: Label = $Overlay/Book/RightPage/NameLabel
@onready var type_label: Label = $Overlay/Book/RightPage/TypeLabel
@onready var sentence_es_label: Label = $Overlay/Book/RightPage/SentenceEs
@onready var sentence_en_label: Label = $Overlay/Book/RightPage/SentenceEn
@onready var stats_label: Label = $Overlay/Book/RightPage/StatsLabel
@onready var tier_label: Label = $Overlay/Book/RightPage/TierLabel
@onready var tier_bar: ProgressBar = $Overlay/Book/RightPage/TierBar
@onready var practice_button: Button = $Overlay/Book/RightPage/PracticeButton
@onready var dev_row: HBoxContainer = $Overlay/Book/DevRow
@onready var dev_practice_button: Button = $Overlay/Book/DevRow/DevPracticeButton
@onready var dev_learn_all_button: Button = $Overlay/Book/DevRow/DevLearnAllButton
@onready var dev_lesson_button: Button = $Overlay/Book/DevRow/DevLessonButton

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
	SpellProgress.book_changed.connect(_on_spells_changed)

func _process(_delta: float) -> void:
	hud_button.visible = _in_gameplay_scene()

func _input(event: InputEvent) -> void:
	if Lesson.is_open or Combat.is_open:
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
	Fx.fade_in(overlay)
	StudySession.log_event("spellbook_opened")
	_refresh()

## Opens the book (from anywhere, e.g. a fight that needs it filled) with a
## hint shown under the slots.
func open_with_note(note: String) -> void:
	if not is_open:
		open()
	note_label.text = note

func close() -> void:
	is_open = false
	Fx.fade_out(overlay)
	StudySession.log_event("spellbook_closed")

func _in_gameplay_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.is_in_group("gameplay_scene")

func _can_open() -> bool:
	return _in_gameplay_scene() and not Dialogue.is_open and not Combat.is_open

func _on_spells_changed() -> void:
	if is_open:
		_refresh()

func _refresh() -> void:
	for child in spell_list.get_children():
		child.queue_free()
	for child in slot_grid.get_children():
		child.queue_free()

	var known := SpellProgress.known_ids()
	if _selected == "" or not SpellProgress.knows(_selected):
		_selected = known[0] if known.size() > 0 else ""

	for id in SpellBank.all_ids():
		spell_list.add_child(_make_card(id))

	# One tile per slot: filled ones first (in library order), then empty.
	var filled: Array = []
	for id in known:
		for i in SpellProgress.book_copies(id):
			filled.append(id)
	for i in SpellBank.BOOK_SLOTS:
		slot_grid.add_child(_make_slot(filled[i] if i < filled.size() else ""))
	book_header.text = "Your spellbook  %d / %d  -  click a filled slot to remove it" % [
		SpellProgress.book_total(), SpellBank.BOOK_SLOTS]

	_show_details(_selected)

# --- Widgets -------------------------------------------------------------------

func _box(color: Color, radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb

func _style_button(b: Button, base: Color) -> void:
	b.add_theme_stylebox_override("normal", _box(base))
	b.add_theme_stylebox_override("hover", _box(base.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _box(base.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", _box(base.darkened(0.35)))
	b.add_theme_stylebox_override("focus", _box(Color(1, 1, 1, 0.0)))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _icon_tile(spell_id: String, tile_size: float) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(tile_size, tile_size)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := SpellBank.type_color(spell_id) if spell_id != "" else Color(0.5, 0.5, 0.5)
	panel.add_theme_stylebox_override("panel", _box(color.darkened(0.55), 10))
	if spell_id != "":
		var tex := SpellIcons.get_icon(spell_id)
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if SpellIcons.is_line_art(spell_id):
				rect.modulate = color.lightened(0.25)
			panel.add_child(rect)
	return panel

func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	return l

## A library entry: icon on the left, name / effect / mana + tier on the right.
func _make_card(id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 76)
	var known := SpellProgress.knows(id)
	_style_button(b, Color(0.22, 0.36, 0.47) if known else Color(0.2, 0.2, 0.24))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if not known:
		row.add_child(_icon_tile("", 60))
		row.add_child(_label("???  -  not learned yet", 16, Color(1, 1, 1, 0.45)))
		b.disabled = true
		return b
	var spell := SpellBank.get_spell(id)
	row.add_child(_icon_tile(id, 60))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_label(spell.name_es, 18))
	col.add_child(_label(SpellBank.effect_text(id), 13, Color(1, 1, 1, 0.85)))
	col.add_child(_label("%d mana  -  %s  -  in book %d / %d" % [
		spell.mana_cost, SpellProgress.tier_name(id),
		SpellProgress.book_copies(id), SpellProgress.copy_cap(id)], 13, Color(1, 1, 1, 0.65)))
	row.add_child(col)
	b.pressed.connect(_on_card_pressed.bind(id))
	b.mouse_entered.connect(_select.bind(id))
	b.focus_entered.connect(_select.bind(id))
	return b

## One spellbook slot: filled (click to remove) or an empty placeholder.
func _make_slot(id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(146, 78)
	if id == "":
		_style_button(b, Color(0.16, 0.17, 0.21))
		b.disabled = true
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW
		b.text = "empty"
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
		return b
	_style_button(b, Color(0.22, 0.36, 0.47))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	row.add_child(_icon_tile(id, 44))
	var name_label_s := _label(SpellBank.get_spell(id).name_es, 13)
	name_label_s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label_s.clip_text = false
	name_label_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label_s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label_s)
	b.pressed.connect(_on_slot_pressed.bind(id))
	b.mouse_entered.connect(_select.bind(id))
	return b

func _on_card_pressed(spell_id: String) -> void:
	_selected = spell_id
	var reason := SpellProgress.add_block_reason(spell_id)
	if reason != "":
		note_label.text = reason
		return
	SpellProgress.add_to_book(spell_id)
	note_label.text = ""

func _on_slot_pressed(spell_id: String) -> void:
	SpellProgress.remove_from_book(spell_id)
	note_label.text = ""

func _select(spell_id: String) -> void:
	if spell_id == _selected:
		return
	_selected = spell_id
	_show_details(spell_id)

func _show_details(spell_id: String) -> void:
	var has_spell := spell_id != ""
	for node in [name_label, type_label, sentence_es_label, sentence_en_label,
			stats_label, tier_label, tier_bar, practice_button]:
		node.visible = has_spell
	dev_practice_button.disabled = not has_spell
	if not has_spell:
		note_label.text = "You haven't learned any spells yet."
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
	stats_label.text = "Mana cost: %d   -   Copies you can carry: %d\nAccuracy by correct answers (0 to 3): %s" % [
		spell.mana_cost, SpellProgress.copy_cap(spell_id), "  ->  ".join(accuracies),
	]
	if SpellBank.has_combined(spell_id):
		stats_label.text += "\nAfter Furia: %s" % spell.combined.sentence_es
	var trouble: Array = []
	for slot in spell.slots:
		if PlayerProfile.weakness(slot.word_id) >= 1.0:
			trouble.append("%s (missed %d)" % [slot.es, PlayerProfile.get_stats(slot.word_id).errors])
	if not trouble.is_empty():
		stats_label.text += "\nWords to review: " + ", ".join(trouble)

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
