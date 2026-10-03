--- Achievements (1.1): ten Steamodded achievements (Mods -> Final Boss -> Achievements), profile-level.
--- SMODS.Achievement (smods src/game_object.lua:3845-3873) registers each as 'ach_FinalBoss_<id>'
--- and puts it in G.ACHIEVEMENTS. A.award(id) goes through vanilla check_for_unlock, whose smods
--- patch (lovely/achievements.toml:23-35) calls every unearned achievement's unlock_condition and
--- unlocks the matching one with unlock_achievement, which applies Steamodded's achievement setting
--- (Unlock-All profiles, seeded and challenge runs need "Bypass Restrictions"). Names and
--- descriptions: misc.achievement_names / misc.achievement_descriptions in localization/*.lua.
local A = {}
A.objects = {}

for i, id in ipairs(FinalBoss.logic.ACHIEVEMENTS) do
  A.objects[id] = SMODS.Achievement{
    key = id,
    order = i,
    hidden_name = false, -- the goal is readable before it is earned (smods hides names by default)
    fb_id = id,
    unlock_condition = function(self, args)
      return type(args) == 'table' and args.type == 'fb_achievement' and args.fb_id == self.fb_id
    end,
  }
end

--- An achievement is a reward on top of the game: an error here is logged and never breaks the
--- finale, the interrupt or the transformation that awarded it (nor disables the mod, unlike
--- util.guard).
function A.award(id)
  if not (G and G.GAME and id) then return end
  local ok, err = pcall(check_for_unlock, {type = 'fb_achievement', fb_id = id})
  if not ok then FinalBoss.util.log('error', ('achievements.award %s failed: %s'):format(tostring(id), tostring(err))) end
end

function A.award_all(ids)
  if type(ids) ~= 'table' then return end
  for _, id in ipairs(ids) do A.award(id) end
end

--- Award what a logic rule (logic.defeat_achievements, ...) returns for these arguments; the rule
--- runs in pcall too, so a damaged input is logged like a failed award.
function A.award_from(name, rule, ...)
  local ok, ids = pcall(rule, ...)
  if not ok then
    FinalBoss.util.log('error', ('achievements.%s failed: %s'):format(tostring(name), tostring(ids)))
    return
  end
  A.award_all(ids)
end

return A
