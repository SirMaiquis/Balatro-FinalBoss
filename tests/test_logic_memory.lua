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
  eq(table.concat(full, ','), 'name,intro')
  local fresh = logic.intro_plan{tier = 'full', memory = true, last = nil, nemesis = false, roll = 0}
  eq(table.concat(fresh, ','), 'name,intro')
  eq(#logic.intro_plan{tier = 'none', memory = true, last = 'won', nemesis = true, roll = 0}, 0)
end

T['intro_plan: a final boss rematch replaces the name line'] = function()
  eq(table.concat(logic.intro_plan{tier = 'full', memory = true, last = 'won', roll = 0.99}, ','),
    'rematch_won,intro')
  eq(table.concat(logic.intro_plan{tier = 'full', memory = true, last = 'lost', roll = 0.99}, ','),
    'rematch_lost,intro')
end

T['intro_plan: a regular boss rematch replaces the intro on a 50% roll'] = function()
  eq(table.concat(logic.intro_plan{tier = 'light', memory = true, last = 'lost', roll = 0.3}, ','), 'rematch_lost')
  eq(table.concat(logic.intro_plan{tier = 'light', memory = true, last = 'won', roll = 0.49}, ','), 'rematch_won')
  eq(table.concat(logic.intro_plan{tier = 'light', memory = true, last = 'won', roll = 0.5}, ','), 'intro')
end

T['intro_plan: the nemesis line takes precedence'] = function()
  eq(table.concat(logic.intro_plan{tier = 'full', memory = true, last = 'lost', nemesis = true, roll = 0}, ','),
    'nemesis_intro,intro')
  eq(table.concat(logic.intro_plan{tier = 'light', memory = true, last = 'won', nemesis = true, roll = 0.99}, ','),
    'nemesis_intro')
end

T['ACHIEVEMENTS: fourteen achievements'] = function()
  eq(#logic.ACHIEVEMENTS, 14)
  for _, id in ipairs({'fb_showdown_survivor', 'fb_clean_sweep', 'fb_rude', 'fb_no_manners', 'fb_last_laugh',
      'fb_overkill', 'fb_phase_skipper', 'fb_comeback', 'fb_nemesis_slayer', 'fb_twisted',
      'fb_boss_collector', 'fb_dont_touch_me', 'fb_hostage', 'fb_kidnapper'}) do
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
  eq(table.concat(ids, ','), 'nemesis_intro,intro')
end

T['intro_plan: the name line falls back to the generic name line'] = function()
  local both = function(p) return (p == 'fb_generic_name' or p == 'fb_bl_hook_name') and 3 or 0 end
  eq(logic.resolve_prefix('bl_hook', 'name', both), 'fb_bl_hook_name', 'the boss name line first')
  local generic = function(p) return p == 'fb_generic_name' and 3 or 0 end
  local p, is_generic = logic.resolve_prefix('bl_mymod_boss', 'name', generic)
  eq(p, 'fb_generic_name'); eq(is_generic, true)
  eq(logic.SHARED_MOMENTS.generic_name, nil); eq(logic.SHARED_MOMENTS.opener, nil)
  eq(logic.SHARED_MOMENTS.closer, nil); eq(logic.SHARED_MOMENTS.nemesis_intro, true)
end

T['record_result: works on records with missing fields (or 0 guards)'] = function()
  local m = logic.new_memory()
  m.bosses['bl_test'] = {losses = 2}  -- missing fights, wins, last, last_loss
  logic.record_result(m, 'bl_test', 'lost')
  local r = m.bosses['bl_test']
  eq(r.losses, 3, 'losses incremented from partial record')
  eq(m.nemesis, 'bl_test', 'nemesis computed with or 0 guards on missing fields')
end

-- 1.3.1 poke and grab achievements ----------------------------------------------------------------

local function set_of(list)
  local s = {}
  for _, k in ipairs(list) do s[k] = true end
  return s
end

T['new_memory: empty poked and grabbed_finals sets'] = function()
  local m = logic.new_memory()
  assert(type(m.poked) == 'table' and next(m.poked) == nil, 'poked')
  assert(type(m.grabbed_finals) == 'table' and next(m.grabbed_finals) == nil, 'grabbed_finals')
end

T['VANILLA_BOSSES: 28 distinct keys, the five final bosses among them'] = function()
  eq(#logic.VANILLA_BOSSES, 28)
  local s = set_of(logic.VANILLA_BOSSES)
  local n = 0
  for _ in pairs(s) do n = n + 1 end
  eq(n, 28, 'distinct')
  for _, k in ipairs(logic.FINAL_BOSSES) do assert(s[k], k) end
end

T['collector_done: 27 of 28 is not done, 28 of 28 is, modded keys are ignored'] = function()
  local s = set_of(logic.VANILLA_BOSSES)
  eq(logic.collector_done(s), true, '28 of 28')
  s.bl_mymod_boss = true
  eq(logic.collector_done(s), true, 'a modded key changes nothing')
  s.bl_hook = nil
  eq(logic.collector_done(s), false, '27 of 28 (plus a modded one) is not done')
  eq(logic.collector_done({}), false); eq(logic.collector_done(nil), false)
end

T['kidnapper_done: 4 of 5 is not done, 5 of 5 is'] = function()
  local s = all_finals()
  eq(logic.kidnapper_done(s), true)
  s.bl_final_vessel = nil
  eq(logic.kidnapper_done(s), false)
  eq(logic.kidnapper_done(nil), false)
end

T['poke_achievements: collector and kidnapper from the profile sets'] = function()
  eq(#logic.poke_achievements({bl_ox = true}, {}), 0)
  local ids = logic.poke_achievements(set_of(logic.VANILLA_BOSSES), all_finals())
  assert(has(ids, 'fb_boss_collector') and has(ids, 'fb_kidnapper'))
  local only = logic.poke_achievements({}, all_finals())
  assert(has(only, 'fb_kidnapper') and not has(only, 'fb_boss_collector'))
end

T["defeat_achievements: don't touch me needs the hard poke on a showdown"] = function()
  local a = {showdown = true, start = 1, hands_left = 1, hand = 2, final_defeated = {}, final_defeated_twisted = {},
    hard_poked_showdown = true}
  assert(has(logic.defeat_achievements(a), 'fb_dont_touch_me'), 'showdown with the flag')
  a.hard_poked_showdown = nil
  assert(not has(logic.defeat_achievements(a), 'fb_dont_touch_me'), 'no flag')
  a.hard_poked_showdown, a.showdown = true, false
  assert(not has(logic.defeat_achievements(a), 'fb_dont_touch_me'), 'not a showdown')
end

T['defeat_achievements: hostage needs the win on the hand right after the grab'] = function()
  -- grabbed between hands with 2 played: the next hand's id is 2 (logic.next_hand_id)
  local grab = logic.next_hand_id(2, 1)
  eq(grab, 2)
  local a = {showdown = false, hand = 2, grab_hand = grab, final_defeated = {}, final_defeated_twisted = {}}
  assert(has(logic.defeat_achievements(a), 'fb_hostage'), 'win on hand N')
  a.hand = 3
  assert(not has(logic.defeat_achievements(a), 'fb_hostage'), 'win on hand N+1')
  a.hand, a.grab_hand = 2, nil
  assert(not has(logic.defeat_achievements(a), 'fb_hostage'), 'no grab')
  a.grab_hand, a.showdown = 2, true
  assert(has(logic.defeat_achievements(a), 'fb_hostage'), 'a showdown counts too')
end

T['next_hand_id: between hands it is hands_played; after the evaluation, before the count, one more'] = function()
  eq(logic.next_hand_id(0, nil), 0, 'first hand of the round')
  eq(logic.next_hand_id(3, 2), 3, 'after hand 2 was counted')
  eq(logic.next_hand_id(3, 3), 4, 'hand 3 evaluated (context.after), not yet counted')
  eq(logic.next_hand_id(nil, nil), nil)
end

return T
