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
var visit_number: int = 1
var prior_word_ids: Array = [] ## populated on visit >= 2 from the linked prior session
var prior_word_stats: Dictionary = {} ## word_id -> Week-1 stats (errors, seen, ...)
## Week-2 recap experiment: each word missed in Week 1 is randomly assigned
## "emphasized" (extra retrieval rounds) or "standard" (a single card); the
## rest are "never_missed" controls. See assign_recap_arms().
var recap_arm: Dictionary = {}    ## word_id -> "emphasized" | "standard"
var recap_never_missed: Array = []
var _data_dir: String = ""
var _session_start_msec: int = 0

## Called by ParticipantScreen once the participant code + visit number are
## known -- everything before that point (consent) doesn't need a data dir.
func configure(code: String, visit: int) -> void:
	participant_code = code
	visit_number = visit
	var dt := Time.get_datetime_dict_from_system()
	session_id = "P%s_visit%d_%04d%02d%02d_%02d%02d%02d" % [
		participant_code, visit_number, dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
	]
	_data_dir = _resolve_base_dir().path_join("study_data").path_join(session_id)
	DirAccess.make_dir_recursive_absolute(_data_dir)
	_session_start_msec = Time.get_ticks_msec()

	prior_word_ids = []
	prior_word_stats = {}
	recap_arm = {}
	recap_never_missed = []
	if visit_number > 1:
		var prior := _find_linked_session(code, visit_number - 1)
		if prior.has("word_stats"):
			prior_word_ids = prior.word_stats.keys()
			prior_word_ids.sort()
			prior_word_stats = prior.word_stats
			assign_recap_arms()
		log_event("session_start", {
			"participant_code": participant_code, "visit_number": visit_number,
			"prior_words_found": prior_word_ids.size(),
		})
	else:
		log_event("session_start", {"participant_code": participant_code, "visit_number": visit_number})

## Randomized within-person assignment for the Week-2 recap. A word is
## "missed" if it had at least one error in Week 1. Missed words are split
## by matched-pairs randomization into two arms of (nearly) equal size and
## equal Week-1 difficulty, so any later difference
## between the arms is attributable to the emphasis and not to word
## difficulty or regression to the mean. The RNG is seeded from the
## participant code, so the assignment is reproducible for audit.
func assign_recap_arms() -> void:
	var missed: Array = []
	recap_never_missed = []
	for id in prior_word_ids:
		if int(prior_word_stats.get(id, {}).get("errors", 0)) >= 1:
			missed.append(id)
		else:
			recap_never_missed.append(id)
	# Matched pairs: order missed words by how badly they were missed (most
	# errors first, id as tiebreak), pair neighbours, and coin-flip which of
	# each pair is emphasized. This keeps the two arms balanced on Week-1
	# difficulty as well as size. An odd word out is a coin flip too.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(participant_code + "|recap")
	missed.sort_custom(func(x, y):
		var ex := int(prior_word_stats[x].get("errors", 0))
		var ey := int(prior_word_stats[y].get("errors", 0))
		return ex > ey if ex != ey else str(x) < str(y))
	recap_arm = {}
	var i := 0
	while i < missed.size():
		if i + 1 < missed.size():
			var first_emphasized := rng.randf() < 0.5
			recap_arm[missed[i]] = "emphasized" if first_emphasized else "standard"
			recap_arm[missed[i + 1]] = "standard" if first_emphasized else "emphasized"
			i += 2
		else:
			recap_arm[missed[i]] = "emphasized" if rng.randf() < 0.5 else "standard"
			i += 1
	if missed.size() < 2:
		# Too few to randomize: everything gets the standard recap.
		for id in missed:
			recap_arm[id] = "standard"
	save_json("recap_assignment.json", {
		"rule": "missed = >=1 error in Week 1; matched-pairs randomization (pairs adjacent by error count)",
		"seed_source": "hash(participant_code|recap)",
		"missed_count": missed.size(),
		"arm": recap_arm,
		"never_missed": recap_never_missed,
	})
	var recap_rows: Array = []
	for id in recap_arm:
		recap_rows.append([id, recap_arm[id], int(prior_word_stats.get(id, {}).get("errors", 0))])
	for id in recap_never_missed:
		recap_rows.append([id, "never_missed", 0])
	save_table("recap_assignment.csv", ["word_id", "arm", "week1_errors"], recap_rows)
	log_event("recap_assigned", {
		"missed": missed.size(),
		"emphasized": recap_arm.values().count("emphasized"),
		"standard": recap_arm.values().count("standard"),
		"never_missed": recap_never_missed.size(),
	})

