extends Node
## Per-participant study data: a session id, an append-only telemetry
## event log, and a folder where surveys/summaries get written. Local
## files only, no network -- collected manually from the lab machine.
##
## In an exported build, data lands next to the executable (easy to find
## and copy after a session). In the editor, it goes to the standard
## user:// data dir instead, so test runs don't clutter the project.

var session_id: String = ""
var participant_code: String = ""
var pending_participant_code: String = ""
var pending_consent_given := false
var portion_number: int = 1
var combat_order: Array[String] = []
var chosen_mechanic: String = ""
## Kept until the unreachable Recap scene is removed in the next pass.
var prior_word_ids: Array = []
var recap_arm: Dictionary = {}
## Filled in by RecallQuiz so the end-of-session summary can show the score.
var last_recall_correct := 0
var last_recall_total := 0
var _data_dir: String = ""
var _session_start_msec: int = 0

## Clear the previous session before a new person reaches the consent screen.
## The participant's code stays in memory until adult eligibility is known.
func reset_for_new_session() -> void:
	session_id = ""
	participant_code = ""
	pending_participant_code = ""
	pending_consent_given = false
	portion_number = 1
	combat_order.clear()
	chosen_mechanic = ""
	_data_dir = ""
	_session_start_msec = 0

## Called after an eligible participant completes the pre-survey.
func configure(code: String) -> void:
	pending_participant_code = ""
	participant_code = code
	portion_number = 1
	combat_order.clear()
	chosen_mechanic = ""
	var dt := Time.get_datetime_dict_from_system()
	session_id = "P%s_%04d%02d%02d_%02d%02d%02d" % [
		participant_code, dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
	]
	_data_dir = _resolve_base_dir().path_join("study_data").path_join(session_id)
	DirAccess.make_dir_recursive_absolute(_data_dir)
	_session_start_msec = Time.get_ticks_msec()
	_assign_combat_order()

	log_event("session_start", {"participant_code": participant_code, "portion": portion_number, "combat_order": combat_order})
	if pending_consent_given:
		log_event("consent_given")
		pending_consent_given = false

func begin_second_portion() -> void:
	if portion_number == 2:
		return
	portion_number = 2
	log_event("gameplay_portion_started", {"portion": portion_number, "after": "post_questionnaire"})

func mechanic_for_encounter(encounter_id: String) -> String:
	if combat_order.size() != 2:
		return "standard"
	match encounter_id:
		"tomas_spar_1": return combat_order[0]
		"tomas_spar_2", "sombra_boss": return combat_order[1]
		_: return chosen_mechanic if portion_number == 2 and chosen_mechanic != "" else "standard"

## Alternate assignments across locally recorded participants to keep the two
## orders as balanced as possible on a single study computer.
func _assign_combat_order() -> void:
	var intent_first := 0
	var standard_first := 0
	var root := DirAccess.open(_resolve_base_dir().path_join("study_data"))
	if root:
		root.list_dir_begin()
		var entry := root.get_next()
		while entry != "":
			if root.current_is_dir() and entry != session_id:
				var path := root.get_current_dir().path_join(entry).path_join("combat_assignment.json")
				if FileAccess.file_exists(path):
					var assignment = JSON.parse_string(FileAccess.get_file_as_string(path))
					if assignment is Dictionary and assignment.get("first", "") == "intent":
						intent_first += 1
					elif assignment is Dictionary and assignment.get("first", "") == "standard":
						standard_first += 1
			entry = root.get_next()
		root.list_dir_end()
	combat_order = ["intent", "standard"] if intent_first < standard_first else ["standard", "intent"]
	save_json("combat_assignment.json", {"first": combat_order[0], "second": combat_order[1], "sombra": combat_order[1]})

## Short, human-writable code (no ambiguous 0/O or 1/I).
func generate_participant_code() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code := ""
	for i in 6:
		code += CHARS[rng.randi() % CHARS.length()]
	return code

func _resolve_base_dir() -> String:
	if OS.has_feature("editor"):
		return "user://"
	return OS.get_executable_path().get_base_dir()

