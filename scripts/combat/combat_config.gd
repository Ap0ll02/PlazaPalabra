extends RefCounted
## Combat tuning in one place. Per-encounter numbers (enemy HP, starting
## mana, loadout, accuracy bonus) live in encounters.gd; spell numbers and
## mastery tiers live in spell_bank.gd.

const MANA_MAX := 10
## Mana gained at the start of every player turn after the first.
const MANA_REGEN := 2
## Extra mana a hint costs, on top of the spell (never refunded).
const HINT_MANA_COST := 1
## The weak fallback move when the loadout is empty (no quiz, always hits).
const STRUGGLE_DAMAGE := 3
## Seconds between an enemy's Spanish line and its English translation.
const TRANSLATION_DELAY := 1.5

## A fizzled cast: is the spell's mana given back? (Hint mana never is.)
const FIZZLE_REFUNDS_MANA := true
## A fizzled cast: does it still use up one loadout slot?
const FIZZLE_CONSUMES_SLOT := true
## A fizzled attack: does a queued Furia bonus survive for the next attack?
const FURIA_SURVIVES_FIZZLE := true
