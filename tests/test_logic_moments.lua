local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function tier(t)
  return logic.decide_tier{is_boss = t[1], is_showdown = t[2], entry_tier = t[3], ante = t[4], min_ante = t[5]}
end

T['decide_tier: non-boss is none'] = function() eq(tier{false, false, 'auto', 5, 1}, 'none') end
T['decide_tier: showdown is full'] = function() eq(tier{true, true, 'auto', 1, 8}, 'full') end
T['decide_tier: regular boss at or above min ante is light'] = function()
  eq(tier{true, false, 'auto', 3, 3}, 'light')
  eq(tier{true, false, 'auto', 2, 3}, 'none')
end
T['decide_tier: explicit entry tier wins'] = function()
  eq(tier{true, false, 'full', 1, 8}, 'full')
  eq(tier{true, true, 'light', 8, 1}, 'light')
end
T['decide_tier: explicit tier still needs a boss'] = function() eq(tier{false, false, 'full', 8, 1}, 'none') end

T['can_fire: once per blind'] = function()
  eq(logic.can_fire('close', 'full', {}, 0), true)
  eq(logic.can_fire('close', 'full', {close = true}, 1), false)
end
T['can_fire: light tier allows one reaction only'] = function()
  eq(logic.can_fire('big_hand', 'light', {}, 0), true)
  eq(logic.can_fire('big_hand', 'light', {}, 1), false)
  eq(logic.can_fire('defeat', 'light', {}, 1), true)
end
T['can_fire: none tier never fires'] = function() eq(logic.can_fire('defeat', 'none', {}, 0), false) end

local function detect(o)
  return logic.detect_moments{delta = o.delta, total = o.total, required = o.required or 100,
    hands_left = o.hands_left or 3, fired = o.fired or {}, tier = o.tier or 'full', reactions = o.reactions or 0}
end

T['detect: winning hand is defeat'] = function() eq(detect{delta = 50, total = 100}, 'defeat') end
T['detect: defeat only once'] = function() eq(detect{delta = 50, total = 120, fired = {defeat = true}}, nil) end
T['detect: big hand at 30 percent'] = function()
  eq(detect{delta = 30, total = 30}, 'big_hand')
  eq(detect{delta = 29, total = 29}, nil)
end
T['detect: close at 75 percent'] = function() eq(detect{delta = 10, total = 75}, 'close') end
T['detect: last hand when out of hands and not beaten'] = function() eq(detect{delta = 5, total = 10, hands_left = 0}, 'last_hand') end
T['detect: priority last_hand > close > big_hand'] = function()
  eq(detect{delta = 40, total = 80, hands_left = 0}, 'last_hand')
  eq(detect{delta = 40, total = 80}, 'close')
end
T['detect: falls through to next available moment'] = function()
  eq(detect{delta = 40, total = 80, fired = {close = true}, reactions = 1}, 'big_hand')
end
T['detect: light tier cap'] = function() eq(detect{delta = 40, total = 80, tier = 'light', reactions = 1}, nil) end
T['detect: zero requirement is ignored'] = function() eq(detect{delta = 1, total = 1, required = 0}, nil) end

local function counts(map) return function(prefix) return map[prefix] or 0 end end

T['resolve_prefix: boss-specific first'] = function()
  local p, generic = logic.resolve_prefix('bl_hook', 'intro', counts{fb_bl_hook_intro = 2, fb_generic_intro = 3})
  eq(p, 'fb_bl_hook_intro'); eq(generic, false)
end
T['resolve_prefix: generic fallback'] = function()
  local p, generic = logic.resolve_prefix('bl_mod_x', 'intro', counts{fb_generic_intro = 3})
  eq(p, 'fb_generic_intro'); eq(generic, true)
end
T['resolve_prefix: nothing resolves to nil'] = function()
  eq(logic.resolve_prefix('bl_mod_x', 'close', counts{}), nil)
end
T['resolve_prefix: shared opener and closer'] = function()
  eq(logic.resolve_prefix('bl_hook', 'opener', counts{fb_opener = 3}), 'fb_opener')
  eq(logic.resolve_prefix('bl_hook', 'closer', counts{}), nil)
end

return T
