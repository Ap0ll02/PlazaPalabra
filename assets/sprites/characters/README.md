# Character sprites

Drop a transparent PNG here named `<character_id>.png` and every scene using
that character picks it up automatically — no scene or script edits. Until
a file exists, a placeholder shape shows in its place, so the game looks and
plays the same either way. Handled by `scripts/world/character_sprite.gd`.

| Character | id |
|---|---|
| Player | `player` |
| Mira | `mira` |
| Tomas | `tomas` |
| Sombra | `sombra` |
| Bandit | `bandit` |
| Jaguar | `jaguar` |

New characters just need a `character_id` on their `CharacterSprite` node
(`scripts/world/character_sprite.gd`) — no new convention to learn.

## Checklist before dropping in AI-generated art

- **Transparent PNG**, no background.
- **Centered** in the frame with consistent margin on all sides (the sprite
  is placed by its bounding box, not by detecting the character in it).
- **Feet near the bottom edge** — this is what lines up with the ground; a
  character floating mid-frame will look like it's floating in-game too.
- **Consistent apparent size** across characters — a giant enemy and a tiny
  one, drawn at the same in-game width, will look wrong next to each other.
  If a character should read as bigger or smaller, say so and we'll set a
  width per character rather than relying on the source image's proportions.
- **One clean, front/three-quarter pose** per file for now (idle animation
  frames or poses are a separate, later step — ask before adding extra
  files so the code that plays them matches what you actually have).
- Skim it once for the common AI-art tells (extra/fused fingers, warped
  weapons or hands, asymmetric eyes, garbled text on clothing/signage) before
  it goes in project. Also confirm you have the rights to use the source
  the art was generated from, if that's applicable.
