# Final Boss

![Final Boss](https://raw.githubusercontent.com/SirMaiquis/Balatro-FinalBoss/main/thumbnail.jpg)

Bosses talk back, and they are savage about it: every boss trash-talks in its own personality and reads your run. Every boss blind gets a short line of dialogue when it starts, reacts to your big hands, close calls and your last hand (before you play it), and gloats if you lose to it. Showdown bosses go further: a roaming boss avatar with an HP bar, a cinematic intro, their own music, screen effects and a slow-motion explosive finale. You also decide when showdowns appear, so you can have a final boss every 8 antes like vanilla or much sooner. Every boss also performs a visible move when its effect hits, final bosses transform at 50% and 25% HP and die their own way, and bosses remember you across runs: rematch lines, a nemesis and ten achievements.

## Requirements

- Balatro 1.0.1
- [Lovely](https://github.com/ethangreen-dev/lovely-injector) 0.9.0 or newer
- [Steamodded](https://github.com/Steamodded/smods) 26.829.0 or newer

## Install

**With a mod manager:** install [Final Boss from Thunderstore](https://thunderstore.io/c/balatro/p/SirMaiquis/FinalBoss/) (r2modman or the Thunderstore app). Steamodded and Lovely come with it.

**By hand:**

1. Download `FinalBoss-v1.2.0.zip` from the [releases page](https://github.com/SirMaiquis/Balatro-FinalBoss/releases).
2. Extract it into `%AppData%\Balatro\Mods\` so the files end up in `%AppData%\Balatro\Mods\FinalBoss\`.
3. Start Balatro. The mod appears in the Mods menu as "Final Boss" with its own config tabs.

## Features

### Encounter tiers

Every boss blind gets a tier. The tier decides how much of the show it gets.

| | Light (regular bosses) | Full (showdowns) |
|---|---|---|
| Intro | 1 line (the boss's threat, or a jab at your run) | 2 lines: boss name (or the rematch or nemesis line), then threat or jab |
| Reactions (big hand, close call, last hand, boss disabled) | each once per blind; at most 1 line per hand and never on two hands in a row (last hand and boss disabled excepted) | each once per blind |
| Run comments (weak hit, reads) | each once per blind, spaced like the reactions; at most 1 read per blind | each once per blind; at most 3 reads per blind, never on two hands in a row |
| Defeat | a line | a line and the shatter effect (the explosive finale when `cinematic` is on) |
| Music | vanilla | a FinalBoss showdown track |
| Screen effects (vignette, shake, flash) | none | yes |
| Interrupted line (you play during the intro) | yes | yes |
| Gloat when you lose | yes | yes |

Reaction triggers:

- Big hand: a single hand scores at least 30% of the blind requirement.
- Close: your running total is at least 75% of the requirement but you have not won yet.
- Last hand: a hand leaves you on your final hand, still short of the requirement. The boss taunts you before you play it.
- Disabled: the boss was disabled (for example by Chicot). A disabled final boss says it again when it gets angry at 50% and 25% health (see "Final bosses: deaths and phases").
- Defeat: the hand that reaches the requirement.

If several reactions would fire on the same hand, only one plays (last hand, then close, then big hand). Click the blind chip or press any key during an intro to advance to the next line; press twice quickly to skip the rest of the intro.

**Interrupting the boss.** Play a hand while the boss's intro is still running (the showdown title card or any intro line) and the speech stops at once: the boss snaps (a sharp shake and a red flash on the avatar, or on the HUD chip for regular bosses) and says its interrupted line instead. That line replaces the reaction line for that hand; the hit itself still lands. It happens once per blind. Skipping lines with a key or a click, or discarding, is not an interruption.

**Game over.** When a boss beats you, Jimbo mocks you on the game-over screen with that boss's catchphrase.

Regular bosses are light tier from the ante set in `min_ante` onward. Showdown bosses are always full tier. Mods can override the tier per boss (see below). An explicit `'light'` or `'full'` tier ignores `min_ante` and whether the boss is a showdown.

### Savage bosses that read your run

Bosses trash-talk. Each one has a personality that sets its voice:

| Personality | Voice | Bosses |
|---|---|---|
| Bully | blunt, loud, physical threats | The Ox, The Wall, The Tooth, The Club, The Goad |
| Smug genius | condescending | The Psychic, The Eye, The Mark, The Window |
| Cold killer | quiet, clinical | The Needle, The Manacle, The Pillar, The Serpent, The Hook |
| Sweet venom | sweet-talking, poisonous | Crimson Heart, Verdant Leaf, The Plant, The Head |
| Chaos gremlin | manic, giggling | The Wheel, The Flint, The Fish, Amber Acorn |
| Royal snob | aristocratic disdain | The House, The Arm, The Mouth, The Water, Violet Vessel, Cerulean Bell |

Every boss speaks in its own lines: its threat, its reactions, its defeat line. The personality adds the rest: run jabs, comments on your play, idle taunts, the overkill line and poke reactions. They roast your play, your build and your luck. Swearing is censored with asterisks and a short bleep; there are no slurs and nothing about real people or groups. Turning Boss dialogue off silences everything below.

- **Intro threat.** The intro line is a threat that hints at the boss's effect (the game already explains it).
- **Intro jabs.** About one intro in three, when your run gives the boss something to say, a jab replaces the threat: you skipped blinds this ante, rerolled the shop 5+ times since the last boss, have $3 or less or $50 or more, a deck with 75% of one suit, 30 cards or fewer or 70 or more, no jokers or a full joker row, or a famous joker (Blueprint, Brainstorm, Baron, DNA, Mime, Cavendish, Triboulet, Perkeo, Yorick, Canio, Sock and Buskin, Hologram). Any jab that applies may be picked, but never the one you got last. Counter jokers are always called out: Chicot, Luchador, Matador, Mr. Bones. Each vanilla boss has its own line for its main counter (Chicot for final bosses, Luchador for the rest), and since Chicot disables the boss before its intro, that line comes as the boss is disabled. A nemesis line is never replaced by a jab.
- **Reading your play.** When a hand triggers no other reaction, the boss may comment: a weak hit (under 10% of the requirement; final bosses laugh first), High Card or a Pair, the same hand type three times in a row, no discards left with 3 or more hands to play (this one included), a single card played. Each comment once per blind, never on the winning hand. A regular boss says at most one of these per blind besides the weak hit, and only when its spacing allows (at most one line every other hand); a final boss makes at most three, never on two hands in a row.
- **Overkill.** Win with a hand that brings your total to twice the requirement and, half the time, the boss's last words are its overkill line instead of its defeat line.
- **Idle taunts.** Choosing cards and touching nothing for 25 seconds makes the boss impatient; a second taunt comes 45 seconds later, never a third. Any key, click, controller button or card selection restarts the clock; menus, pauses and intros stop it.

### Poke the boss

During a boss fight, the boss chip in the HUD is yours to bother (in a showdown, the roaming boss avatar while it is on the table).

- **Poke.** Click it: it jiggles and says something.
- **Poke hard.** Click it 3 times within 2 seconds: a bigger reaction and a harsher line (then not again for 8 seconds).
- **Grab.** Drag it: it springs back after about a second, even while you hold it, and the boss reacts as it returns.

Each personality takes it its own way: the bully is furious (a red flash and an angry shake), the cold killer barely moves and threatens you, the royal snob recoils, offended, the smug genius talks down to you, sweet venom is sweet until you poke hard, then poisonous, and the chaos gremlin laughs. The chip always reacts; a line comes at most every 4 seconds, though three quick pokes get their answer right away (once per 8 seconds). Pokes never use up the boss's reactions or comments. They do nothing during intros, cinematics, menus or pauses, once the winning hand is in, nor before the ante where boss dialogue starts (`min_ante`). With Boss dialogue off the chip still reacts, silently. Reduced motion keeps the flashes and sounds but drops the movement.

### Showdown stage

Showdowns (full tier) get a stage of their own. None of it appears for regular bosses.

- **Roaming boss avatar.** A large chip with the boss's own art sits on the table. It bobs and lives right of the play area, above the deck; while you choose cards it glides between a few open spots where its HP bar stays clear of your cards, and it stops while it talks. When you play a hand it returns to the right of the play area until the hand resolves. Its speech bubbles are drawn above your cards. The boss reacts when your score lands: each hand makes it flash and flinch, a hand under 10% of the boss's health makes it shrug off the hit and laugh (a distinct "ha-ha-ha": it hops and tilts, and its line waits until the laugh ends), and it gets wounded: below 50% it cracks and bobs faster, below 25% it cracks more and trembles. While the boss is on the table, its HUD chip steps out of the HUD and returns when it leaves. Click it to skip an intro line; during the fight, click or drag it to poke the boss (see "Poke the boss").
- **HP bar and damage numbers.** Under the avatar: the boss name, a vanilla-style pixel bar (the same rounded, stepped bars as the game's own progress bars) in the boss's colour and `remaining / max`. The bar is drawn under your cards, so a card that overlaps it stays on top; damage numbers and speech bubbles still draw above. Each hand drops the bar at once and leaves a white trail that drains, and a damage number pops up above the avatar (big hands bigger, tiny hands small and grey). The bar flashes at 50% and 25%.
- **Cinematic intro.** Black bars slide in, a dark band with the "SHOWDOWN" title and the boss name slams in across the screen (above the boss-effect text) and holds for a moment, and the avatar falls onto the table before it speaks. Press any key to jump straight to the avatar and its dialogue (a click works once the avatar has landed). Press again to advance a line; press twice quickly to skip the rest. The title card draws above your cards. Continue never replays the intro.
- **Slow-motion explosive finale.** When the winning score lands, the game slows for under a second while the avatar cracks and shows its defeat line, then it explodes into shards with a flash in the boss's colour (the flash needs `fx`); the five vanilla final bosses die their own way instead (see "Final bosses: deaths and phases"). Playing a hand during the title card cuts the intro: the avatar lands at once, snaps at you and says its interrupted line (no intro dialogue).
- **Game-over gloat.** Lose a showdown and the HP bar goes away (the fight is over) while the avatar glides beside the game-over panel, above the dark overlay. When Jimbo says the boss's catchphrase, the boss laughs once, then bobs smugly until you start a new run or go to the main menu.
- **Living arena.** The background swirl takes the boss's colours, pulses on each hand, and darkens and spins faster as the boss gets wounded (below 50%, then below 25%). In the final stretch (below 25%) the music pitches up slightly; the pitch-up needs both `fx` and `music`. Everything returns to normal when the blind ends.

Turn off the avatar side with `cinematic` (avatar, HP bar, damage numbers, intro and finale). The arena follows `fx`, and the music pitch-up in the final stretch needs both `fx` and `music`. If you quit or Continue mid-showdown the stage is rebuilt from the saved score, with no fall-in.

**Reduced motion.** With Balatro's reduced motion setting on, the stage keeps colours, flashes, the dissolve and the explosion, but drops the movement: no roaming, bob, tilt, tremble, knockback, slide/fall animations, slow motion, arena spin or arena pulses (an interrupted boss only flashes red, and the game-over avatar does not bob). The avatar and bars just appear, the avatar stays right of the play area, and screen shake is off (only the explosion keeps a small jiggle).

### Boss moves

Every vanilla boss performs a visible move at the moment its effect applies, with a short sound at its own voice pitch. In a showdown the avatar performs it; otherwise the boss chip in the HUD does (it juices and flashes in the boss's colour first). All 28 vanilla bosses have one.

- **When you play a hand:** The Hook whips a chain at the two cards it discards, which jolt toward it; The Tooth bites your played cards and drains a coin per card.
- **When it hits your hand:** The Flint sparks and cracks the Chips and Mult panels; The Psychic, The Eye and The Mouth send rings onto your played cards (The Eye adds a beam); The Arm drops the Raised Fist onto your hand level and slams it as the level falls; The Ox drains your money.
- **When cards are dealt:** The Club, Goad, Window and Head put a frame in the suit's colour and a suit badge on each cursed card; The Plant and Verdant Leaf grow vines over theirs; The Pillar cracks the cards played this ante. These marks are part of the card, drawn like a seal, and stay for as long as the curse holds. The Wheel spins its face-down card, The Mark puts an X on face cards it flips, The Fish sweeps a splash over the hand, The House sweeps the hand while it is dealt and flashes each face-down card as it lands, The Serpent's snake crawls from the deck to the hand and arrives with the 3-card refill, Cerulean Bell rings and circles the forced card, Crimson Heart fires a beam at the joker it disables.
- **The moment the blind is set** (The Wall, The Water, The Needle, The Manacle, Violet Vessel, Amber Acorn): the move plays at once and shows your value before and after. The Wall's and the Vessel's target counts up from the normal boss target (a bar slams it and cracks it, or purple rises over it); The Water washes your discards down to 0; The Manacle chains your hand and its card count drops by one; The Needle stabs the hands counter, which shakes and drops one hand at a time down to 1; Amber Acorn sweeps your jokers.
- **When you sell a joker** to Verdant Leaf, it bursts into leaves.

Moves never change what the boss does; they only show it. A repeated move (a stamp on every draw) plays at most once per batch, and curse marks are always placed even then. A disabled boss stops performing, except Verdant Leaf disabled by your sale. Bosses from other mods burst when they act. Turn moves off with Boss moves (`moves`); they also need Screen effects (`fx`). Reduced motion keeps the flashes, marks and particles but nothing flies, slides, falls or spins.

### Final bosses: deaths and phases

- **Deaths.** The finale's explosion is replaced by each final boss's own death: Crimson Heart shatters into hearts, Verdant Leaf is blown away in a gust of leaves, Amber Acorn cracks open (crack lines and shell shards), Violet Vessel spills purple liquid over the play area, Cerulean Bell rings once more and breaks. Bosses from other mods keep the explosion unless they register a `death`. Deaths need `fx`.
- **Phases.** At 50% and 25% health a final boss transforms: time slows for a moment, the screen flashes in its colour and the showdown music dips, the avatar swells and shakes, its own move erupts big and it says a phase line. Afterwards its HP bar shows **II** or **III**, and it roams faster with an aura that gets stronger in phase III. One huge hand that goes from above 50% to below 25% goes straight to phase III. The winning hand and your last hand never transform the boss, and a boss that has been disabled (for example by Chicot) has no phases and no twists: at 50% and 25% it gets angry instead, flashing red with a short shake (the flash only with reduced motion) and saying its disabled line again, with no transformation, marker or stance. A Verdant Leaf disabled by your own joker sale still gets its phases and its regrowth twist. Phases need Showdown cinematics (`cinematic`).
- **Rule twists** (Boss phases change the rules, `phase_twists`, off by default, read when the blind starts): in phases II and III each final boss twists its own mechanic. Amber Acorn hides and reshuffles your jokers again; once you have sold a joker, Verdant Leaf withers 1 random card (phase II) or 2 (phase III) in each new hand, with vines on them; Violet Vessel heals 10% of its original requirement each time it changes phase (skipping to phase III heals twice) and the bar visibly refills; Crimson Heart disables 2 jokers per hand instead of 1; Cerulean Bell forces 2 cards instead of 1. With twists off, phases are only a show.

Continue mid-showdown restores the phase, stance, marker and twists without replaying the transformation.

### Memory, nemesis and achievements

- **Memory.** Bosses remember your results across runs, per Balatro profile (fights, wins and losses per boss). Seeded and challenge runs count too. A final boss you have met before opens with a rematch line instead of its name line (sore if you won last time, smug if you lost); a regular boss says its rematch line instead of its threat about half the time.
- **Nemesis.** The boss that has beaten you most, at least 3 times, becomes your nemesis (a tie goes to the more recent loss). A nemesis always greets you with a nemesis line. In a showdown the title card reads **NEMESIS** instead of SHOWDOWN and the avatar glows crimson; a regular nemesis gets a red NEMESIS tag over its chip and a faint crimson aura. When you beat it, it says its own defeat line while a gold "NEMESIS DEFEATED" banner, a gong and a gold burst play. A defeated nemesis loses the title until it beats you again.
- **Achievements.** Ten Steamodded achievements (Mods menu, Final Boss, Achievements tab):
  - Showdown Survivor: defeat a final boss
  - Clean Sweep: defeat all 5 vanilla final bosses
  - Rude!: interrupt a boss while it is talking
  - No Manners: interrupt 10 different bosses
  - Last Laugh: defeat a boss with the hand right after it laughed at you
  - Overkill: defeat a final boss in one hand from full HP
  - Phase Skipper: take a final boss from phase I to phase III in one hand
  - Comeback: defeat a final boss on your last hand
  - Nemesis Slayer: defeat your nemesis
  - Twisted: defeat all 5 vanilla final bosses with phase twists on (a win over a boss disabled by Chicot or Luchador does not count)

  They follow Steamodded's achievement settings: with an Unlock All profile, or in seeded and challenge runs, Steamodded decides whether they unlock (its "Bypass Restrictions" setting).

Boss memory (`memory`) off hides the rematch lines and the whole nemesis presentation, and records keep counting, so turning it back on picks up where you were.

### Showdown schedule

By default, showdowns appear exactly like vanilla (ante 8, 16, ...). Turn on the schedule in the Showdowns tab and pick a first ante and an interval to get extra showdowns, for example start 4 and every 4 gives antes 4, 8, 12 and so on. The win-ante boss is always a showdown. The tab shows a live ante track (antes 1 to 16, showdown antes lit in crimson with a final-boss chip) and warns ("Hard!") when the first showdown is before ante 4. Changes apply from the next ante's boss roll.

### Configuration

Set in the Mods menu (Final Boss). The Config tab groups the boss dialogue settings (with Boss memory) and the showdown stage toggles (with Boss moves and Boss phases change the rules, which grey out while Screen effects or Showdown cinematics are off), with the developer keys at the bottom; the Showdowns tab holds the schedule; the Credits tab has the links (GitHub, the showdown music, Ko-fi); Steamodded adds an Achievements tab listing the ten achievements. Steamodded saves your choices; `config.lua` only holds the defaults.

| Key | What it does | Default |
|---|---|---|
| `dialogue` | Boss and Jimbo lines (intros, jabs, reactions, comments on your play, idle taunts, poke lines, defeat, gloat) and the bleep. Off, a poked boss still reacts, silently | `true` |
| `music` | The FinalBoss showdown track (Adam Isiah's orchestral cover) during full-tier encounters | `true` |
| `cinematic` | Showdown cinematics: avatar, HP bar, damage numbers, intro and finale. The arena follows `fx`; the music pitch-up in the final stretch needs both `fx` and `music` | `true` |
| `fx` | Screen effects: vignette, shake, flash, shatter. They only run in full-tier encounters. Also controls the boss-coloured arena of showdowns. Respects Balatro's reduced motion and screenshake settings. Under reduced motion the shake and the vignette animation are off (the vignette stays at a fixed strength), while the background flash and the defeat burst still run | `true` |
| `moves` | Boss moves: every boss shows its effect with a visible move. Needs `fx` | `true` |
| `phase_twists` | Boss phases change the rules: final bosses twist their own mechanic in phases II and III. Needs `cinematic`; read when the blind starts | `false` |
| `memory` | Boss memory: rematch lines and the nemesis presentation. Records keep counting either way | `true` |
| `intro_speed` | How long each intro line stays up: 1 slow (6 s), 2 normal (4 s), 3 fast (2.5 s) | `2` |
| `min_ante` | First ante at which regular bosses get light-tier dialogue (1 to 8) | `1` |
| `showdown.enabled` | Use the extra showdown schedule | `false` |
| `showdown.start_ante` | First scheduled showdown ante (1 to 8) | `8` |
| `showdown.every` | Interval between scheduled showdowns (1 to 8) | `8` |
| `dev_mode` | Developer keys while in a run: F5 cycle the forced boss through the 5 vanilla showdowns (the 6th press clears it; press it during a round or in the shop, before the blind-select screen appears), Shift+F5 does the same through the 23 regular vanilla bosses, F6 fire the next moment (cycles big hand, close, last hand, disabled, defeat), Shift+F6 fake a run state and say the jab it gives (cycles skipped, rerolls, broke, loaded, one suit, counter, famous), F7 dump state and boss memory to the Lovely log, Shift+F7 force an idle taunt, F8 push the current final boss to its next phase (needs the avatar on the table), F9 make the current boss your nemesis (saved in the profile; a fight against a boss faked this way does not count for Nemesis Slayer) | `false` |

The dialogue, music, FX and cinematic toggles are independent. Any combination works, for example music and effects with no dialogue.

## For mod authors

Bosses added by other mods work with zero effort: a boss with no entry and no lines gets the generic lines automatically, with the boss name filled in. To give your boss its own voice, register an encounter and add localization lines. Every boss also gets the run comments and poke reactions of its personality (default bully).

```lua
if FinalBoss and FinalBoss.register_encounter then
  FinalBoss.register_encounter{blind = 'bl_mymod_boss', tier = 'full', voice = {pitch = 0.8}}
end
-- localization: misc.quips.fb_bl_mymod_boss_intro_1 = {"My line", "here"}
```

**Load order.** FinalBoss loads at priority -10, and Steamodded orders mods by priority and then id (dependencies do not change the load order). Keep your mod's priority above -10 (the default 0 is fine) so that `FinalBoss` exists when your main file runs, or register at runtime (for example from your own `calculate` or `setting_blind`) after checking that `FinalBoss` exists.

Always check that `FinalBoss` exists first so your mod still works without it. Registering the same `blind` again overwrites the earlier entry (and logs it).

### `FinalBoss.register_encounter{...}`

| Field | Meaning | Default |
|---|---|---|
| `blind` | Required. Full blind key, for example `'bl_hook'` or your prefixed key | |
| `tier` | `'auto'`, `'light'` or `'full'`. Auto means showdown bosses are full and the rest are light. An unknown value falls back to `'auto'` with a warning. A forced `'full'` on a boss that is not a showdown gets full dialogue but not the showdown stage (avatar, HP bar, cinematics and arena are showdown-only) | `'auto'` |
| `voice` | `{pitch = n}`: pitch of the vanilla voice blips for the boss's lines | `{pitch = 1.0}` |
| `personality` | `'bully'`, `'smug'`, `'killer'`, `'venom'`, `'chaos'` or `'royal'`: whose lines (jabs, reads, idle taunts, overkill, poke and grab) your boss uses when it has no line of its own, and how its chip reacts to a poke. An unknown value falls back to `'bully'` with a warning | `'bully'` |
| `music` | `nil` uses FinalBoss's showdown track. A full prefixed sound key string, or a list of them, picks from your own tracks (full tier only). See "Custom music" below | `nil` |
| `fx` | `{intro = name, defeat = name}` with names from `pulse`, `shake`, `flash`, `shatter`, `phase_shift`. An unknown name is ignored with a warning. They only run in full-tier encounters | `{intro = 'pulse', defeat = 'shatter'}` |
| `moves` | Boss moves: a table of trigger kind to recipe (see "Boss moves for your boss"). Unknown kinds, effects or targets are dropped with a warning. A boss without `moves` bursts on the `generic` trigger | `nil` |
| `death` | What plays instead of the explosion when your showdown boss dies: the name of a built-in death (`'hearts'`, `'leaves'`, `'acorn'`, `'flood'`, `'bell'`) or a recipe of `burst`, `ring`, `crack` and `sweep` steps, played from the boss's last position. Needs `fx` | `nil` |
| `phases` | Reserved, ignored. Phases are automatic for every showdown boss with cinematics on (lines `phase2` and `phase3`, the `signature` move); rule twists exist only for the 5 vanilla final bosses | `nil` |

### Boss moves for your boss

`moves` maps a trigger kind to a recipe: a list of effect steps plus an optional `sound`. FinalBoss runs the recipe from the performer (the showdown avatar, or the HUD chip) the moment the trigger happens. It never changes what your boss does; it only shows it. Your own effect code stays yours: FinalBoss only observes the vanilla `Blind` callbacks.

```lua
FinalBoss.register_encounter{blind = 'bl_mymod_boss', tier = 'full', moves = {
  hand_debuff = {{effect = 'glare', target = 'cards', line = true}, {effect = 'crack', target = 'hud_chips'},
    sound = {'magic_crumple', 1.2, 0.4}},
  card_debuff = {{effect = 'curse', target = 'cards', style = 'suit', colour = 'suit'}},
  start = {{effect = 'chain', target = 'hand'}, sound = {'cardSlide2', 0.6, 0.6}},
  signature = {{effect = 'burst', target = 'source', scale = 1.5}}, -- played big when the boss changes phase
}, death = {{effect = 'burst'}, {effect = 'ring', count = 3}, {effect = 'sweep'}}}
```

| Kind | When it plays | `target = 'cards'` is |
|---|---|---|
| `play` | `Blind:press_play` (you played a hand). With `defer = true` on the recipe the cards are read a moment later, when only the cards the boss discards are still highlighted (The Hook) | the played cards |
| `modify` | `Blind:modify_hand` changed the hand's chips or mult | none |
| `hand_debuff` | `Blind:debuff_hand` fired for a real play (it returned true, or the boss set `triggered`) | the played cards |
| `card_debuff` | cards debuffed by your blind (`debuffed_by_blind`) arrive in the hand, once per draw | the newly cursed cards |
| `flipped` | `Blind:stay_flipped` kept cards face down during a draw, once per draw. With `live = true` on the recipe the steps play while the cards are dealt: steps without `each` once at the first card, steps with `each = true` for every card | the face-down cards |
| `drawn` | `Blind:drawn_to_hand` forced a card or disabled jokers | the newly forced card and the disabled jokers |
| `set` | the moment `Blind:set_blind` applies your boss, with the counters from just before it (use with `recount`) | none |
| `start` | once, when the intro ends, or 1.5 s after the blind is set when no intro plays | none |
| `draw` | The Serpent's refill (vanilla boss only) | none |
| `joker_sold` | selling a card disabled your blind (the only move of a disabled blind) | none |
| `generic` | `Blind:wiggle`. A boss with no `moves` at all uses a plain burst here | none |
| `signature` | a showdown boss changes phase; played big (bigger effects, one more ring) | none |

Two moves of the same kind are at least 0.6 s apart, and moves wait while a phase transformation plays (at most the last two are kept). Everything needs `fx` and `moves`, and nothing plays for a disabled blind (except `joker_sold`) or after FinalBoss has stopped for the run.

Effects (`effect = ...`):

| Effect | What it does | Options |
|---|---|---|
| `burst` | a particle spray from the boss | `scale` |
| `ring` | shockwave rings from the boss, or around each target card | `count` (default 2), `scale` (rings from the boss) |
| `glare` | rings travel from the boss onto the target cards | `line = true` adds a beam |
| `fling` | the target cards jolt toward the boss with a trail | |
| `stamp` | a mark bursts onto each target card | `glyph` = `'x'`, `'hex'`, `'vine'` or `'crack'`; `scale` |
| `curse` | a persistent mark fitted to each target card, drawn like a seal, kept while the card stays debuffed by the blind | `style` (required) = `'suit'` (frame and badge of the debuffed suit), `'vine'` or `'crack'` |
| `sweep` | a band of particles washes across the target area | `time`, `scale` |
| `chain` | dark bars clamp the target area | |
| `spin` | the target cards spin | |
| `drain` | coins stream from the money counter to the boss | `amount` = a number, `'played'` (one per played card) or `'money'` (what the boss just took) |
| `crack` | the target HUD element juices, flashes and cracks | `style` = `'fill'` (a bar rises over it) or `'slam'` (a bar drops onto it first) |
| `fist` | the Raised Fist drops onto the target and slams as the hand level falls; built for The Arm (`hand_debuff`, `target = 'hud_hand_level'`) | `impact` = a sound |
| `recount` | a counter shows its old value and counts to the new one (`set` kind only; the real counter is hidden meanwhile); `cue` = steps played as the count starts (the cue still plays when the counter is missing, with nothing counted) | `value` (required) = `'hands'`, `'discards'`, `'hand_size'` or `'target'`; `hold`, `time`; `step`, `lead`, `tick` for a stepwise count; `top`, `impact` |
| `needle` | a needle stabs a counter, the cue of The Needle's recount | `impact` |
| `land` | each face-down card flashes as it reaches its slot (`live` flipped recipe, step marked `each = true`) | |
| `snake` | a snake crawls from the deck to the hand (`draw` kind) | |

Targets (`target = ...`): `source` (the boss, the default), `cards`, `played`, `hand`, `jokers`, and the HUD elements `hud_chips`, `hud_mult`, `hud_hand_name`, `hud_hand_level`, `hud_hands`, `hud_discards`, `hud_target` (the blind's score), `hud_dollars` and `hand_limit` (the "0/8" card count under the hand). A step whose target does not exist is skipped. Numeric options (`scale`, `count`, `time`, `hold`, a numeric `amount`) given as strings are converted; any other value is ignored with a warning in the log.

Colours: leave `colour` out for the boss colour, or use `'suit'` (the suit your blind debuffs) or a lower-case `G.C` name such as `'gold'` or `'blue'`. `sound = {key, pitch, volume}` names a vanilla sound on a recipe (played with the move) or on a step (played when that step runs); the pitch is multiplied by the boss's `voice.pitch`.

`death` is a built-in name or a recipe of `burst`, `ring`, `crack` and `sweep` steps (other effects need targets a death does not have). It replaces the explosion at the end of the finale and needs `fx`.

### Custom music

FinalBoss only bids for its own tracks, so a custom track must be your own `SMODS.Sound` that bids for itself. The key must contain "music" (a Steamodded requirement), and you pass its full prefixed key in the `music` field. The audio file lives in your mod's `assets/sounds/` folder.

```lua
SMODS.Sound{
  key = 'music_boss',
  path = 'boss.ogg',
  volume = 0.6,
  pitch = 1,
  select_music_track = function(self)
    local st = G.GAME and G.GAME.FinalBoss
    if st and st.encounter and st.encounter.track == self.key and not st.encounter.ended then
      return 10 -- beats vanilla boss music
    end
  end,
}
FinalBoss.register_encounter{blind = 'bl_mymod_boss', tier = 'full', music = 'MyMod_music_boss'}
```

The `FinalBoss.config.music` toggle only silences FinalBoss's own tracks; honour it in your bid if you want players to be able to turn your track off too.

**Music duck.** When a showdown boss changes phase, the music dips for about a second. FinalBoss does this with a silent companion track (`FinalBoss_music_duck`, 10 minutes long) that it briefly sets as Balatro's music override, so every other track eases toward silence and back. As a result, the duck may restart a custom track that is longer than 600 seconds or that has `sync` set. Keep your showdown tracks shorter than that and without `sync` if a restart would bother you.

### Line keys

All text lives in `misc.quips` in your mod's localization. Each moment can have as many variants as you like: write `_1`, `_2`, `_3`, ... with no gaps and FinalBoss finds them all. Variants are picked at random, never repeating the previous one when there are two or more.

| Moment | Key pattern | Scope |
|---|---|---|
| name | `fb_<blind>_name_<n>` | per boss (full intro only) |
| intro | `fb_<blind>_intro_<n>` | per boss (the threat line) |
| big hand | `fb_<blind>_big_hand_<n>` | per boss |
| close | `fb_<blind>_close_<n>` | per boss |
| last hand | `fb_<blind>_last_hand_<n>` | per boss |
| disabled | `fb_<blind>_disabled_<n>` | per boss |
| defeat | `fb_<blind>_defeat_<n>` | per boss |
| interrupted | `fb_<blind>_interrupted_<n>` | per boss (you played a hand during the intro) |
| gloat | `fb_<blind>_gloat_<n>` | per boss |
| phase 2 / phase 3 | `fb_<blind>_phase2_<n>`, `fb_<blind>_phase3_<n>` | per boss (said when a showdown boss transforms) |
| rematch (you won last time / lost last time) | `fb_<blind>_rematch_won_<n>`, `fb_<blind>_rematch_lost_<n>` | per boss |
| nemesis | `fb_nemesis_intro_<n>`, `fb_nemesis_defeat_<n>` | shared, no generic fallback (`#1#` is the boss name) |
| weak | `fb_<blind>_weak_<n>` | per boss (a hand under 10% of the requirement) |
| overkill | `fb_<blind>_overkill_<n>` | per boss, usually left to the personality (replaces the defeat line half the time) |
| idle | `fb_<blind>_idle_<n>` | per boss, usually left to the personality |
| intro jabs | `fb_<blind>_jab_<trigger>_<n>`, triggers `counter`, `skipped`, `skipped_both`, `rerolls`, `broke`, `loaded`, `onesuit`, `tinydeck`, `hugedeck`, `nojokers`, `fulljokers`, `famous` | per boss, usually left to the personality (`#2#` is the joker in `counter` and `famous`; a boss's own `counter` line is only used for its main counter: Chicot for the five vanilla final bosses, Luchador for every other boss) |
| reads | `fb_<blind>_read_<trigger>_<n>`, triggers `weakhand`, `repeat`, `discardspam`, `onecard` | per boss, usually left to the personality |
| poke, hard poke, grab | `fb_<blind>_poked_<n>`, `fb_<blind>_poked_hard_<n>`, `fb_<blind>_grabbed_<n>` | per boss, usually left to the personality |
| personality | `fb_p_<personality>_<moment>_<n>` | shared by every boss of that personality |

`<blind>` is the full blind key, for example `bl_hook`. For each moment FinalBoss tries the boss-specific key first, then the boss's personality (`fb_p_<personality>_<moment>_<n>`), then `fb_generic_<moment>_<n>`, and otherwise skips the moment. The shared nemesis lines have no generic fallback: if none exist, they are skipped. A rematch or nemesis line replaces the name line of a showdown (in light tier it replaces the boss's threat line, and a rematch line does so only about half the time). A raw key is never shown to the player. Generic lines receive the boss name as `#1#`.

Writing tips: each quip is 1 or 2 lines, and each line should stay under about 24 visible characters so it fits the speech bubble. A gloat line is spoken by Jimbo on the game-over screen, mocking you with the boss's catchphrase: write only the line itself (no "Name:" header, no quotation marks) and no placeholders. A line with a censored word (a letter followed by `*`, for example `sh*t`) plays a short bleep, so do not use asterisks for actions.

## Compatibility

- Big-number scores (Talisman) are converted to plain numbers before FinalBoss compares them, but this path has not been tested with Talisman installed.
- FinalBoss ships one Lovely patch (`lovely/timescale.toml`) for the finale's slow motion; if a game update changes its target line, the finale simply runs at normal speed.
- Boss moves observe `Blind:set_blind`, `press_play`, `modify_hand`, `debuff_hand`, `stay_flipped`, `drawn_to_hand`, `disable` and `wiggle`, and `G.FUNCS.draw_from_deck_to_hand`, by wrapping them: the original always runs first and its results are returned unchanged. A mod that replaces one of these instead of wrapping it loses the moves tied to it.
- Boss memory is stored in your Balatro profile (`profile.jkr`); resetting the profile resets it.
- Removing FinalBoss in the middle of a Verdant Leaf fight with twists on leaves the withered cards debuffed for the rest of that run.
- Mods that replace (rather than wrap) `SMODS.is_showdown_ante` or `end_round` override FinalBoss's behaviour for the showdown schedule and the round-end handling.

## Languages

English, German (`de`), Spanish Latin America (`es_419`), Spanish Spain (`es_ES`), French (`fr`), Indonesian (`id`), Italian (`it`), Japanese (`ja`), Korean (`ko`), Dutch (`nl`), Polish (`pl`), Brazilian Portuguese (`pt_BR`), Russian (`ru`), Simplified Chinese (`zh_CN`) and Traditional Chinese (`zh_TW`). That is 15 localization files. Missing keys fall back to English. Native-speaker corrections are welcome.

## Credits

- Author: SirMaiquis
- Showdown music: [Balatro (Main Theme) (Orchestral Cover)](https://www.youtube.com/watch?v=XCBC8oz8dfE) by **Adam Isiah**, used with his permission
- Built on [Steamodded](https://github.com/Steamodded/smods) and [Lovely](https://github.com/ethangreen-dev/lovely-injector)

## License

FinalBoss is released under the [MIT License](https://github.com/SirMaiquis/Balatro-FinalBoss/blob/main/LICENSE). See the [changelog](https://github.com/SirMaiquis/Balatro-FinalBoss/blob/main/CHANGELOG.md) for what changed in each release.