## Finds the most recent prior session folder for this code/visit and
## returns its session_summary.json (or {} if none exists -- e.g. a
## mistyped code, or genuinely the first time this code has been used).
func _find_linked_session(code: String, visit: int) -> Dictionary:
	var base := _resolve_base_dir().path_join("study_data")
	var prefix := "P%s_visit%d_" % [code, visit]
	var dir := DirAccess.open(base)
	if not dir:
		return {}
	var candidates: Array = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and name.begins_with(prefix):
			candidates.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	if candidates.is_empty():
		return {}
	candidates.sort()
	var summary_path := base.path_join(candidates[-1]).path_join("session_summary.json")
	if not FileAccess.file_exists(summary_path):
		return {}
	var f := FileAccess.open(summary_path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

## Short, human-writable code (no ambiguous 0/O or 1/I) offered to
## first-time participants to bring back for a follow-up session.
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
		"event": event_type,
		"data": payload,
	}
	_append_line(_data_dir.path_join("events.jsonl"), JSON.stringify(entry))
	var path := _data_dir.path_join("events.csv")
	if not FileAccess.file_exists(path):
		_append_line(path, csv_line(EVENT_COLUMNS))
	_append_line(path, csv_line([
		session_id, participant_code, visit_number, entry.t_msec, event_type,
		payload.get("word_id", ""), payload.get("spell_id", ""), payload.get("correct", ""),
		payload.get("kind", ""), JSON.stringify(payload),
	]))

# --- CSV output --------------------------------------------------------------
# Every table is a plain CSV (UTF-8, comma separated, quoted where needed) so
# it opens directly in Excel / LibreOffice and loads in pandas or R. Each row
# starts with session_id, participant_code, visit so files from many
# sessions can be stacked (tools/aggregate_study_data.py does that).

const EVENT_COLUMNS := [
	"session_id", "participant_code", "visit", "t_msec", "event",
	"word_id", "spell_id", "correct", "kind", "detail_json",
]
const KEY_COLUMNS := ["session_id", "participant_code", "visit"]

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
		f.store_line(csv_line([session_id, participant_code, visit_number] + row))
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
		"visit_number": visit_number,
		"prior_word_ids": prior_word_ids,
		"quest_stage_reached": GameState.quest_stage,
		"final_hp": GameState.hp,
		"word_stats": word_stats,
		"spell_progress": SpellProgress.snapshot(),
		"recap_arm": recap_arm,
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
			recap_arm.get(id, "never_missed" if id in recap_never_missed else ""),
			int(prior_word_stats.get(id, {}).get("errors", 0)),
		])
	save_table("word_stats.csv", [
		"word_id", "spanish", "english", "seen", "correct", "errors", "hinted",
		"recap_group", "week1_errors",
	], word_rows)
	var spell_rows: Array = []
	var progress := SpellProgress.snapshot()
	for id in progress:
		spell_rows.append([id, progress[id].practice, progress[id].tier, progress[id].get("in_book", 0)])
	save_table("spell_progress.csv", ["spell_id", "practice_count", "tier", "copies_in_book"], spell_rows)
	save_table("session.csv", [
		"quest_stage_reached", "final_hp", "duration_msec", "best_streak", "words_seen", "spells_known",
	], [[
		GameState.quest_stage, GameState.hp, Time.get_ticks_msec() - _session_start_msec,
		Praise.best, word_rows.size(), progress.size(),
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
