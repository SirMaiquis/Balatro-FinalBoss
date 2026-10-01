# FinalBoss dev log

Journal of every step of the 2.0 overhaul. Newest entries at the bottom.

## Environment
- Balatro 1.0.1 (Steam, app 2379780)
- Lovely: v0.10.0 (release zip ships `winmm.dll`, not `version.dll`; extracted to tools/out/lovely/, NOT yet copied into the Balatro folder, see Log)
- Steamodded: 26.829.0
- Repo junctioned to %AppData%\Balatro\Mods\FinalBoss
- Saves backed up to backups/2026-09-30/

## Log
- 2026-09-30 Task 0: environment set up. Steamodded 26.829.0 installed, repo junctioned, `um` CLI installed (v0.2.0). Lovely v0.10.0 downloaded but the proxy DLL copy into the Steam Balatro folder was denied by the permission system, so Lovely is not injected yet and the baseline launch with v1.0.0 was NOT run (no Lovely log exists). Manual step: copy `tools/out/lovely/winmm.dll` to `C:\Program Files (x86)\Steam\steamapps\common\Balatro\`, then run the baseline launch.

## Smoke checklist (run before release)
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
