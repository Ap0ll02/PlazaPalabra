# Recording lines

Text is copied from the current game scripts. Record each numbered character line once; branches marked *retry*, *loss*, or *choice* can appear on different playthroughs. The game currently plays character dialogue as text. The Spanish clips in the last section are the recordings the listening exercise actually loads.

## Mira

1. ¡Por Favor! Can you help me? Some men just stole my coin!
2. Could you help me look for clues near the market stalls?
3. Thank you! ¡Gracias! I think just searching around these market stalls might be a good start...
4. Oh... please come back if you change your mind. This world could use more heroes. *(decline)*
5. Did you find anything yet? *(while searching)*
6. You found something! A note...
7. This note, I don't know, 'No Lo Se' what it means. Perhaps Tomas, near the well, will have an idea!
8. Go talk to him!
9. Please be careful! There are three of them!
10. You did it! You beat them all! And you found my money?
11. Thank you, truly! I wish I could repay you properly...
12. Wait! One of the bandits dropped a scroll when he ran. Please, take it. Maybe it can help you.
13. Thank you again. Oh... where is Tomas? He was here just this morning.
14. One of the bandits said he was taken. I have no idea what happened to him.
15. Please, will you look for him? The jungle path to the east is where the bandits came from.
16. Please find Tomas. The jungle path to the east is where the bandits came from. *(reminder)*
17. Be careful! There are bandits all around me! *(during ambush)*

## Tomas

1. Hola, a traveler I take it?
2. Ah, Mira sent you. I heard about the robbery.
3. That note... I know that handwriting. There's a thief who hides out in the old ruins east of town. They call him Sombra.
4. Are you sure you want to go after him?
5. Words are your best weapon, you may not be from around here, but I can teach you what I know.
6. Listen close, and use these incantations, they will help if things get messy...
7. Follow the path east out of town. And be careful.
8. Sorry, I'm busy. Maybe ask Mira about her missing money first. *(early interaction)*
9. The ruins are east of town. Good luck. *(reminder)*
10. You came all the way out here for me. Thank you. Sombra was only a piece of something bigger.
11. But that is a story for another day. Let's go home.

## Sombra

1. Tch. You followed me all the way out here?
2. Those coins are mine now. Go home, traveler.
3. Bold. Let's see what you've got. *(fight choice)*
4. Talk? Ha! Let's see if you can string a sentence together. *(talk choice)*
5. Back for more? Then speak up this time. *(retry)*
6. Tch... enough! Take your coins back. Who taught you to talk like that? *(first victory)*
7. Ha! Come back when you can string a sentence together. *(first loss)*
8. So you followed me all the way here. Persistent, aren't you?
9. Last time I held back. This time, I won't.
10. Voy a vencerte... I will defeat you.
11. Back for more? Good. I was just getting warmed up. *(final retry)*
12. Impossible... You speak better than you did before. *(final victory)*
13. Fine. Take your old man. The cage is open. But I wasn't working alone...
14. Ha! Is that all? Practice, then come back. *(final loss)*

## Bandit

1. Hey, you! That scroll is mine now. Hand it over!
2. No? Then I'll take it the hard way!
3. Well, well, look who's here! Hand over those coins and maybe we leave the lady alone.
4. Get them!
5. Ha! Had enough already? Then give us the coins! *(retry)*

## Spanish listening clips

Record these as **separate clips**, one word or phrase per file. The game looks for `.ogg`, `.wav`, or `.mp3` under `assets/audio/voice/`; the filename uses lowercase text without accents and with underscores for spaces. These are all unique spell slots currently in `spell_bank.gd` (including the advanced ice spell).

| Say | Filename stem |
| --- | --- |
| Yo | `yo` |
| lanzo | `lanzo` |
| una bola de fuego | `una_bola_de_fuego` |
| disparo | `disparo` |
| un rayo | `un_rayo` |
| Ustedes | `ustedes` |
| sienten | `sienten` |
| frío | `frio` |
| gano | `gano` |
| fuerza | `fuerza` |
| me | `me` |
| sano | `sano` |
| un rayo morado | `un_rayo_morado` |
| Tú | `tu` |
| sientes | `sientes` |
| un viento plateado | `un_viento_plateado` |
| siento | `siento` |
| una luz dorada | `una_luz_dorada` |
| protejo | `protejo` |
| con fuerza | `con_fuerza` |
| y el hielo los golpea | `y_el_hielo_los_golpea` |

## Optional if you want to voice all dialogue-box text

These have no named speaker in the game. They are narration, prompts, or choice responses, so decide whether they need a narrator/player voice before recording:

- You return to town with Mira's stolen coins, and stop short. Mira is surrounded by three bandits!
- You hand Mira the coins.
- Your spellbook only has a few spells in it. Fill it up before facing Sombra?
- Take your time. Talk to him when you're ready.
- Here goes nothing.
- An old stone shrine stands here. On its altar a scroll glints, and a jaguar guards it. It growls and blocks your way.
- The jaguar crouches, ready to pounce.
- You step back. The jaguar's eyes follow you, but it doesn't chase.
- The jaguar slinks away into the trees, leaving the shrine's scroll behind.
- The jaguar drives you back. Catch your breath, check your spellbook, and try again.
- The bandit scrambles off into the wreckage, clutching his bruises. The scroll is yours to keep.
- You found a %s (%s)! This might be a clue. *(dynamic Spanish/English word)*
- There's nothing here. *(default search-spot text)*
- A scrap of paper glows faintly among the wreckage. The strange marks seem to rearrange themselves as you stare at them.
- Tucked under a torn cloth in the crates is a scroll, warm to the touch. A healer's charm, maybe.
- Wedged under the cart's seat is a scroll marked with a clenched fist.
- Behind a fallen pillar, a scroll is sealed in a sheet of ice that hasn't melted in years. It cracks open as you reach for it.
- Half-buried under huge leaves, a scroll glows with a soft golden light.
- On the shrine's altar, a scroll swirls, wrapped in a silvery wind.

Player choice buttons are text selections, not spoken lines. The intro's four captions are also on-screen text rather than dialogue.
