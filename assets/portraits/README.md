# Dialogue portraits

Drop PNGs here named `<id>.png`. The dialogue box loads them automatically;
until a file exists, a labeled colored placeholder shows in its place.

The ids in use (edit a dialogue node's `"portrait"` key to use a different one):

| Character | Files |
|---|---|
| Mira | `mira.png` (default), `mira_worried.png`, `mira_sad.png`, `mira_relieved.png` |
| Tomas | `tomas.png` (default), `tomas_thoughtful.png`, `tomas_serious.png` |
| Bandit | `bandit.png` |
| Sombra | `sombra.png` (default), `sombra_smug.png`, `sombra_angry.png` |

Display area is roughly 150x240 px, drawn to the left of the text box and
scaled to fit while keeping aspect ratio, so tall/portrait-shaped art works
best. New poses need no code change: name the file, then reference the id
in the relevant dialogue dict.
