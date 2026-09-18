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
	if visit_number > 1:
		var prior := _find_linked_session(code, visit_number - 1)
		if prior.has("word_stats"):
			prior_word_ids = prior.word_stats.keys()
		log_event("session_start", {
			"participant_code": participant_code, "visit_number": visit_number,
			"prior_words_found": prior_word_ids.size(),
		})
	else:
		log_event("session_start", {"participant_code": participant_code, "visit_number": visit_number})

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
	var entry := {
		"t_msec": Time.get_ticks_msec() - _session_start_msec,
		"event": event_type,
		"data": payload,
	}
	_append_line(_data_dir.path_join("events.jsonl"), JSON.stringify(entry))

func save_json(filename: String, data: Dictionary) -> void:
	var f := FileAccess.open(_data_dir.path_join(filename), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func write_session_summary() -> void:
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
		"duration_msec": Time.get_ticks_msec() - _session_start_msec,
	})

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
