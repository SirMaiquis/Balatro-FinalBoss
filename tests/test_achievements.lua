-- achievements.lua under stubs (no game): registration, awarding through check_for_unlock, errors.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- Fresh achievements module. SMODS.Achievement records each definition (keyed like smods:
--- 'ach_FinalBoss_<key>'); check_for_unlock runs every unearned unlock_condition like smods' patch
--- (lovely/achievements.toml:23-35) and records the unlocks in ctx.unlocked.
local function setup(opts)
  opts = opts or {}
  local ctx = {defs = {}, unlocked = {}, logs = {}, checks = 0}
  local function log(msg) ctx.logs[#ctx.logs + 1] = msg end
  _G.sendInfoMessage, _G.sendWarnMessage, _G.sendErrorMessage, _G.sendDebugMessage = log, log, log, log
  _G.G = {GAME = (not opts.no_game) and {} or nil}
  _G.SMODS = {Achievement = function(def)
    def.key = 'ach_FinalBoss_' .. def.key
    ctx.defs[#ctx.defs + 1] = def
    return def
  end}
  _G.check_for_unlock = function(args)
    ctx.checks = ctx.checks + 1
    if opts.check_fails then error('boom') end
    for _, def in ipairs(ctx.defs) do
      if not def.earned and def:unlock_condition(args) then
        def.earned = true
        ctx.unlocked[#ctx.unlocked + 1] = def.key
      end
    end
  end
  package.loaded['src.util'] = nil
  package.loaded['src.logic'] = nil
  _G.FinalBoss = {util = require('src.util'), logic = require('src.logic')}
  package.loaded['src.achievements'] = nil
  ctx.A = require('src.achievements')
  return ctx
end

T['achievements: ten registered in logic order, names readable before they are earned'] = function()
  local ctx = setup()
  local ids = FinalBoss.logic.ACHIEVEMENTS
  eq(#ctx.defs, #ids, 'count')
  for i, id in ipairs(ids) do
    local def = ctx.defs[i]
    eq(def.key, 'ach_FinalBoss_' .. id); eq(def.order, i); eq(def.hidden_name, false)
    eq(ctx.A.objects[id], def, 'objects[' .. id .. ']')
  end
end

T['achievements: award unlocks exactly that one, once'] = function()
  local ctx = setup()
  ctx.A.award('fb_rude')
  eq(#ctx.unlocked, 1); eq(ctx.unlocked[1], 'ach_FinalBoss_fb_rude')
  ctx.A.award('fb_rude')
  eq(#ctx.unlocked, 1, 'an earned one is not unlocked again')
  ctx.A.award_all({'fb_comeback', 'fb_overkill'})
  eq(#ctx.unlocked, 3)
end

T['achievements: other unlock checks never unlock them'] = function()
  local ctx = setup()
  check_for_unlock({type = 'win'})
  check_for_unlock({type = 'fb_achievement'})
  check_for_unlock({type = 'fb_achievement', fb_id = 'nope'})
  eq(#ctx.unlocked, 0)
end

T['achievements: award_from awards what the rule returns'] = function()
  local ctx = setup()
  ctx.A.award_from('phase', FinalBoss.logic.phase_achievements, 1, 3)
  eq(ctx.unlocked[1], 'ach_FinalBoss_fb_phase_skipper')
  ctx.A.award_from('phase', FinalBoss.logic.phase_achievements, 1, 2)
  eq(#ctx.unlocked, 1)
end

T['achievements: errors are logged, never raised'] = function()
  local ctx = setup({check_fails = true})
  ctx.A.award('fb_rude')
  eq(#ctx.logs, 1, 'failed award logged')
  ctx.A.award_from('defeat', function() error('bad input') end)
  eq(#ctx.logs, 2, 'failed rule logged')
  ctx.A.award_all(nil)
end

T['achievements: nothing is awarded outside a game'] = function()
  local ctx = setup({no_game = true})
  ctx.A.award('fb_rude')
  eq(ctx.checks, 0)
end

return T
