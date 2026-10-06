-- Boss personalities (1.2): the vanilla table, validation and the boss -> personality -> generic order.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function fresh()
  package.loaded['src.logic'] = nil
  package.loaded['src.personality'] = nil
  local logic = require('src.logic')
  _G.FinalBoss = {logic = logic}
  return logic, require('src.personality')
end

local function counts(t) return function(prefix) return t[prefix] or 0 end end

T['personality: every vanilla boss has one of the six'] = function()
  local logic, P = fresh()
  _G.FinalBoss = nil
  package.loaded['src.encounters.vanilla'] = nil
  local bosses = require('src.encounters.vanilla')
  local valid = {}
  for _, k in ipairs(logic.PERSONALITIES) do valid[k] = true end
  local n = 0
  for key in pairs(bosses) do
    n = n + 1
    assert(valid[P.VANILLA[key]], key .. ' has no valid personality: ' .. tostring(P.VANILLA[key]))
  end
  eq(n, 28)
end

T['personality: the six groups match the design'] = function()
  local _, P = fresh()
  local by = {}
  for _, p in pairs(P.VANILLA) do by[p] = (by[p] or 0) + 1 end
  eq(by.bully, 5, 'bully'); eq(by.smug, 4, 'smug'); eq(by.killer, 5, 'killer')
  eq(by.venom, 4, 'venom'); eq(by.chaos, 4, 'chaos'); eq(by.royal, 6, 'royal')
  eq(P.VANILLA.bl_ox, 'bully'); eq(P.VANILLA.bl_psychic, 'smug'); eq(P.VANILLA.bl_hook, 'killer')
  eq(P.VANILLA.bl_final_heart, 'venom'); eq(P.VANILLA.bl_final_acorn, 'chaos'); eq(P.VANILLA.bl_final_bell, 'royal')
end

T['clean_personality: valid kept, nil and unknown fall back to bully'] = function()
  local logic = fresh()
  local p, w = logic.clean_personality('smug'); eq(p, 'smug'); eq(w, nil)
  p, w = logic.clean_personality(nil); eq(p, 'bully'); eq(w, nil)
  p, w = logic.clean_personality('grumpy'); eq(p, 'bully')
  assert(w and w:find('grumpy', 1, true), 'the warning names the bad key')
  p, w = logic.clean_personality(42); eq(p, 'bully'); assert(w, 'a number warns')
end

T['resolve_prefix: boss line, then personality, then generic'] = function()
  local logic = fresh()
  eq(logic.resolve_prefix('bl_hook', 'idle',
    counts{fb_bl_hook_idle = 1, fb_p_killer_idle = 2, fb_generic_idle = 1}, 'killer'), 'fb_bl_hook_idle')
  eq(logic.resolve_prefix('bl_hook', 'idle', counts{fb_p_killer_idle = 2, fb_generic_idle = 1}, 'killer'),
    'fb_p_killer_idle')
  local p, generic = logic.resolve_prefix('bl_hook', 'idle', counts{fb_p_bully_idle = 2, fb_generic_idle = 1}, 'killer')
  eq(p, 'fb_generic_idle'); eq(generic, true)
  eq(logic.resolve_prefix('bl_hook', 'idle', counts{}, 'killer'), nil)
end

T['resolve_prefix: skip_boss goes straight to the personality'] = function()
  local logic = fresh()
  eq(logic.resolve_prefix('bl_hook', 'jab_counter',
    counts{fb_bl_hook_jab_counter = 1, fb_p_killer_jab_counter = 1}, 'killer', true), 'fb_p_killer_jab_counter')
end

T['resolve_prefix: shared moments ignore the personality'] = function()
  local logic = fresh()
  eq(logic.resolve_prefix('bl_hook', 'opener', counts{fb_opener = 3, fb_p_killer_opener = 1}, 'killer'), 'fb_opener')
end

T['resolve_prefix: without a personality it keeps the 1.1 order'] = function()
  local logic = fresh()
  eq(logic.resolve_prefix('bl_hook', 'close', counts{fb_generic_close = 3}), 'fb_generic_close')
  eq(logic.resolve_prefix('bl_hook', 'close', counts{fb_bl_hook_close = 1, fb_generic_close = 3}), 'fb_bl_hook_close')
end

return T
