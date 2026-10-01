# Final Boss

Bosses talk back. Every boss blind gets a short line of dialogue when it starts, reacts to your big hands, close calls and last hand, and gloats if you lose to it. Showdown bosses go further: a roaming boss avatar with an HP bar, a cinematic intro, their own music, screen effects and a slow-motion explosive finale. You also decide when showdowns appear, so you can have a final boss every 8 antes like vanilla or much sooner.

## Requirements

- Balatro 1.0.1
- [Lovely](https://github.com/ethangreen-dev/lovely-injector) 0.9.0 or newer
- [Steamodded](https://github.com/Steamodded/smods) 26.829.0 or newer

## Install

1. Download `FinalBoss-v1.0.0.zip` from the [releases page](https://github.com/SirMaiquis/Balatro-FinalBoss/releases).
2. Extract it into `%AppData%\Balatro\Mods\` so the files end up in `%AppData%\Balatro\Mods\FinalBoss\`.
3. Start Balatro. The mod appears in the Mods menu as "Final Boss" with its own config tabs.

## Features

### Encounter tiers

Every boss blind gets a tier. The tier decides how much of the show it gets.

| | Light (regular bosses) | Full (showdowns) |
|---|---|---|
| Intro | 1 line (the boss's threat) | opener, boss name, threat, closer |
| Reactions (big hand, close call, last hand, boss disabled) | at most 1 per blind | each once per blind |
| Defeat | a line | a line and the shatter effect |
| Music | vanilla | a FinalBoss showdown track |
| Screen effects (vignette, shake, flash) | none | yes |
| Gloat when you lose | yes | yes |

Reaction triggers:

- Big hand: a single hand scores at least 30% of the blind requirement.
- Close: your running total is at least 75% of the requirement but you have not won yet.
- Last hand: you have no hands left and have not reached the requirement.
- Disabled: the boss was disabled (for example by Chicot).
- Defeat: the hand that reaches the requirement.

If several reactions would fire on the same hand, only one plays (last hand, then close, then big hand). Click the blind chip or press any key during an intro to advance to the next line; press twice quickly to skip the rest of the intro.

Regular bosses are light tier from the ante set in `min_ante` onward. Showdown bosses are always full tier. Mods can override the tier per boss (see below). An explicit `'light'` or `'full'` tier ignores `min_ante` and whether the boss is a showdown.

### Showdown stage

Showdowns (full tier) get a stage of their own. None of it appears for regular bosses.

- **Roaming boss avatar.** A large chip with the boss's own art sits on the table. It bobs, glides between a few spots that stay away from your hand and buttons, and stops while it talks. Its speech bubbles are drawn above your cards. Each hand makes it flash and flinch, a tiny hand makes it laugh, and it gets wounded: below 50% it cracks and bobs faster, below 25% it cracks more and trembles. Click it to skip an intro line.
- **HP bar and damage numbers.** Under the avatar: the boss name, a bar in the boss's colour and `remaining / max`. Each hand drops the bar at once and leaves a white trail that drains, and a damage number pops up above the avatar (big hands bigger, tiny hands small and grey). The bar flashes at 50% and 25%.
- **Cinematic intro.** Black bars slide in, a "SHOWDOWN" title card with the boss name slams in, and the avatar falls onto the table before it speaks. Press any key to jump straight to the avatar and its dialogue (a click works once the avatar has landed). Press again to advance a line; press twice quickly to skip the rest. The title card draws above your cards. Continue never replays the intro.
- **Slow-motion explosive finale.** The winning hand plays in slow motion for under a second while the avatar cracks and shows its defeat line, then it explodes into shards with a flash in the boss's colour (the flash needs `fx`). Losing to a showdown makes the avatar laugh and fade before the gloat.
- **Living arena.** The background swirl takes the boss's colours, pulses on each hand, and darkens and spins faster as the boss gets wounded (below 50%, then below 25%). In the final stretch (below 25%) the music pitches up slightly; the pitch-up needs both `fx` and `music`. Everything returns to normal when the blind ends.

Turn off the avatar side with `cinematic` (avatar, HP bar, damage numbers, intro and finale). The arena follows `fx`, and the music pitch-up in the final stretch needs both `fx` and `music`. If you quit or Continue mid-showdown the stage is rebuilt from the saved score, with no fall-in.

**Reduced motion.** With Balatro's reduced motion setting on, the stage keeps colours, flashes, the dissolve and the explosion, but drops the movement: no roaming, bob, tilt, tremble, knockback, slide/fall animations, slow motion, arena spin or arena pulses. The avatar and bars just appear, and screen shake is off (only the explosion keeps a small jiggle).

### Showdown schedule

By default, showdowns appear exactly like vanilla (ante 8, 16, ...). Turn on the schedule in the Showdowns tab and pick a first ante and an interval to get extra showdowns, for example start 4 and every 4 gives antes 4, 8, 12 and so on. The win-ante boss is always a showdown. The tab shows a live preview of the next showdown antes and warns ("Hard!") when the first showdown is before ante 4. Changes apply from the next ante's boss roll.

### Configuration

Set in the Mods menu (Final Boss, Config and Showdowns tabs). Steamodded saves your choices; `config.lua` only holds the defaults.

| Key | What it does | Default |
|---|---|---|
| `dialogue` | Boss and Jimbo lines (intros, reactions, defeat, gloat) | `true` |
| `music` | FinalBoss showdown tracks during full-tier encounters | `true` |
| `cinematic` | Showdown cinematics: avatar, HP bar, damage numbers, intro and finale. The arena follows `fx`; the music pitch-up in the final stretch needs both `fx` and `music` | `true` |
| `fx` | Screen effects: vignette, shake, flash, shatter. They only run in full-tier encounters. Also controls the boss-coloured arena of showdowns. Respects Balatro's reduced motion and screenshake settings. Under reduced motion the shake and the vignette animation are off (the vignette stays at a fixed strength), while the background flash and the defeat burst still run | `true` |
| `intro_speed` | How long each intro line stays up: 1 slow (6 s), 2 normal (4 s), 3 fast (2.5 s) | `2` |
| `min_ante` | First ante at which regular bosses get light-tier dialogue (1 to 8) | `1` |
| `showdown.enabled` | Use the extra showdown schedule | `false` |
| `showdown.start_ante` | First scheduled showdown ante (1 to 8) | `8` |
| `showdown.every` | Interval between scheduled showdowns (1 to 8) | `8` |
| `dev_mode` | Developer keys while in a run: F5 cycle the forced boss through the 5 vanilla showdowns (the 6th press clears it; press it during a round or in the shop, before the blind-select screen appears), F6 fire the next moment (cycles big hand, close, last hand, disabled, defeat), F7 dump state to the Lovely log | `false` |

The dialogue, music, FX and cinematic toggles are independent. Any combination works, for example music and effects with no dialogue.

## For mod authors

Bosses added by other mods work with zero effort: a boss with no entry and no lines gets the generic lines automatically, with the boss name filled in. To give your boss its own voice, register an encounter and add localization lines.

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
| `music` | `nil` uses the showdown pool. A full prefixed sound key string, or a list of them, picks from your own tracks (full tier only). See "Custom music" below | `nil` |
| `fx` | `{intro = name, defeat = name}` with names from `pulse`, `shake`, `flash`, `shatter`, `phase_shift`. An unknown name is ignored with a warning. They only run in full-tier encounters | `{intro = 'pulse', defeat = 'shatter'}` |
| `phases` | Reserved for a future release, ignored for now | `nil` |

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

### Line keys

All text lives in `misc.quips` in your mod's localization. Each moment can have as many variants as you like: write `_1`, `_2`, `_3`, ... with no gaps and FinalBoss finds them all. Variants are picked at random, never repeating the previous one when there are two or more.

| Moment | Key pattern | Scope |
|---|---|---|
| opener | `fb_opener_<n>` | shared (full intro only) |
| name | `fb_<blind>_name_<n>` | per boss |
| intro | `fb_<blind>_intro_<n>` | per boss (the threat line) |
| closer | `fb_closer_<n>` | shared (full intro only) |
| big hand | `fb_<blind>_big_hand_<n>` | per boss |
| close | `fb_<blind>_close_<n>` | per boss |
| last hand | `fb_<blind>_last_hand_<n>` | per boss |
| disabled | `fb_<blind>_disabled_<n>` | per boss |
| defeat | `fb_<blind>_defeat_<n>` | per boss |
| gloat | `fb_<blind>_gloat_<n>` | per boss |

`<blind>` is the full blind key, for example `bl_hook`. For each moment FinalBoss tries the boss-specific key first, then `fb_generic_<moment>_<n>`, and otherwise skips the moment. The shared `opener` and `closer` lines have no generic fallback: if none exist, they are skipped. A raw key is never shown to the player. Generic lines receive the boss name as `#1#`.

Writing tips: each quip is 1 or 2 lines, and each line should stay under about 24 visible characters so it fits the speech bubble. A per-boss gloat line is spoken by Jimbo on the game-over screen and gets no placeholders, so name the boss in the text itself.

## Compatibility

- Big-number scores (Talisman) are converted to plain numbers before FinalBoss compares them, but this path has not been playtested.
- FinalBoss ships one Lovely patch (`lovely/timescale.toml`) for the finale's slow motion; if a game update changes its target line, the finale simply runs at normal speed.
- Mods that replace (rather than wrap) `SMODS.is_showdown_ante` or `end_round` override FinalBoss's behaviour for the showdown schedule and the round-end handling.

## Languages

English, German (`de`), Spanish Latin America (`es_419`), Spanish Spain (`es_ES`), French (`fr`), Indonesian (`id`), Italian (`it`), Japanese (`ja`), Korean (`ko`), Dutch (`nl`), Polish (`pl`), Brazilian Portuguese (`pt_BR`), Russian (`ru`), Simplified Chinese (`zh_CN`) and Traditional Chinese (`zh_TW`). That is 15 localization files. Missing keys fall back to English. Native-speaker corrections are welcome.

## Credits

- Author: SirMaiquis
- Showdown music: the tracks from the original FinalBoss
- Built on [Steamodded](https://github.com/Steamodded/smods) and [Lovely](https://github.com/ethangreen-dev/lovely-injector)
