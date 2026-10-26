-- FinalBoss lines for the template boss (bl_mymod_my_boss).
--
-- `misc` sits next to `descriptions`, not inside it, or Balatro never loads the quips.
-- Each line is 1 or 2 strings of about 24 characters (the speech bubble fits 2 short lines).
-- Add variants with _2, _3, ... (no gaps): FinalBoss picks one at random and never repeats the last.
-- Delete any line you don't want: that moment falls back to your boss's personality.
-- #1# is your boss's name.
return {
  descriptions = {
    Blind = {
      bl_mymod_my_boss = {
        name = 'The Template',
        text = {'Your boss effect here'},
      },
    },
  },
  misc = {
    quips = {
      -- Showdown bosses only: the name reveal in the intro
      fb_bl_mymod_my_boss_name_1 = {"I am The Template.", "Remember it."},

      -- The intro threat (hint at your effect, don't explain it)
      fb_bl_mymod_my_boss_intro_1 = {"Nice run.", "Shame about the end."},
      fb_bl_mymod_my_boss_intro_2 = {"Oh, you again?", "This won't take long."},

      -- During the fight
      fb_bl_mymod_my_boss_big_hand_1 = {"Lucky hit.", "Won't happen twice."},   -- one hand scored 30%+
      fb_bl_mymod_my_boss_close_1 = {"Wait, wait...", "Stay back!"},             -- your total passed 75%
      fb_bl_mymod_my_boss_last_hand_1 = {"Last hand.", "Make it count."},       -- you're down to your last hand
      fb_bl_mymod_my_boss_weak_1 = {"That's it?", "Pathetic."},                 -- a hand under 10%
      fb_bl_mymod_my_boss_interrupted_1 = {"Rude.", "I was talking."},          -- you played during the intro
      fb_bl_mymod_my_boss_disabled_1 = {"My power!", "You'll pay for that."},   -- the boss got disabled

      -- End of the fight
      fb_bl_mymod_my_boss_defeat_1 = {"This isn't over!"},                      -- you won
      fb_bl_mymod_my_boss_gloat_1 = {"Told you so."},                           -- you lost (Jimbo says it)

      -- Boss memory: the intro when you won or lost against this boss last time
      fb_bl_mymod_my_boss_rematch_won_1 = {"You again.", "Not so lucky today."},
      fb_bl_mymod_my_boss_rematch_lost_1 = {"Back for more?", "Sweet."},

      -- Showdown bosses only: the transformations at 50% and 25% HP
      fb_bl_mymod_my_boss_phase2_1 = {"Enough games."},
      fb_bl_mymod_my_boss_phase3_1 = {"NOW I'M ANGRY!"},

      -- Lines picked by the `line` function in boss.lua
      fb_bl_mymod_my_boss_defeat_lasthand_1 = {"Last hand?", "Lucky."},
      fb_bl_mymod_my_boss_intro_broke_1 = {"Broke already?", "How sad."},

      -- Optional, usually left to the personality (see "Line keys" in the FinalBoss README):
      -- fb_bl_mymod_my_boss_jab_broke_1, fb_bl_mymod_my_boss_read_onecard_1, fb_bl_mymod_my_boss_idle_1,
      -- fb_bl_mymod_my_boss_poked_1, fb_bl_mymod_my_boss_fear_1_1, fb_bl_mymod_my_boss_last_words_1, ...
    },
  },
}
