local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

T['EFFECTS lists the ten primitives'] = function()
  local n = 0
  for _ in pairs(logic.EFFECTS) do n = n + 1 end
  eq(n, 10, 'effect count')
  for _, name in ipairs({'fling', 'drain', 'crack', 'stamp', 'sweep', 'glare', 'chain', 'ring', 'spin', 'burst'}) do
    assert(logic.EFFECTS[name], 'missing effect ' .. name)
  end
end

T['MOVE_KINDS has every trigger kind plus signature'] = function()
  for _, k in ipairs({'play', 'modify', 'hand_debuff', 'card_debuff', 'flipped', 'drawn', 'start', 'draw',
      'joker_sold', 'generic', 'signature'}) do
    assert(logic.MOVE_KINDS[k], 'missing kind ' .. k)
  end
end

T['clean_recipe keeps valid steps, sound and defer'] = function()
  local r, w = logic.clean_recipe({defer = true, {effect = 'glare', target = 'cards', line = true},
    {effect = 'burst'}, sound = {'slice1', 0.9, 0.5}})
  eq(#r, 2); eq(r[1].effect, 'glare'); eq(r[1].line, true); eq(r[2].effect, 'burst')
  eq(r.sound[1], 'slice1'); eq(r.defer, true); eq(#w, 0)
end

T['clean_recipe drops unknown effects and targets with warnings'] = function()
  local r, w = logic.clean_recipe({{effect = 'laser'}, {effect = 'ring', target = 'moon'}, {effect = 'ring'}})
  eq(#r, 1); eq(r[1].effect, 'ring'); eq(#w, 2)
end

T['clean_recipe returns nil when nothing valid remains'] = function()
  local r, w = logic.clean_recipe({{effect = 'laser'}})
  eq(r, nil); eq(#w, 1)
  local r2, w2 = logic.clean_recipe('burst')
  eq(r2, nil); eq(#w2, 1)
end

T['clean_moves validates kinds and recipes'] = function()
  local m, w = logic.clean_moves({play = {{effect = 'fling', target = 'cards'}}, dance = {{effect = 'burst'}},
    start = {{effect = 'nope'}}})
  assert(m.play, 'play kept'); eq(m.dance, nil); eq(m.start, nil)
  eq(#w, 2, 'unknown kind + empty start recipe')
  local none = logic.clean_moves({})
  eq(none, nil)
end

T['clean_death accepts a built-in name or a recipe'] = function()
  eq(logic.clean_death('hearts'), 'hearts')
  local d, w = logic.clean_death('fireworks')
  eq(d, nil); eq(#w, 1)
  local r = logic.clean_death({{effect = 'burst'}, {effect = 'ring'}})
  eq(#r, 2)
end

T['throttle_ok allows the first call and blocks inside the gap'] = function()
  local last = {}
  eq(logic.throttle_ok(last, 'card_debuff', 10, 0.6), true)
  eq(logic.throttle_ok(last, 'card_debuff', 10.3, 0.6), false)
  eq(logic.throttle_ok(last, 'flipped', 10.3, 0.6), true, 'other keys are independent')
  eq(logic.throttle_ok(last, 'card_debuff', 10.75, 0.6), true)
  eq(last.card_debuff, 10.75)
end

T['throttle_ok uses THROTTLE_GAP by default'] = function()
  local last = {}
  logic.throttle_ok(last, 'k', 0)
  eq(logic.throttle_ok(last, 'k', logic.THROTTLE_GAP - 0.01), false)
  eq(logic.throttle_ok(last, 'k', logic.THROTTLE_GAP), true)
end

T['queue_push drops the oldest beyond max'] = function()
  local q = {}
  local _, d1 = logic.queue_push(q, 'a', 2)
  local _, d2 = logic.queue_push(q, 'b', 2)
  local _, d3 = logic.queue_push(q, 'c', 2)
  eq(d1, nil); eq(d2, nil); eq(d3, 'a'); eq(#q, 2); eq(q[1], 'b'); eq(q[2], 'c')
end

T['move_allowed needs moves, fx, a live run and a boss'] = function()
  local base = {moves = true, fx = true, disabled_run = false, is_boss = true, blind_disabled = false, kind = 'play'}
  eq(logic.move_allowed(base), true)
  for _, k in ipairs({'moves', 'fx', 'is_boss'}) do
    local a = {}
    for kk, v in pairs(base) do a[kk] = v end
    a[k] = false
    eq(logic.move_allowed(a), false, k)
  end
  local a = {}
  for kk, v in pairs(base) do a[kk] = v end
  a.disabled_run = true
  eq(logic.move_allowed(a), false, 'disabled run')
end

T['move_allowed: a disabled blind only performs joker_sold'] = function()
  local a = {moves = true, fx = true, is_boss = true, blind_disabled = true, kind = 'drawn'}
  eq(logic.move_allowed(a), false)
  a.kind = 'joker_sold'
  eq(logic.move_allowed(a), true)
end

T['recipe_for: own recipe, generic fallback only without moves'] = function()
  local moves = {play = {{effect = 'burst'}}}
  eq(logic.recipe_for(moves, 'play'), moves.play)
  eq(logic.recipe_for(moves, 'generic'), nil, 'a boss with a recipe ignores wiggles')
  eq(logic.recipe_for(nil, 'generic'), logic.GENERIC_RECIPE)
  eq(logic.recipe_for(nil, 'play'), nil)
end

T['GLYPHS: four glyphs of polylines inside the unit square'] = function()
  for _, g in ipairs({'x', 'hex', 'vine', 'crack'}) do
    local strokes = logic.GLYPHS[g]
    assert(type(strokes) == 'table' and #strokes >= 1, 'glyph ' .. g)
    for _, s in ipairs(strokes) do
      assert(#s >= 4 and #s % 2 == 0, g .. ': a stroke needs at least two points')
      for _, v in ipairs(s) do assert(v >= 0 and v <= 1, g .. ': point outside the unit square') end
    end
  end
end

T['coin_count: none below one dollar, floor, capped'] = function()
  eq(logic.coin_count(0), 0)
  eq(logic.coin_count(0.5), 0)
  eq(logic.coin_count(-3), 0)
  eq(logic.coin_count(1), 1)
  eq(logic.coin_count(4.7), 4)
  eq(logic.coin_count(250), 12)
  eq(logic.coin_count(250, 5), 5)
  eq(logic.coin_count(nil), 0)
end

T['HUD_IDS covers every hud_* target'] = function()
  for target in pairs(logic.TARGETS) do
    if target:sub(1, 4) == 'hud_' then
      assert(type(logic.HUD_IDS[target]) == 'string', 'no HUD id for ' .. target)
    end
  end
  eq(logic.HUD_IDS.hud_target, 'HUD_blind_count')
  eq(logic.HUD_IDS.hud_dollars, 'dollar_text_UI')
end

T['step_amount reads played cards, money or a number'] = function()
  local data = {played = {1, 2, 3}, money = 12}
  eq(logic.step_amount({amount = 'played'}, data), 3)
  eq(logic.step_amount({amount = 'money'}, data), 12)
  eq(logic.step_amount({amount = 4}, data), 4)
  eq(logic.step_amount({}, data), 0)
  eq(logic.step_amount({amount = 'played'}, {}), 0)
  eq(logic.step_amount({amount = 'money'}, {}), 0)
end

T['hand_debuff_fired: real calls that returned true or triggered'] = function()
  eq(logic.hand_debuff_fired(true, true, nil, false), true, 'Psychic/Eye/Mouth')
  eq(logic.hand_debuff_fired(nil, true, nil, false), true, 'Arm/Ox act and return nil')
  eq(logic.hand_debuff_fired(nil, false, nil, false), false, 'nothing happened')
  eq(logic.hand_debuff_fired(true, true, true, false), false, 'highlight preview (check)')
  eq(logic.hand_debuff_fired(true, true, nil, true), false, 'disabled blind')
end

T['serpent_draw: only the Serpent after the first play or discard'] = function()
  eq(logic.serpent_draw{key = 'bl_serpent', disabled = false, hands_played = 1, discards_used = 0}, true)
  eq(logic.serpent_draw{key = 'bl_serpent', disabled = false, hands_played = 0, discards_used = 2}, true)
  eq(logic.serpent_draw{key = 'bl_serpent', disabled = false, hands_played = 0, discards_used = 0}, false, 'opening draw')
  eq(logic.serpent_draw{key = 'bl_serpent', disabled = true, hands_played = 1, discards_used = 0}, false)
  eq(logic.serpent_draw{key = 'bl_hook', disabled = false, hands_played = 1, discards_used = 0}, false)
end

return T