func log_event(event_type: String, payload: Dictionary = {}) -> void:
	if _data_dir == "":
		return # not configured yet (e.g. a scene run directly from the editor)
	var entry := {
		"t_msec": Time.get_ticks_msec() - _session_start_msec,
		"portion": portion_number,
		"event": event_type,
		"data": payload,
	}
	_append_line(_data_dir.path_join("events.jsonl"), JSON.stringify(entry))
	var path := _data_dir.path_join("events.csv")
	if not FileAccess.file_exists(path):
		_append_line(path, csv_line(EVENT_COLUMNS))
	_append_line(path, csv_line([
		session_id, participant_code, portion_number, entry.t_msec, event_type,
		payload.get("word_id", ""), payload.get("spell_id", ""), payload.get("correct", ""),
		payload.get("kind", ""), JSON.stringify(payload),
	]))

# --- CSV output --------------------------------------------------------------
# Every table is a plain CSV (UTF-8, comma separated, quoted where needed) so
# it opens directly in Excel / LibreOffice and loads in pandas or R. Each row
# starts with session_id and participant_code so files from many
# sessions can be stacked (tools/aggregate_study_data.py does that).

const EVENT_COLUMNS := [
	"session_id", "participant_code", "portion", "t_msec", "event",
	"word_id", "spell_id", "correct", "kind", "detail_json",
]
const KEY_COLUMNS := ["session_id", "participant_code"]

static func csv_field(value) -> String:
	var text := str(value)
	if text.contains(",") or text.contains("\"") or text.contains("\n") or text.contains("\r"):
		return "\"" + text.replace("\"", "\"\"") + "\""
	return text

static func csv_line(values: Array) -> String:
	return ",".join(values.map(func(v): return csv_field(v)))

## Writes a whole table. `headers` should NOT include the key columns; they
## are added to every row. `rows` is an Array of Arrays matching `headers`.
func save_table(filename: String, headers: Array, rows: Array) -> void:
	if _data_dir == "":
		return
	var f := FileAccess.open(_data_dir.path_join(filename), FileAccess.WRITE)
	if not f:
		return
	f.store_line(csv_line(KEY_COLUMNS + headers))
	for row in rows:
		f.store_line(csv_line([session_id, participant_code] + row))
	f.close()

func save_json(filename: String, data: Dictionary) -> void:
	if _data_dir == "":
		return
	var f := FileAccess.open(_data_dir.path_join(filename), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func write_session_summary() -> void:
	_write_summary_tables()
	var word_stats := {}
	for id in WordBank.all_word_ids():
		if PlayerProfile.has_seen(id):
			word_stats[id] = PlayerProfile.get_stats(id)
	save_json("session_summary.json", {
		"session_id": session_id,
		"participant_code": participant_code,
		"final_portion": portion_number,
		"combat_order": combat_order,
		"chosen_mechanic": chosen_mechanic,
		"quest_stage_reached": GameState.quest_stage,
		"final_hp": GameState.hp,
		"word_stats": word_stats,
		"spell_progress": SpellProgress.snapshot(),
		"duration_msec": Time.get_ticks_msec() - _session_start_msec,
	})

func _write_summary_tables() -> void:
	var word_rows: Array = []
	for id in WordBank.all_word_ids():
		if not PlayerProfile.has_seen(id):
			continue
		var st: Dictionary = PlayerProfile.get_stats(id)
		var word: Dictionary = WordBank.get_word(id)
		word_rows.append([
			id, word.spanish, word.english, st.seen, st.correct, st.errors, st.hinted,
		])
	save_table("word_stats.csv", [
		"word_id", "spanish", "english", "seen", "correct", "errors", "hinted",
	], word_rows)
	var spell_rows: Array = []
	var progress := SpellProgress.snapshot()
	for id in progress:
		spell_rows.append([id, progress[id].practice, progress[id].tier, progress[id].get("in_book", 0)])
	save_table("spell_progress.csv", ["spell_id", "practice_count", "tier", "copies_in_book"], spell_rows)
	save_table("session.csv", [
		"quest_stage_reached", "final_hp", "duration_msec", "best_streak", "words_seen", "spells_known",
		"answers_correct_first_try", "answers_wrong",
	], [[
		GameState.quest_stage, GameState.hp, Time.get_ticks_msec() - _session_start_msec,
		Praise.best, word_rows.size(), progress.size(), Praise.total_correct, Praise.total_wrong,
	]])

func get_data_dir() -> String:
	return _data_dir

func _append_line(path: String, line: String) -> void:
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_line(line)
		f.close()
