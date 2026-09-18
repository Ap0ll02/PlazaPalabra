extends Node
## Per-participant study data: a session id, an append-only telemetry
## event log, and a folder where surveys/summaries get written. Local
## files only, no network -- collected manually from the lab machine.
##
## In an exported build, data lands next to the executable (easy to find
## and copy after a session). In the editor, it goes to the standard
## user:// data dir instead, so test runs don't clutter the project.

var session_id: String
var _data_dir: String
var _session_start_msec: int

func _ready() -> void:
	session_id = _generate_session_id()
	_data_dir = _resolve_base_dir().path_join("study_data").path_join(session_id)
	DirAccess.make_dir_recursive_absolute(_data_dir)
	_session_start_msec = Time.get_ticks_msec()
	log_event("session_start", {})

func _generate_session_id() -> String:
	var dt := Time.get_datetime_dict_from_system()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "session_%04d%02d%02d_%02d%02d%02d_%04d" % [
		dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, rng.randi() % 10000
	]

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
