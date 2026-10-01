# Final Boss

Bosses talk back. Every boss blind gets a short line of dialogue when it starts, reacts to your big hands, close calls and last hand, and gloats if you lose to it. Showdown bosses go further: a full intro, their own music, screen effects and a shattering defeat. You also decide when showdowns appear, so you can have a final boss every 8 antes like vanilla or much sooner.

## Requirements

- Balatro 1.0.1
- [Lovely](https://github.com/ethangreen-dev/lovely-injector) 0.9.0 or newer
- [Steamodded](https://github.com/Steamodded/smods) 26.829.0 or newer

## Install

1. Download `FinalBoss-v2.0.0.zip` from the release page.
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

Regular bosses are light tier from the ante set in `min_ante` onward. Showdown bosses are always full tier. Mods can override the tier per boss (see below).

### Showdown schedule

By default, showdowns appear exactly like vanilla (ante 8, 16, ...). Turn on the schedule in the Showdowns tab and pick a first ante and an interval to get extra showdowns, for example start 4 and every 4 gives antes 4, 8, 12 and so on. The win-ante boss is always a showdown. The tab shows a live preview of the next showdown antes and warns ("Hard!") when the first showdown is before ante 4. Changes apply from the next ante's boss roll.

### Configuration

Set in the Mods menu (Final Boss, Config and Showdowns tabs). The values live in `config.lua`.

| Key | What it does | Default |
|---|---|---|
| `dialogue` | Boss and Jimbo lines (intros, reactions, defeat, gloat) | `true` |
| `music` | FinalBoss showdown tracks during full-tier encounters | `true` |
| `fx` | Screen effects: vignette, shake, flash, shatter. Respects Balatro's reduced motion and screenshake settings | `true` |
| `intro_speed` | How long each intro line stays up: 1 slow (6 s), 2 normal (4 s), 3 fast (2.5 s) | `2` |
| `min_ante` | First ante at which regular bosses get light-tier dialogue (1 to 8) | `1` |
| `showdown.enabled` | Use the extra showdown schedule | `false` |
| `showdown.start_ante` | First scheduled showdown ante (1 to 8) | `8` |
| `showdown.every` | Interval between scheduled showdowns (1 to 8) | `8` |
| `dev_mode` | Developer keys while in a run: F5 force the next showdown boss, F6 fire the next reaction, F7 dump state to the Lovely log | `false` |

The dialogue, music and FX toggles are independent. Any combination works, for example music and effects with no dialogue.

## For mod authors

Bosses added by other mods work with zero effort: a boss with no entry and no lines gets the generic lines automatically, with the boss name filled in. To give your boss its own voice, register an encounter and add localization lines.

```lua
if FinalBoss and FinalBoss.register_encounter then
  FinalBoss.register_encounter{blind = 'bl_mymod_boss', tier = 'full', voice = {pitch = 0.8}}
end
-- localization: misc.quips.fb_bl_mymod_boss_intro_1 = {"My line", "here"}
```

Always check that `FinalBoss` exists first so your mod still works without it. Registering the same `blind` again overwrites the earlier entry (and logs it).

### `FinalBoss.register_encounter{...}`

| Field | Meaning | Default |
|---|---|---|
| `blind` | Required. Full blind key, for example `'bl_hook'` or your prefixed key | |
| `tier` | `'auto'`, `'light'` or `'full'`. Auto means showdown bosses are full and the rest are light. An unknown value falls back to `'auto'` with a warning | `'auto'` |
| `voice` | `{pitch = n}`: pitch of the vanilla voice blips for the boss's lines | `{pitch = 1.0}` |
| `music` | `nil` uses the showdown pool. A sound key string, or a list of keys, picks from your own tracks (full tier only) | `nil` |
| `fx` | `{intro = name, defeat = name}` with names from `pulse`, `shake`, `flash`, `shatter`, `phase_shift`. An unknown name is ignored with a warning | `{intro = 'pulse', defeat = 'shatter'}` |
| `phases` | Reserved for a future release, ignored for now | `nil` |

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

`<blind>` is the full blind key, for example `bl_hook`. For each moment FinalBoss tries the boss-specific key first, then `fb_generic_<moment>_<n>`, and otherwise skips the moment. A raw key is never shown to the player. Generic lines receive the boss name as `#1#`.

Writing tips: each quip is 1 or 2 lines, and each line should stay under about 24 visible characters so it fits the speech bubble. A per-boss gloat line is spoken by Jimbo on the game-over screen and gets no placeholders, so name the boss in the text itself.

## Languages

English, German (`de`), Spanish Latin America (`es_419`), Spanish Spain (`es_ES`), French (`fr`), Indonesian (`id`), Italian (`it`), Japanese (`ja`), Korean (`ko`), Dutch (`nl`), Polish (`pl`), Brazilian Portuguese (`pt_BR`), Russian (`ru`), Simplified Chinese (`zh_CN`) and Traditional Chinese (`zh_TW`). That is 15 localization files. Missing keys fall back to English. Native-speaker corrections are welcome.

## Credits

- Author: SirMaiquis
- Showdown music: the tracks from FinalBoss v1
- Built on [Steamodded](https://github.com/Steamodded/smods) and [Lovely](https://github.com/ethangreen-dev/lovely-injector)
