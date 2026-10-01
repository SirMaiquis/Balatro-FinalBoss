# FinalBoss dev log

Journal of every step of the overhaul (developed under the working label 2.0, released as 1.0.0). Newest entries at the bottom.

## Environment
- Balatro 1.0.1 (Steam, app 2379780)
- Lovely: v0.10.0 (release zip ships `winmm.dll`, not `version.dll`; installed in the Steam Balatro folder)
- `um` CLI (universal-modder 0.2.0) lives in `~/.local/bin` (uv tool dir); add it to PATH in new shells
- Steamodded: 26.829.0
- Repo junctioned to %AppData%\Balatro\Mods\FinalBoss
- Saves backed up to backups/2026-09-30/

## Log
- 2026-09-30 Task 0: environment set up. Steamodded 26.829.0 installed, repo junctioned, `um` CLI installed (v0.2.0). Lovely v0.10.0 (`winmm.dll`) copied into the Balatro folder by the controller after the first attempt was denied.
- 2026-09-30 Task 0 baseline launch with v1.0.0 (log `lovely-2026.09.30-22.28.15.log`): Lovely injected, `SMODS :: Steamodded v26.829.0` loaded, `DefaultLogger :: Launching Final Boss!` printed, all object injections ran. No ERROR, traceback or Lua error lines. Only warnings: `Sound :: Object FinalBoss_music6 has the same key as an existing object, not registering` and the same for `FinalBoss_music7` (duplicate sound keys in v1.0.0). Also `Failed to connect to the debug server` (harmless, no debug server running). Game killed after ~40 s; the menu was not inspected visually.
- 2026-09-30 Task 3: skeleton loads on smods 26.829.0 (log `lovely-2026.09.30-22.39.15.log`: `FinalBoss 2.0.0 loaded` (released as 1.0.0), no errors/warnings, v1 `FinalBoss_music6/7` duplicate-key warnings gone). Mods-menu version check deferred to playtest.
- 2026-09-30 Task 6: config menu implemented (src/ui.lua, main.lua MODULES updated, localization/default.lua dictionary added). In-game load verified (log `lovely-2026.09.30-22.49.44.log`: `FinalBoss 2.0.0 loaded` (released as 1.0.0), no errors). Config and Showdowns tabs created and wired; menu has NOT been visually verified yet, pending playtest. **IMPORTANT:** dev_mode must be turned ON in game during playtest before Task 7 checks.
- 2026-09-30 Task 7: dialogue, director (intro path), devtools (F5/F7) and hooks implemented verbatim from the brief; main.lua MODULES extended. Unit tests 52 passed. In-game load verified (log `lovely-2026.09.30-22.56.25.log`: `FinalBoss 2.0.0 loaded` (released as 1.0.0), 0 error/traceback/warn lines). Gameplay (light intro, full intro, skip paths, continue, INTRO_DELAY tuning, chip-click skip) NOT verified, pending playtest. Note: smods registers its own F5 keybind (Alt+F5 restart); ours has no held_keys so Alt+F5 would also trigger the forced-boss cycle.
- 2026-09-30 Task 8: reactions (Dir.fire / on_hand_after / on_blind_disabled / on_blind_defeated), hooks routing, loss-gloat JimboQuip (src/quips.lua, `fb_gloat` localization), F6 dev key, main.lua MODULES + 'quips'. Unit tests 52 passed. In-game load verified (log `lovely-2026.09.30-23.06.46.log`: `FinalBoss 2.0.0 loaded` (released as 1.0.0), JimboQuip injected, 0 error/traceback/warn lines, no fb_gloat localization warning). Fix round 1: hooks route only `context.after` (debuffed_hand fires before last_hand_score is set), gloat quip weight 1e6. Gameplay NOT verified, pending playtest. `Dir.SCORE_INCLUDES_HAND` stays `false` for now; a permanent dev-gated log line (`dev: at after chips=... delta=...`) was added to `Dir.on_hand_after` so SirMaiquis can confirm in game: if `chips=` equals the score BEFORE the hand keep false; if it already equals the score AFTER the hand, flip to true. Finding: false per smods source (better_calc.toml after-context runs before the queued chip ease); in-game re-check pending playtest.
- 2026-09-30 Task 9: showdown schedule hook added (src/hooks.lua); wraps `SMODS.is_showdown_ante` to apply `FinalBoss.logic.is_extra_showdown` schedule when enabled. Unit tests 52 passed. In-game load and gameplay verification pending playtest.
- 2026-09-30 Task 10: music module (src/music.lua); showdown_1.ogg and showdown_2.ogg assets renamed from music6/7. Bid-only during full-tier encounters; phase recording for M3. Unit tests 52 passed. In-game load check and gameplay verification pending playtest.
- 2026-09-30 Task 11: fx module + vignette shader (assets/shaders/vignette.fs, src/fx.lua: SMODS.Shader + SMODS.ScreenShader vignette, shake, flash, shatter, phase_shift). Unit tests 52 passed. Load check (shader compile) and gameplay pending. Source-checked against smods/vanilla; two adaptations: vignette eases are cancelled by stop() via a gen check in the ease func, and the flash's background restore is unconditional (not cancelled by stop()) and restores to neutral after a defeat.
- 2026-09-30 Task 11 fix round 1: `FinalBoss.fx.reset()` wired to a `Game:delete_run` wrapper in hooks.lua (vignette no longer survives leaving a run), vignette ScreenShader `order = 1`, flash-restore failures logged. Tests 52 passed. Load check and gameplay still pending.
- 2026-09-30 Task 12: `tools/check_loc.py` added (keys, tag balance, `#n#` placeholders vs default.lua); es_419 and es_ES fully rewritten (all 16 dictionary + all quip keys). RED run: 600 problems; GREEN run `check_loc.py es_419 es_ES default`: 3 files checked, 0 problems. Unit tests 52 passed. Official terms from the game's own es_419/es_ES: Ante = "apuesta inicial", boss names `descriptions.Blind` (identical in both), Joker = "comodín", debuff = "debilitar", Spades = "espadas" (es_419) / "picas" (es_ES). "Showdown" has no official term in the game: used "enfrentamiento". SirMaiquis's review of the Spanish text is DEFERRED to the next checkpoint. In-game check (accents, n-tilde, inverted marks, both config tabs, intro + F6 reactions in Español LatAm) NOT done, pending playtest. Other 12 localization files still fail the checker until Task 13.
- 2026-10-01 Task 13: remaining 12 languages written in full (de new; fr, id, it, ja, ko, nl, pl, pt_BR, ru, zh_CN, zh_TW rewritten from the v1 stub), one commit each. `check_loc.py` over all 15 files: 0 problems; unit tests 52 passed. Official boss names / Ante term taken from the game's own localization per language (Ante: de/id/it/nl "Ante", fr "Mise initiale", pl "Wejście", pt_BR "Aposta", ru "Ante" (Анте), ja アンティ, ko 앤티, zh 底注). Line lengths scripted: non-CJK <= 26, CJK <= 12 visible chars. Notes: ko official names reuse "술잔" for both Violet Vessel and Crimson Heart and "행성" (planet) for The Plant; zh_TW official The Plant = "星球"; used as-is. "Showdown" has no official term; used a natural local word per language. In-game check (ja/ru font rendering, bubble fit) NOT done, pending playtest. Native-speaker review of puns recommended for all 12.

