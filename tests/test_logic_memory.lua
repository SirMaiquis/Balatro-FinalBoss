local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function has(list, id)
  for _, v in ipairs(list) do if v == id then return true end end
  return false
end

--- Memory with records key -> {losses, last_loss}.
local function mem_with(rows)
  local m = logic.new_memory()
  for key, r in pairs(rows) do
    m.bosses[key] = {fights = r[1], wins = 0, losses = r[1], last = 'lost', last_loss = r[2]}
  end
  return m
end

local function all_finals()
  local s = {}
  for _, k in ipairs(logic.FINAL_BOSSES) do s[k] = true end
  return s
end

T['new_memory: an empty profile memory'] = function()
  local m = logic.new_memory()
  eq(next(m.bosses), nil); eq(m.nemesis, nil); eq(m.loss_seq, 0)
  for _, k in ipairs({'broken', 'interrupted', 'final_defeated', 'final_defeated_twisted'}) do
    assert(type(m[k]) == 'table' and next(m[k]) == nil, k)
  end
end

T['record_result: fights, wins and losses with the last result'] = function()
  local m = logic.new_memory()
  logic.record_result(m, 'bl_hook', 'fight')
  local r = logic.record_result(m, 'bl_hook', 'won')
  eq(r.fights, 1); eq(r.wins, 1); eq(r.losses, 0); eq(r.last, 'won')
  logic.record_result(m, 'bl_hook', 'fight')
  r = logic.record_result(m, 'bl_hook', 'lost')
  eq(r.fights, 2); eq(r.losses, 1); eq(r.last, 'lost'); eq(r.last_loss, 1); eq(m.loss_seq, 1)
end

T['record_result: a loss to a broken boss clears its broken flag'] = function()
  local m = logic.new_memory()
  m.broken.bl_ox = true
  logic.record_result(m, 'bl_ox', 'lost')
  eq(m.broken.bl_ox, nil)
end

T['record_result: the nemesis is recomputed after each loss'] = function()
  local m = logic.new_memory()
  logic.record_result(m, 'bl_wall', 'lost')
  logic.record_result(m, 'bl_wall', 'lost')
  eq(m.nemesis, nil, 'two losses are not enough')
  logic.record_result(m, 'bl_wall', 'lost')
  eq(m.nemesis, 'bl_wall')
end

T['pick_nemesis: most losses, at least 3, not broken'] = function()
  local m = mem_with{bl_hook = {3, 1}, bl_ox = {5, 2}, bl_wall = {2, 3}}
  eq(logic.pick_nemesis(m.bosses, m.broken), 'bl_ox')
  m.broken.bl_ox = true
  eq(logic.pick_nemesis(m.bosses, m.broken), 'bl_hook')
  eq(logic.pick_nemesis(mem_with{bl_hook = {2, 1}}.bosses, {}), nil)
  eq(logic.pick_nemesis({}, {}), nil)
  eq(logic.pick_nemesis(nil, nil), nil)
end

T['pick_nemesis: a tie goes to the most recent loss'] = function()
  local m = mem_with{bl_hook = {4, 7}, bl_ox = {4, 9}, bl_eye = {4, 2}}
  eq(logic.pick_nemesis(m.bosses, m.broken), 'bl_ox')
end

T['break_nemesis: broken, no nemesis until the next loss'] = function()
  local m = mem_with{bl_hook = {4, 1}, bl_ox = {3, 2}}
  m.nemesis = 'bl_hook'
  logic.break_nemesis(m, 'bl_hook')
  eq(m.broken.bl_hook, true); eq(m.nemesis, nil)
  logic.record_result(m, 'bl_eye', 'lost')
  eq(m.nemesis, 'bl_ox', 'recomputed on the next loss, broken bosses skipped')
end

