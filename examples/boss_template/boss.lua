-- FinalBoss boss template: a modded boss blind with its own voice.
--
-- Copy this file and localization/en-us.lua into your mod, then:
--   1. Rename `my_boss` to your blind's key and `mymod` to your mod's prefix (the "prefix" in your mod's
--      json). Steamodded turns `key = 'my_boss'` into the full key `bl_mymod_my_boss`, and every
--      FinalBoss line uses that full key: fb_bl_mymod_my_boss_intro_1, and so on.
--   2. Load this file from your main file (for example `assert(SMODS.load_file('boss.lua'))()`).
--      Keep your mod's priority above -10 (the default 0 is fine) so FinalBoss exists by then.
--
-- Everything works without FinalBoss installed: the check below just skips the registration.

SMODS.Blind{
  key = 'my_boss',
  atlas = 'my_atlas',          -- your blind atlas
  pos = {x = 0, y = 0},
  mult = 2,
  dollars = 5,
  boss = {min = 1},            -- add `showdown = true` for a final boss (it gets the full showdown stage)
  boss_colour = HEX('8a4fff'),
}

if FinalBoss and FinalBoss.register_encounter then
  FinalBoss.register_encounter{
    blind = 'bl_mymod_my_boss',

    -- Whose lines your boss uses for anything you don't write yourself (run jabs, comments on your play,
    -- idle taunts, consumable reactions, fear and last words, poke reactions):
    -- 'bully', 'smug', 'killer', 'venom', 'chaos' or 'royal'. Default 'bully'.
    personality = 'smug',

    -- Pitch of the voice blips while your boss talks (1.0 is normal, lower is deeper).
    voice = {pitch = 0.9},

    -- Optional: pick a different line depending on what is happening. Return the name of one of your
    -- boss's own lines (fb_bl_mymod_my_boss_<name>_N) or nothing to keep the usual line.
    -- info has: hands_left, discards_left, hands_played, dollars, chips, required, hand_type, ante,
    -- tier, showdown, won, lost, blind.
    line = function(moment, info)
      if moment == 'defeat' and info.hands_left == 0 then
        return 'defeat_lasthand'
      end
      if moment == 'intro' and info.dollars and info.dollars <= 3 then
        return 'intro_broke'
      end
    end,

    -- Optional: a visual move when your boss's effect hits (see "Boss moves for your boss" in the
    -- FinalBoss README for every trigger and effect).
    -- moves = {
    --   hand_debuff = {{effect = 'glare', target = 'cards', line = true}, sound = {'magic_crumple', 1.2, 0.4}},
    -- },
  }
end
