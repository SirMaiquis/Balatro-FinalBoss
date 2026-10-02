# Changelog

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
