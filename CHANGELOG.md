# Changelog

## 1.3.1

### New
- Four new achievements for poking and grabbing bosses: Boss Collector, Don't Touch Me, Hostage and Kidnapper.

### Fixes
- Intro jabs read your run as you arrived, so a boss that takes your money when the blind starts no longer calls you broke.
- Works with big-number and custom scoring mods (like Amulet): winning hands are no longer mistaken for weak ones.

### For mod authors
- A boss template to start from: `examples/boss_template` has a boss file and a localization file with every moment, ready to rename and fill in (also included in the download).
- `register_encounter` accepts `line = function(moment, info)`: return the name of one of your boss's own lines (`fb_<blind>_<name>_<n>`) to say it instead of the usual one, for example a different defeat line on the last hand. `info` carries the live fight (hands and discards left, money, score, requirement, ante, tier and more). Returning nothing, a name with no lines, or an error keeps the usual line. See "Picking lines by situation" in the README.

## 1.3.0

Bosses react to your tricks.

### The fear scale
- The boss watches your score climb, card by card. Past 2×, 10× and 100× the requirement it gets sore, scared, then terrified, and says so on the spot; a higher tier replaces the bubble.
- At 10× its chip (or the showdown avatar) starts to tremble; at 100× the screen shakes and flashes and the boss cowers. The showdown avatar shakes harder at higher tiers.
- A fear line replaces the defeat line. A nemesis keeps its own defeat line.
- This replaces the old overkill line.

### Tiered deaths
- 2×: a short slow motion. A regular boss's chip cracks and shatters; a showdown boss's own death is amplified.
- 10×: a longer slow motion and a flash. The chip explodes into pieces; a showdown boss dies at full intensity.
- 100×: the longest freeze, in which the boss says its last words, then the biggest explosion. A nemesis says its own defeat line instead.
- Reduced motion and the Screen effects setting are respected: reduced motion keeps only the flashes, and with screen effects off there is no shake or flash.

### Consumables used mid-fight
- Use a tarot, spectral or planet during a boss fight and the boss answers, naming the card. Tarots and spectrals are grouped by what they do.
- Planets read your hand history: level up your most played hand and the boss mocks the new level; level up a hand you never play and it calls it a waste.
- The Wheel of Fortune reacts to a hit, a miss, or rigged odds (for example with Oops! All 6s).
- The same card gets a line once per turn, quick spam is collapsed, and the line comes after the card's effect has played out.

### Jokers created mid-fight
- A joker created during the fight gets one line per blind, naming it.
- Judgement, The Soul, Wraith and Ankh say the joker line instead of their card line.
- Riff-raff's jokers arrive during the intro, so they get no line.

### Combo jabs
- About ten famous joker pairs can be called out at the intro, such as Blueprint & Brainstorm or Baron & Mime.

### Fixes
- Bosses keep talking after Hieroglyph or Petroglyph send the run back to ante 0 or below.
- Both Spanish translations are rewritten, and the other languages are updated.

### For mod authors
- The `overkill` keys are removed. Use `fear_1`, `fear_2`, `fear_3` and `last_words` instead.
- New moments: `fear_1..3`, `last_words`, `used_tarot_<group>`, `used_spectral_<group>`, `used_tarot_wheel_hit`, `used_tarot_wheel_miss`, `used_tarot_wheel_rigged`, `used_planet_main`, `used_planet_waste`, the `used_tarot`, `used_spectral` and `used_planet` fallbacks, `joker_created` and `jab_combo`. See the README for the groups.
- Placeholders: `#2#` now also names the card, the planet's hand, the new joker, or both jokers of a combo ("A & B"); the new `#3#` is a planet's new hand level.

### Developer keys
- The Shift+F6 jab cycle now includes `combo`.

## 1.2.0

Savage bosses that read your run.

### A new voice
- Every boss line is rewritten: bosses trash-talk now, each in its own personality (bully, smug genius, cold killer, sweet venom, chaos gremlin, royal snob), in all 15 languages.
- Intros are threats, not rule explanations (the game already shows the rule).
- Shorter showdown intros: two lines, the boss's name (or its rematch or nemesis line), then its threat.
- More variety where lines repeat most: three intros, three big-hand reactions and three gloats per boss.
- Swearing is censored ("sh*t") and gets a short TV-style bleep. No slurs, nothing about real people or groups.

### Bosses read your run
- Intro jabs: about one intro in three, the boss's threat is replaced by a jab at how you got here: skipped blinds, rerolling the shop, being broke or loaded, a one-suit deck, a tiny or huge deck, no jokers or a full row, a famous joker. Never the same jab twice in a row. Counter jokers are always called out: bosses know your Chicot, Luchador, Matador and Mr. Bones, and every vanilla boss has its own line for its main counter.
- During the fight: comments on weak hands, the same hand three times in a row, burning every discard early and one-card plays. A weak hit now gets a line (final bosses laugh first). Winning with twice the score needed gets an overkill line instead of the defeat line half the time.
- Idle taunts: sit on your hand for 25 seconds and the boss gets impatient (twice per blind at most).
- Regular bosses talk more but never crowd you: at most one line every other hand, and at most one comment on your play per blind. Their last-hand taunt, disabled line and defeat line always come.
- Final bosses make at most three comments on your play per blind, never on two hands in a row.
- The last-hand taunt now comes when you are down to your final hand, before you play it.
- Boss dialogue off silences all of it.

### Poke the boss
- Click the boss chip during a boss fight and it jiggles and says something. Click it three times within two seconds for a harsher line. Drag it and it springs back after about a second, even while you hold it, and the boss reacts as it returns.
- Each personality takes it its own way: the bully is furious, the killer goes cold, the royal is offended, the smug genius talks down to you, sweet venom turns poisonous, the chaos gremlin laughs.
- In a showdown, poke the roaming boss avatar. Not during intros, cinematics, menus or pauses, once the winning hand is in, nor before the ante where boss dialogue starts. With Boss dialogue off the boss still reacts, silently.

### For mod authors
- `register_encounter` accepts `personality` (`bully`, `smug`, `killer`, `venom`, `chaos`, `royal`; default `bully`): your boss gets that personality's run comments and poke reactions without writing any line.
- Lines now resolve boss, then personality (`fb_p_<personality>_<moment>_<n>`), then generic. New moments: `weak`, `overkill`, `idle`, `jab_*`, `read_*`, `poked`, `poked_hard`, `grabbed`.
- The shared showdown lines `fb_opener_<n>` and `fb_closer_<n>` are no longer used; a rematch or nemesis line now replaces the boss's name line.

### Developer keys
- Shift+F6 fakes a run state and says the jab it gives (cycles skipped, rerolls, broke, loaded, one suit, counter, famous); Shift+F7 forces an idle taunt.

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
- Phases: at 50% and 25% HP a final boss transforms with a short cinematic (slow motion, a flash, the music dips, its own move erupts), says a phase line and gets a new stance and a II / III marker on its HP bar. The winning hand and your last hand never transform it, and a boss that has been disabled (for example by Chicot) has no phases: it gets angry at 50% and 25% instead and says its disabled line again.
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
