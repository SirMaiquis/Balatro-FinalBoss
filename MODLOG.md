# FinalBoss dev log

Journal of every step of the 2.0 overhaul. Newest entries at the bottom.

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
- 2026-09-30 Task 3: skeleton loads on smods 26.829.0 (log `lovely-2026.09.30-22.39.15.log`: `FinalBoss 2.0.0 loaded`, no errors/warnings, v1 `FinalBoss_music6/7` duplicate-key warnings gone). Mods-menu version check deferred to playtest.
- 2026-09-30 Task 6: config menu implemented (src/ui.lua, main.lua MODULES updated, localization/default.lua dictionary added). In-game load verified (log `lovely-2026.09.30-22.49.44.log`: `FinalBoss 2.0.0 loaded`, no errors). Config and Showdowns tabs created and wired; menu has NOT been visually verified yet, pending playtest. **IMPORTANT:** dev_mode must be turned ON in game during playtest before Task 7 checks.
- 2026-09-30 Task 7: dialogue, director (intro path), devtools (F5/F7) and hooks implemented verbatim from the brief; main.lua MODULES extended. Unit tests 52 passed. In-game load verified (log `lovely-2026.09.30-22.56.25.log`: `FinalBoss 2.0.0 loaded`, 0 error/traceback/warn lines). Gameplay (light intro, full intro, skip paths, continue, INTRO_DELAY tuning, chip-click skip) NOT verified, pending playtest. Note: smods registers its own F5 keybind (Alt+F5 restart); ours has no held_keys so Alt+F5 would also trigger the forced-boss cycle.
- 2026-09-30 Task 8: reactions (Dir.fire / on_hand_after / on_blind_disabled / on_blind_defeated), hooks routing, loss-gloat JimboQuip (src/quips.lua, `fb_gloat` localization), F6 dev key, main.lua MODULES + 'quips'. Unit tests 52 passed. In-game load verified (log `lovely-2026.09.30-23.06.46.log`: `FinalBoss 2.0.0 loaded`, JimboQuip injected, 0 error/traceback/warn lines, no fb_gloat localization warning). Fix round 1: hooks route only `context.after` (debuffed_hand fires before last_hand_score is set), gloat quip weight 1e6. Gameplay NOT verified, pending playtest. `Dir.SCORE_INCLUDES_HAND` stays `false` for now; a permanent dev-gated log line (`dev: at after chips=... delta=...`) was added to `Dir.on_hand_after` so SirMaiquis can confirm in game: if `chips=` equals the score BEFORE the hand keep false; if it already equals the score AFTER the hand, flip to true. Finding: false per smods source (better_calc.toml after-context runs before the queued chip ease); in-game re-check pending playtest.

## Smoke checklist (run before release)
- [ ] Config tab: dialogue/music/FX toggles, intro speed and min ante cycles, dev keys toggle
- [ ] Showdowns tab: schedule toggle, first ante / every N cycles, live preview, Hard! warning below ante 4, settings persist after restart
- [ ] Light-tier intro plays on a regular boss at ante >= min ante
- [ ] Full intro (opener, name, intro, closer) plays on a showdown
- [ ] Any key / clicking the blind chip advances the intro; double press skips it
- [ ] big_hand, close, last_hand each fire at most once per blind
- [ ] Light tier fires at most one reaction per blind
- [ ] Defeat line on the winning hand; shatter FX when the chip dissolves (full tier)
- [ ] Losing to a boss shows its gloat line on the game-over screen
- [ ] Showdown music plays only during full-tier encounters and survives save + continue
- [ ] Showdown schedule preview matches the boss actually rolled at the next ante
- [ ] Reduced motion: no shake, static vignette. FX toggle off: no FX at all
- [ ] A modded boss shows generic lines with its name
- [ ] Spanish (es_419) text displays correctly in game
- [ ] No FinalBoss errors in the Lovely log
