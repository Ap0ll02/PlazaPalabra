extends RefCounted
## Line-art spell icons. Each is a small SVG drawn white on transparent so
## it can be tinted to the spell's type color. To replace one with real art,
## drop `assets/icons/spells/<spell_id>.png` in the project: that file wins.

const SVG_HEAD := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none" stroke="#fff" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">'

const SHAPES := {
	"bola_de_fuego": '<path d="M32 7C35 19 48 23 48 38C48 48 41 56 32 56C23 56 16 48 16 38C16 30 22 26 24 19C27 23 28 25 30 26C30 20 30 14 32 7Z"/><path d="M32 47C28 47 26 44 27 40C29 42 31 42 32 38C35 42 37 44 37 45C37 46 35 47 32 47Z"/>',
	"rayo": '<path d="M37 6L15 35H30L26 58L49 26H34Z"/>',
	"tormenta_de_hielo": '<path d="M32 6V58M9.5 19L54.5 45M9.5 45L54.5 19"/><path d="M26 12L32 18L38 12M26 52L32 46L38 52M11 30L19 31L17 22M53 34L45 33L47 42"/>',
	"furia": '<circle cx="32" cy="32" r="26"/><path d="M19 30L32 17L45 30M19 46L32 33L45 46"/>',
	"luz_curativa": '<circle cx="32" cy="32" r="26"/><path d="M32 17V47M17 32H47"/>',
	"rayo_morado": '<circle cx="32" cy="32" r="28"/><path d="M36 10L18 34H30L27 54L46 28H34Z"/>',
	"viento_plateado": '<path d="M6 22H38C46 22 46 12 39 12M6 34H50C58 34 58 46 50 46M6 46H30C36 46 36 54 30 54"/>',
	"luz_dorada": '<circle cx="32" cy="32" r="10"/><path d="M32 6V16M32 48V58M6 32H16M48 32H58M14 14L21 21M43 43L50 50M50 14L43 21M21 43L14 50"/>',
	"muro_de_piedra": '<path d="M32 6L52 14V32C52 46 43 54 32 58C21 54 12 46 12 32V14Z"/><path d="M32 6V58M12 30H52"/>',
}

static var _cache: Dictionary = {}

## The icon texture for a spell (custom PNG if present, else the built-in SVG).
static func get_icon(spell_id: String) -> Texture2D:
	if _cache.has(spell_id):
		return _cache[spell_id]
	var tex: Texture2D = null
	var custom := "res://assets/icons/spells/%s.png" % spell_id
	if ResourceLoader.exists(custom):
		tex = load(custom)
	elif SHAPES.has(spell_id):
		var img := Image.new()
		if img.load_svg_from_string(SVG_HEAD + SHAPES[spell_id] + "</svg>", 2.0) == OK:
			tex = ImageTexture.create_from_image(img)
	_cache[spell_id] = tex
	return tex

## True if the icon is our white line art (so it should be tinted), false
## for custom art, which is shown as-is.
static func is_line_art(spell_id: String) -> bool:
	return not ResourceLoader.exists("res://assets/icons/spells/%s.png" % spell_id)
