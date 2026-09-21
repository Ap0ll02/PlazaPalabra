extends RefCounted
## Tiny shared fade helpers so UI text and panels ease in and out instead of
## popping. Each node keeps at most one running fade (a new one replaces it).

const FADE_IN := 0.18
const FADE_OUT := 0.14
const TEXT_FADE := 0.25

static func _kill(node: CanvasItem) -> void:
	if node.has_meta("fx_tween"):
		var t = node.get_meta("fx_tween")
		if t is Tween and t.is_valid():
			t.kill()

static func fade_in(node: CanvasItem, duration: float = FADE_IN) -> void:
	_kill(node)
	node.visible = true
	node.modulate.a = 0.0
	var t := node.create_tween()
	t.tween_property(node, "modulate:a", 1.0, duration)
	node.set_meta("fx_tween", t)

## Fades out then hides. The alpha is restored so a later show isn't invisible.
static func fade_out(node: CanvasItem, duration: float = FADE_OUT) -> void:
	_kill(node)
	if not node.visible:
		return
	var t := node.create_tween()
	t.tween_property(node, "modulate:a", 0.0, duration)
	t.tween_callback(func():
		node.visible = false
		node.modulate.a = 1.0)
	node.set_meta("fx_tween", t)

## Sets a label's text and fades it in (hides it if the text is empty).
static func fade_text(label: Label, text: String, duration: float = TEXT_FADE) -> void:
	label.text = text
	if text == "":
		_kill(label)
		label.visible = false
		label.modulate.a = 1.0
	else:
		fade_in(label, duration)
