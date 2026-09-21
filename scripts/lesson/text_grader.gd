extends RefCounted
## Grades typed answers: ignores case, punctuation and extra spaces,
## accepts any phrasing from a list, tolerates one typo (on answers long
## enough that one edit can't turn them into a different word), and for
## Spanish also ignores accents so a US keyboard isn't a handicap.

const _ACCENTS := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}

static var _punct: RegEx
static var _spaces: RegEx

static func strip_accents(text: String) -> String:
	var out := text
	for accented in _ACCENTS:
		out = out.replace(accented, _ACCENTS[accented])
	return out

static func normalize(text: String, drop_accents: bool = false) -> String:
	if _punct == null:
		_punct = RegEx.new()
		_punct.compile("[^\\p{L}\\p{N}\\s]")
		_spaces = RegEx.new()
		_spaces.compile("\\s+")
	var t := text.to_lower()
	if drop_accents:
		t = strip_accents(t)
	t = _punct.sub(t, "", true)
	t = _spaces.sub(t, " ", true)
	return t.strip_edges()

static func edit_distance(a: String, b: String) -> int:
	var prev: Array = []
	for j in b.length() + 1:
		prev.append(j)
	for i in range(1, a.length() + 1):
		var cur: Array = [i]
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur.append(mini(mini(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost))
		prev = cur
	return prev[b.length()]

## Returns {correct: bool, typo: bool, nudge: String}. `nudge` is the
## properly spelled answer when the input was right except for accents or
## a typo, so the UI can show it gently.
static func grade(input: String, accepted: Array, spanish: bool = false, allow_typo: bool = true) -> Dictionary:
	var result := {"correct": false, "typo": false, "nudge": ""}
	var norm_input := normalize(input, spanish)
	if norm_input == "":
		return result
	for candidate in accepted:
		var norm_candidate := normalize(candidate, spanish)
		if norm_input == norm_candidate:
			result.correct = true
			result.typo = false
			result.nudge = ""
			if spanish and normalize(input, false) != normalize(candidate, false):
				result.nudge = candidate
			return result
		if allow_typo and norm_candidate.length() >= 5 and edit_distance(norm_input, norm_candidate) <= 1:
			result.correct = true
			result.typo = true
			result.nudge = candidate
	return result
