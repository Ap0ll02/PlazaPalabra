extends Node
## Persistent, session-wide player profile: per-word familiarity and the
## hint-cost economy described in the design doc (free while new, flat
## predictable penalty once over-relied on, penalty lifted once mastered).

const FREE_HINT_ALLOWANCE := 2
const HINT_PENALTY := 0.10
const MASTERY_UNHINTED_STREAK := 2

## word_id -> { seen: int, hinted: int, correct: int, unhinted_streak: int }
var _word_stats: Dictionary = {}

func _stat(word_id: String) -> Dictionary:
	if not _word_stats.has(word_id):
		_word_stats[word_id] = {
			"seen": 0,
			"hinted": 0,
			"correct": 0,
			"unhinted_streak": 0,
		}
	return _word_stats[word_id]

func record_seen(word_id: String) -> void:
	_stat(word_id).seen += 1
	StudySession.log_event("word_seen", {"word_id": word_id})

## Cost as a fraction of the action's effect (0.0 = free, 0.10 = -10%).
## Pure query, does not mutate state -- safe to call for UI preview.
func get_hint_cost(word_id: String) -> float:
	var stat := _stat(word_id)
	if is_mastered(word_id):
		return 0.0
	if stat.hinted < FREE_HINT_ALLOWANCE:
		return 0.0
	return HINT_PENALTY

## Call when the player actually uses a hint on this word this turn.
func record_hint(word_id: String) -> float:
	var cost := get_hint_cost(word_id)
	_stat(word_id).hinted += 1
	_stat(word_id).unhinted_streak = 0
	StudySession.log_event("hint_used", {"word_id": word_id, "cost": cost})
	return cost

## Call when the player resolves a slot correctly. `was_hinted` should
## reflect whether a hint was used on this word THIS turn.
func record_correct(word_id: String, was_hinted: bool) -> void:
	var stat := _stat(word_id)
	stat.correct += 1
	if was_hinted:
		stat.unhinted_streak = 0
	else:
		stat.unhinted_streak += 1
	StudySession.log_event("word_correct", {"word_id": word_id, "was_hinted": was_hinted})

func is_mastered(word_id: String) -> bool:
	return _stat(word_id).unhinted_streak >= MASTERY_UNHINTED_STREAK

func get_stats(word_id: String) -> Dictionary:
	return _stat(word_id).duplicate()

func has_seen(word_id: String) -> bool:
	return _word_stats.has(word_id) and _word_stats[word_id].seen > 0
