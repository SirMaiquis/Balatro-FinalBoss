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
T['can_fire: light tier, at most one line per hand and never on consecutive hands'] = function()
  for _, m in ipairs({'big_hand', 'close', 'last_hand'}) do
    eq(logic.can_fire(m, 'light', {}, 0, 1, nil), true, m .. ' first line')
    eq(logic.can_fire(m, 'light', {}, 1, 1, 1), false, m .. ' same hand')
    eq(logic.can_fire(m, 'light', {}, 1, 2, 1), false, m .. ' next hand')
    eq(logic.can_fire(m, 'light', {}, 1, 3, 1), true, m .. ' a hand later')
  end
  eq(logic.can_fire('close', 'light', {close = true}, 1, 5, 1), false, 'still once per blind')
end
T['can_fire: light tier, disabled and defeat are not spaced, once each'] = function()
  for _, m in ipairs({'disabled', 'defeat'}) do
    eq(logic.can_fire(m, 'light', {}, 3, 2, 1), true, m .. ' right after a line')
    eq(logic.can_fire(m, 'light', {[m] = true}, 3, 5, 1), false, m .. ' once')
  end
end
T['can_fire: full tier is not spaced'] = function()
  eq(logic.can_fire('close', 'full', {}, 1, 2, 1), true)
  eq(logic.can_fire('big_hand', 'full', {}, 1, 2, 1), true)
end
T['can_fire: none tier never fires'] = function() eq(logic.can_fire('defeat', 'none', {}, 0), false) end

local function detect(o)
  return logic.detect_moments{delta = o.delta, total = o.total, required = o.required or 100,
    hands_left = o.hands_left or 3, fired = o.fired or {}, tier = o.tier or 'full', reactions = o.reactions or 0,
    hand = o.hand, last_line_hand = o.last_line_hand}
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
T['detect: light tier spacing'] = function()
  eq(detect{delta = 40, total = 80, tier = 'light', hand = 2, last_line_hand = 1}, nil, 'the hand after a line')
  eq(detect{delta = 40, total = 80, tier = 'light', hand = 3, last_line_hand = 1}, 'close')
  eq(detect{delta = 40, total = 100, tier = 'light', hand = 2, last_line_hand = 1}, 'defeat', 'defeat is not spaced')
end
T['detect: light tier, a line on hand 1, nothing on hand 2, a line on hand 3'] = function()
  local enc = {tier = 'light', fired = {}, reactions = 0}
  local function play(hand, delta, total)
    local m = detect{delta = delta, total = total, tier = enc.tier, fired = enc.fired, reactions = enc.reactions,
      hand = hand, last_line_hand = enc.last_line_hand}
    if m then logic.note_line(enc, m, hand) end
    return m
  end
  eq(play(1, 40, 40), 'big_hand')
  eq(enc.last_line_hand, 1)
  eq(play(2, 40, 80), nil, 'close, but the boss just spoke')
  eq(enc.last_line_hand, 1)
  eq(play(3, 5, 85), 'close')
  eq(enc.last_line_hand, 3)
end
T['note_line: books fired; only a spaced line marks its hand'] = function()
  local enc = {fired = {}, reactions = 0}
  logic.note_line(enc, 'disabled', 2)
  eq(enc.fired.disabled, true); eq(enc.last_line_hand, nil, 'disabled is not spaced')
  logic.note_line(enc, 'last_hand', 4)
  eq(enc.fired.last_hand, true); eq(enc.last_line_hand, 4)
  logic.note_line(enc, 'defeat', 5)
  eq(enc.last_line_hand, 4, 'defeat is not spaced')
end
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
T['resolve_prefix: shared nemesis lines'] = function()
  eq(logic.resolve_prefix('bl_hook', 'nemesis_intro', counts{fb_nemesis_intro = 3}), 'fb_nemesis_intro')
  eq(logic.resolve_prefix('bl_hook', 'nemesis_defeat', counts{fb_generic_nemesis_defeat = 3}), nil,
    'no generic fallback')
end

T['resolve_prefix: interrupted is boss-specific, then generic'] = function()
  eq(logic.resolve_prefix('bl_hook', 'interrupted', counts{fb_bl_hook_interrupted = 1, fb_generic_interrupted = 3}),
    'fb_bl_hook_interrupted')
  local p, generic = logic.resolve_prefix('bl_custom', 'interrupted', counts{fb_generic_interrupted = 3})
  eq(p, 'fb_generic_interrupted'); eq(generic, true)