- 2026-10-01 Playtest A + B passed (SirMaiquis). Score read point confirmed in game: "dev: at after chips=0 delta=8910" on the first hand → SCORE_INCLUDES_HAND = false is correct.
- 2026-10-01 Load check after Tasks 9–13: FinalBoss 2.0.0 loaded (released as 1.0.0); Shader, ScreenShader, Sound, JimboQuip, Keybind injected; no errors.
- 2026-10-01 Task 11b: screen effects made stronger and longer after playtest feedback (values in commit).
- 2026-10-01 Task 14 skipped by SirMaiquis (ships with the 2 existing tracks, no custom icon). Task 14b: applied all reviewer-flagged EN/ES line fixes.
- 2026-10-01 Task 15: README written; tests 52 passed, check_loc 15 files 0 problems; `um publish check .` 0 failures (8 warnings, all absolute-path mentions in git-ignored planning docs, not shipped). Release zip built (`dist/FinalBoss-v2.0.0.zip` (released as 1.0.0), 41 files, runtime files only, git-ignored) and load-tested as a real install (junction swapped for the extracted zip): log `lovely-2026.10.01-01.50.49.log`: `FinalBoss 2.0.0 loaded` (released as 1.0.0), 0 error/traceback/warn lines. Junction restored afterwards. Still open: modded-boss generic-lines check, CJK/Russian render check, look of the stronger FX. Tag v2.0.0 not created yet (released as 1.0.0).
- 2026-10-01 Task 15 fix round 1: manifest `priority` 20 -> -10 so mods at default priority 0 see `FinalBoss` when their main file runs (smods loads ascending priority); README documents load order, custom music (own `SMODS.Sound` that bids itself) and several clarifications; releases link added. Zip rebuilt from new HEAD.
- 2026-10-01 Version relabelled 1.0.0 (never released). Added "Showdown cinematics" setting and fb_cfg_cinematic / fb_showdown_title keys in all 15 languages.

