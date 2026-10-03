# Changelog

## 1.1.0

Boss personality, phases and memory.

### Boss moves
- Every vanilla boss performs a visible move the moment its effect hits, with a sound at its own voice pitch. The Hook whips a chain at the two cards it discards, The Tooth bites your played cards and drains your coins, The Arm slams the Raised Fist onto your hand level, The Serpent's snake crawls in with its 3-card refill, The House sweeps the hand as the face-down cards are dealt, and so on for all 28 bosses.
- Card curses now stay on the cards: The Club, Goad, Window and Head put a suit-coloured frame and badge on each cursed card, The Plant and Verdant Leaf grow vines, The Pillar cracks. They go away when the curse does.
- Bosses that change your setup when the blind starts (The Wall, The Water, The Needle, The Manacle, Violet Vessel, Amber Acorn) play their move the moment the blind is set. You see your value go from before to after: the Wall's and the Vessel's target counts up from the normal target, The Needle stabs the hands counter and drops it one hand at a time, The Water washes the discards away, The Manacle chains your hand.
- In showdowns the move comes from the boss avatar; otherwise from the boss chip in the HUD. Bosses from other mods burst when they act.
- New setting: Boss moves (needs Screen effects).

### Final bosses
- Each final boss dies its own way: Crimson Heart shatters into hearts, Verdant Leaf blows away in a gust of leaves, Amber Acorn cracks open into shards, Violet Vessel spills purple liquid over the table, Cerulean Bell rings one last time and breaks.
- Phases: at 50% and 25% HP a final boss transforms with a short cinematic (slow motion, a flash, the music dips, its own move erupts), says a phase line and gets a new stance and a II / III marker on its HP bar. The winning hand and your last hand never transform it, and a boss that has been disabled (for example by Chicot) has no phases.
- New setting: Boss phases change the rules (off by default). Each final boss twists its own mechanic in phase II and III: Amber Acorn reshuffles your jokers, Verdant Leaf withers 1 then 2 cards with vines once you have sold a joker, Violet Vessel heals 10% of its requirement per phase (jumping to phase III heals twice), Crimson Heart disables 2 jokers per hand, Cerulean Bell forces 2 cards.

### Memory
- Bosses remember you across runs, per Balatro profile: they greet you with a rematch line depending on whether you won or lost last time. Seeded and challenge runs count too.
- Lose three times to the same boss and it becomes your nemesis: a NEMESIS title or tag, a crimson aura, its own intro and defeat lines, and a gold banner when you finally beat it.
- Ten achievements, from Rude! (interrupt a boss) to Twisted (beat all five final bosses with phase twists on). They use Steamodded's achievement system and settings.
- New setting: Boss memory. Turning it off hides the rematch lines and the nemesis presentation; your records keep counting.

### For mod authors
- `FinalBoss.register_encounter` accepts `moves` (trigger kind to a recipe of effects) and `death` (a built-in death name or a recipe); new line keys `phase2`, `phase3`, `rematch_won`, `rematch_lost`, plus the shared `fb_nemesis_intro_<n>` and `fb_nemesis_defeat_<n>`.

### Developer keys
- Shift+F5 forces the next regular boss, F7 also dumps boss memory, F8 pushes the current final boss to its next phase, F9 makes the current boss your nemesis (for testing; it does not count for Nemesis Slayer).

## 1.0.0

First release.

### Encounters
- Every boss blind talks: an intro line when it starts, reactions to your big hands, close calls and last hand, a line when it is disabled, and a defeat line.
- Showdown bosses get the full treatment: an opener, the boss name, its threat and a closer, and every reaction once per blind.
- Play a hand while the boss is still talking and you interrupt it: it snaps and says its interrupted line instead.
- Lose to a boss and Jimbo mocks you on the game-over screen with that boss's catchphrase.
- Dialogue for all 28 vanilla bosses plus generic lines for modded bosses, in 15 languages.

### Showdown stage
- Showdown music: Adam Isiah's orchestral cover of the Balatro main theme plays during showdowns (used with permission).
- Screen effects: vignette, shake, flash and shatter.
- Cinematic intro: letterbox bars, a "SHOWDOWN" title band with the boss name, and the boss avatar falling onto the table.
- Roaming boss avatar with its own HP bar, damage numbers and a white damage trail.
- Living arena: the background takes the boss's colours, pulses on each hand and darkens as the boss gets wounded; the music pitches up in the final stretch.
- The boss reacts when your score lands: it flinches, cracks and trembles as it gets wounded, and laughs off weak hits.
- Explosive finale: the winning hand slows time while the boss cracks and says its last line, then it explodes.
- Game-over gloat: the boss sits beside the game-over panel and laughs at you.

### Settings
- Independent toggles for dialogue, music, screen effects and showdown cinematics, plus intro speed and the first ante for regular-boss dialogue.
- Showdown schedule: choose a first ante and an interval to get extra showdowns, with a live ante track.
- Themed config menu in the boss palette, with a Credits tab.
- Respects Balatro's reduced motion setting: colours and flashes stay, movement goes.

### For mod authors
- `FinalBoss.register_encounter` gives your bosses their own tier, voice pitch, music and effects; modded bosses get generic lines with no setup.