T['intro_plan: memory off or no history keeps the 1.0 intro'] = function()
  local full = logic.intro_plan{tier = 'full', memory = false, last = 'won', nemesis = true, roll = 0}
  eq(table.concat(full, ','), 'opener,name,intro,closer')
  local fresh = logic.intro_plan{tier = 'full', memory = true, last = nil, nemesis = false, roll = 0}
  eq(table.concat(fresh, ','), 'opener,name,intro,closer')
  eq(#logic.intro_plan{tier = 'none', memory = true, last = 'won', nemesis = true, roll = 0}, 0)
end

T['intro_plan: a final boss rematch replaces the opener'] = function()
  eq(table.concat(logic.intro_plan{tier = 'full', memory = true, last = 'won', roll = 0.99}, ','),
    'rematch_won,name,intro,closer')
  eq(table.concat(logic.intro_plan{tier = 'full', memory = true, last = 'lost', roll = 0.99}, ','),
    'rematch_lost,name,intro,closer')
end

T['intro_plan: a regular boss rematch replaces the intro on a 50% roll'] = function()
  eq(table.concat(logic.intro_plan{tier = 'light', memory = true, last = 'lost', roll = 0.3}, ','), 'rematch_lost')
  eq(table.concat(logic.intro_plan{tier = 'light', memory = true, last = 'won', roll = 0.49}, ','), 'rematch_won')
  eq(table.concat(logic.intro_plan{tier = 'light', memory = true, last = 'won', roll = 0.5}, ','), 'intro')
end

T['intro_plan: the nemesis line takes precedence'] = function()
  eq(table.concat(logic.intro_plan{tier = 'full', memory = true, last = 'lost', nemesis = true, roll = 0}, ','),
    'nemesis_intro,name,intro,closer')
  eq(table.concat(logic.intro_plan{tier = 'light', memory = true, last = 'won', nemesis = true, roll = 0.99}, ','),
    'nemesis_intro')
end

T['ACHIEVEMENTS: the ten spec ids'] = function()
  eq(#logic.ACHIEVEMENTS, 10)
  for _, id in ipairs({'fb_showdown_survivor', 'fb_clean_sweep', 'fb_rude', 'fb_no_manners', 'fb_last_laugh',
      'fb_overkill', 'fb_phase_skipper', 'fb_comeback', 'fb_nemesis_slayer', 'fb_twisted'}) do
    assert(has(logic.ACHIEVEMENTS, id), 'missing ' .. id)
  end
end

T['defeat_achievements: a final boss from full HP on the last hand'] = function()
  local ids = logic.defeat_achievements{showdown = true, start = 0, hands_left = 0, hand = 1,
    final_defeated = {bl_final_heart = true}, final_defeated_twisted = {}}
  assert(has(ids, 'fb_showdown_survivor') and has(ids, 'fb_overkill') and has(ids, 'fb_comeback'), 'survivor/overkill/comeback')
  assert(not has(ids, 'fb_clean_sweep') and not has(ids, 'fb_nemesis_slayer'), 'nothing else')
end

T['defeat_achievements: a regular boss earns only what applies'] = function()
  eq(#logic.defeat_achievements{showdown = false, start = 0, hands_left = 0, final_defeated = {}, final_defeated_twisted = {}}, 0)
  local ids = logic.defeat_achievements{showdown = false, hand = 4, laughed_hand = 3, nemesis = true,
    final_defeated = {}, final_defeated_twisted = {}}
  assert(has(ids, 'fb_last_laugh') and has(ids, 'fb_nemesis_slayer'), 'last laugh + nemesis slayer')
end

T['defeat_achievements: last laugh needs the very next hand; overkill needs full HP'] = function()
  local a = {showdown = true, start = 500, hands_left = 2, hand = 5, laughed_hand = 3,
    final_defeated = {}, final_defeated_twisted = {}}
  local ids = logic.defeat_achievements(a)
  assert(not has(ids, 'fb_last_laugh') and not has(ids, 'fb_overkill') and not has(ids, 'fb_comeback'))
  a.start = nil
  assert(not has(logic.defeat_achievements(a), 'fb_overkill'), 'unknown start is not full HP')
end

T['defeat_achievements: clean sweep and twisted need all five'] = function()
  local ids = logic.defeat_achievements{showdown = true, start = 1, hands_left = 1,
    final_defeated = all_finals(), final_defeated_twisted = all_finals()}
  assert(has(ids, 'fb_clean_sweep') and has(ids, 'fb_twisted'))
  local four = all_finals()
  four.bl_final_bell = nil
  local ids2 = logic.defeat_achievements{showdown = true, start = 1, hands_left = 1,
    final_defeated = four, final_defeated_twisted = four}
  assert(not has(ids2, 'fb_clean_sweep') and not has(ids2, 'fb_twisted'))
end

T['interrupt_achievements: rude always, no manners at 10 bosses'] = function()
  local set = {}
  for i = 1, 9 do set['bl_' .. i] = true end
  local ids = logic.interrupt_achievements(set)
  assert(has(ids, 'fb_rude') and not has(ids, 'fb_no_manners'))
  set.bl_10 = true
  assert(has(logic.interrupt_achievements(set), 'fb_no_manners'))
end

T['phase_achievements: phase I to III in one hand'] = function()
  assert(has(logic.phase_achievements(1, 3), 'fb_phase_skipper'))
  eq(#logic.phase_achievements(1, 2), 0)
  eq(#logic.phase_achievements(2, 3), 0)
end

-- Regression tests for fix round 1

T['defeat_achievements: plain showdown win has survivor but not comeback'] = function()
  local ids = logic.defeat_achievements{showdown = true, start = 500, hands_left = 2, hand = 5,
    final_defeated = {}, final_defeated_twisted = {}}
  assert(has(ids, 'fb_showdown_survivor'), 'has showdown_survivor')
  assert(not has(ids, 'fb_comeback'), 'no comeback (hands_left != 0)')
end

T['defeat_achievements: overkill requires start <= 0, not hand == 1'] = function()
  local ids = logic.defeat_achievements{showdown = true, start = 1, hands_left = 0, hand = 1,
    final_defeated = {}, final_defeated_twisted = {}}
  assert(has(ids, 'fb_showdown_survivor'), 'survivor yes')
  assert(not has(ids, 'fb_overkill'), 'overkill no (start = 1)')
  assert(has(ids, 'fb_comeback'), 'comeback yes (hands_left == 0)')
  -- Now test with start = 0
  local ids2 = logic.defeat_achievements{showdown = true, start = 0, hands_left = 2, hand = 5,
    final_defeated = {}, final_defeated_twisted = {}}
  assert(has(ids2, 'fb_overkill'), 'overkill yes (start = 0)')
  assert(not has(ids2, 'fb_comeback'), 'comeback no (hands_left = 2)')
end

T['defeat_achievements: nemesis_slayer awarded on showdown with nemesis'] = function()
  local ids = logic.defeat_achievements{showdown = true, start = 1, hands_left = 1,
    final_defeated = {}, final_defeated_twisted = {}, nemesis = true}
  assert(has(ids, 'fb_nemesis_slayer'), 'nemesis_slayer awarded on showdown')
end

T['defeat_achievements: comeback only when hands_left == 0'] = function()
  local ids1 = logic.defeat_achievements{showdown = true, start = 1, hands_left = 1,
    final_defeated = {}, final_defeated_twisted = {}}
  assert(not has(ids1, 'fb_comeback'), 'no comeback (hands_left = 1)')
  local ids2 = logic.defeat_achievements{showdown = true, start = 1, hands_left = 0,
    final_defeated = {}, final_defeated_twisted = {}}
  assert(has(ids2, 'fb_comeback'), 'comeback yes (hands_left = 0)')
end

T['intro_plan: nil roll treated as 1 (above REMATCH_CHANCE)'] = function()
  eq(table.concat(logic.intro_plan{tier = 'light', memory = true, last = 'won', roll = nil}, ','), 'intro')
end

T['intro_plan: nemesis line shown even without last'] = function()
  local ids = logic.intro_plan{tier = 'full', memory = true, last = nil, nemesis = true, roll = 0}
  eq(table.concat(ids, ','), 'nemesis_intro,name,intro,closer')
end

T['record_result: works on records with missing fields (or 0 guards)'] = function()
  local m = logic.new_memory()
  m.bosses['bl_test'] = {losses = 2}  -- missing fights, wins, last, last_loss
  logic.record_result(m, 'bl_test', 'lost')
  local r = m.bosses['bl_test']
  eq(r.losses, 3, 'losses incremented from partial record')
  eq(m.nemesis, 'bl_test', 'nemesis computed with or 0 guards on missing fields')
end

return T