## Smoke checklist (run before release)
- [x] Config tab: dialogue/music/FX toggles, intro speed and min ante cycles, dev keys toggle
- [x] Showdowns tab: schedule toggle, first ante / every N cycles, live preview, Hard! warning below ante 4, settings persist after restart
- [x] Light-tier intro plays on a regular boss at ante >= min ante
- [x] Full intro (opener, name, intro, closer) plays on a showdown
- [x] Any key / clicking the blind chip advances the intro; double press skips it
- [x] big_hand, close, last_hand each fire at most once per blind
- [x] Light tier fires at most one reaction per blind
- [x] Defeat line on the winning hand; shatter FX when the chip dissolves (full tier)
- [x] Losing to a boss shows its gloat line on the game-over screen
- [x] Showdown music plays only during full-tier encounters and survives save + continue
- [x] Showdown schedule preview matches the boss actually rolled at the next ante
- [x] Reduced motion: no shake, static vignette. FX toggle off: no FX at all
- [ ] A modded boss shows generic lines with its name
- [x] Spanish (es_419) text displays correctly in game
- [ ] Japanese, Korean, Chinese (CN/TW) and Russian text render in the game font (no tofu) and fit the bubble; Polish/German/French diacritics show
- [x] No FinalBoss errors in the Lovely log
- 2026-10-01 Final review fixes: vignette cleared on guard failure, Talisman number conversion, README load order, dialogue reset on run teardown, registry input checks, reduced-motion static vignette 0.3, Chicot skips intro.
- 2026-10-01 Stage skeleton: lovely/timescale.toml, stub modules, director tick/reset_stage, Game:update wrap.
- 2026-10-01 Living arena: boss-coloured swirl for showdowns, darker/faster by wound stage, hit pulse, final-stretch pitch.
- 2026-10-01 Roaming boss avatar for showdowns; speech bubbles come from it.
- 2026-10-01 Boss HP bar under the avatar with damage trail and damage numbers.
- 2026-10-01 Cinematic showdown intro: letterbox, SHOWDOWN title card, avatar fall-in, skippable.
- 2026-10-01 Explosive showdown finale (slow motion via lovely/timescale.toml) and game-over exit.
- 2026-10-01 README updated for 1.0.0; release zip FinalBoss-v1.0.0.zip built.
- 2026-10-01 Final review fixes: no double defeat effect after the finale, live HP at avatar spawn, trail drain over 0.35 s, vignette/arena revert at the finale's end, Continue/toggle fixes.
- 2026-10-01 Playtest C feedback: HUD chip steps out while the avatar is on the table; HP bar rebuilt on vanilla progress bars (pixel style) and drawn under cards.
- 2026-10-01 Playtest D feedback: title band with slam and longer hold; avatar perches in open space, home ringside (right of the play area, above the deck), parked there during scoring; boss reacts when the score lands.
- 2026-10-01 Laugh feedback: weak hit under 10% of boss HP; hit first, then a distinct laugh (one syllable, ha-ha rhythm, hops and tilt); the line waits for the laugh.