end

local function interrupt(over)
  local a = {hand_played = true, cinematic_intro = false, dialogue_intro = true, tier = 'light', ended = false,
    fired = {}}
  for k, v in pairs(over or {}) do a[k] = v end
  return logic.should_interrupt(a)
end

T['should_interrupt: playing during the intro lines'] = function() eq(interrupt(), true) end
T['should_interrupt: playing during the cinematic beats'] = function()
  eq(interrupt{cinematic_intro = true, dialogue_intro = false, tier = 'full'}, true)
end
T['should_interrupt: no hand played (discard, skip key) is not an interruption'] = function()
  eq(interrupt{hand_played = false}, false)
end
T['should_interrupt: only while the intro runs'] = function()
  eq(interrupt{cinematic_intro = false, dialogue_intro = false}, false)
end
T['should_interrupt: once per encounter'] = function() eq(interrupt{fired = {interrupted = true}}, false) end
T['should_interrupt: not after the encounter ended or without a tier'] = function()
  eq(interrupt{ended = true}, false)
  eq(interrupt{tier = 'none'}, false)
end
T['should_interrupt: other fired moments do not block it'] = function()
  eq(interrupt{fired = {big_hand = true, close = true}}, true)
end

T['moment_replaced: only the interrupting hand'] = function()
  eq(logic.moment_replaced(0, 0), true)
  eq(logic.moment_replaced(0, 1), false)
  eq(logic.moment_replaced(nil, 0), false)
  eq(logic.moment_replaced(2, nil), false)
  eq(logic.moment_replaced(0, 0, 'close'), true)
end

T['moment_replaced: the defeat line is never replaced'] = function()
  eq(logic.moment_replaced(0, 0, 'defeat'), false)
  eq(logic.moment_replaced(3, 3, 'defeat'), false)
end

local function near(a, b, msg) if math.abs(a - b) > 1e-9 then error((msg or 'value') .. ': ' .. a .. ' ~= ' .. b, 2) end end

T['gloat_rect: full size right of the panel, vertically centred'] = function()
  local x, y, s = logic.gloat_rect({x = 6, y = 2, w = 10, h = 8}, 20.5, 2.1, 1.4, 0.3)
  near(s, 2.1, 'size'); near(x, 16.3, 'x'); near(y, 2 + 4 - 1.05, 'y')
end

T['gloat_rect: shrinks to the free margin, never covering the panel'] = function()
  -- free = 20.5 - 18 - 0.6 = 1.9
  local x, y, s = logic.gloat_rect({x = 8, y = 2, w = 10, h = 8}, 20.5, 2.1, 1.4, 0.3)
  near(s, 1.9, 'size'); near(x, 18.3, 'x'); near(y, 6 - 0.95, 'y')
  assert(x + s <= 20.5 - 0.3 + 1e-9, 'stays inside the window')
end

T['gloat_rect: above the top-right corner when even the minimum does not fit'] = function()
  -- free = 20.5 - 19.5 - 0.6 = 0.4 < 1.4; space above = 2 - 0.6 = 1.4
  local x, y, s = logic.gloat_rect({x = 9.5, y = 2, w = 10, h = 8}, 20.5, 2.1, 1.4, 0.3)
  near(s, 1.4, 'size'); near(x, 19.5 - 1.4, 'x'); near(y, 2 - 0.3 - 1.4, 'y')
  assert(y + s <= 2, 'never covers the panel')
  local _, _, big = logic.gloat_rect({x = 9.5, y = 4, w = 10, h = 6}, 20.5, 2.1, 1.4, 0.3)
  near(big, 2.1, 'full size when there is room above')
end

T['interrupted is forced, not a reaction'] = function()
  eq(logic.FORCED_MOMENTS.interrupted, true)
  eq(logic.FORCED_MOMENTS.defeat, true)
  eq(logic.REACTIONS.interrupted, nil)
  eq(logic.can_fire('interrupted', 'light', {}, 1), true) -- a spent light-tier reaction does not block it
  eq(logic.can_fire('interrupted', 'light', {interrupted = true}, 0), false)
end

return T
