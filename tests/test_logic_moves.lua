local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

T['EFFECTS lists the ten primitives plus curse, fist, recount, land, snake and needle'] = function()
  local n = 0
  for _ in pairs(logic.EFFECTS) do n = n + 1 end
  eq(n, 16, 'effect count')
  for _, name in ipairs({'fling', 'drain', 'crack', 'stamp', 'sweep', 'glare', 'chain', 'ring', 'spin', 'burst',
      'curse', 'fist', 'recount', 'land', 'snake', 'needle'}) do
    assert(logic.EFFECTS[name], 'missing effect ' .. name)
  end
end

T['clean_recipe: a curse step needs a known style'] = function()
  local r, w = logic.clean_recipe({{effect = 'curse', target = 'cards', style = 'suit'},
    {effect = 'curse', target = 'cards', style = 'lava'}, {effect = 'curse', target = 'cards'}})
  eq(#r, 1); eq(r[1].style, 'suit'); eq(#w, 2, 'unknown and missing style')
  for style in pairs(logic.CURSE_STYLES) do
    local ok, ww = logic.clean_recipe({{effect = 'curse', target = 'cards', style = style}})
    assert(ok and #ww == 0, 'style ' .. style)
  end
end

T['CURSE_STYLES: suit, vine, crack'] = function()
  local n = 0
  for _ in pairs(logic.CURSE_STYLES) do n = n + 1 end
  eq(n, 3)
  for _, s in ipairs({'suit', 'vine', 'crack'}) do assert(logic.CURSE_STYLES[s], s) end
end

--- The column order of assets/*/curse_marks.png (tools/make_art.py MARK_COLUMNS).
local ART_COLUMNS = {'Hearts', 'Diamonds', 'Clubs', 'Spades', 'suit', 'vine', 'crack', 'needle'}

T['MARK_FRAMES: one atlas column per frame, in the order make_art.py draws them'] = function()
  local n = 0
  for _ in pairs(logic.MARK_FRAMES) do n = n + 1 end
  eq(n, #ART_COLUMNS, 'frame count')
  for i, name in ipairs(ART_COLUMNS) do eq(logic.MARK_FRAMES[name], i - 1, name) end
end

T['mark_frame: every curse style has a frame, suit frames per suit and palette'] = function()
  for style in pairs(logic.CURSE_STYLES) do
    local x, y = logic.mark_frame(style, 'Clubs', false)
    assert(x and y, 'style ' .. style .. ' has a frame')
  end
  local x, y = logic.mark_frame('suit', 'Clubs', false)
  eq(x, 2); eq(y, 0, 'low contrast: row 0')
  x, y = logic.mark_frame('suit', 'Clubs', true)
  eq(x, 2); eq(y, 1, 'high contrast: row 1')
  for _, s in ipairs({'Hearts', 'Diamonds', 'Spades'}) do eq(logic.mark_frame('suit', s, false), logic.MARK_FRAMES[s], s) end
  x, y = logic.mark_frame('suit', 'mod_Stars', true)
  eq(x, logic.MARK_FRAMES.suit, 'unknown suit: the plain frame'); eq(y, 0, 'the plain frame has one palette')
  x, y = logic.mark_frame('suit', nil, false)
  eq(x, logic.MARK_FRAMES.suit, 'no suit: the plain frame')
  x, y = logic.mark_frame('vine', 'Hearts', true)
  eq(x, logic.MARK_FRAMES.vine); eq(y, 0, 'vines ignore suit and palette')
  eq(logic.mark_frame('crack'), logic.MARK_FRAMES.crack)
  eq(logic.mark_frame('lava', 'Hearts', false), nil, 'unknown style')
end

T['mark_dissolve: fades in as the mark grows, follows the card dissolving away'] = function()
  eq(logic.mark_dissolve(0, 0), 1, 'not grown: hidden')
  eq(logic.mark_dissolve(1, 0), 0, 'grown: fully shown')
  assert(math.abs(logic.mark_dissolve(0.25, 0) - 0.75) < 1e-9, 'quarter grown')
  eq(logic.mark_dissolve(1, 0.6), 0.6, 'the card dissolves: the mark goes with it')
  eq(logic.mark_dissolve(1, -0.4), 0.4, 'negative dissolve (vanilla uses abs)')
  eq(logic.mark_dissolve(0.2, 0.1), 0.8, 'the larger wins')
  eq(logic.mark_dissolve(1, nil), 0, 'no dissolve field')
  eq(logic.mark_dissolve(2, 0), 0, 'clamped'); eq(logic.mark_dissolve(-1, 0), 1, 'clamped')
end

T['curse_grow: eases 0 -> 1 over CURSE_GROW, at once under reduced motion'] = function()
  eq(logic.curse_grow(-0.2, false), 0, 'staggered card not born yet')
  eq(logic.curse_grow(0, false), 0)
  local mid = logic.curse_grow(logic.CURSE_GROW / 2, false)
  assert(mid > 0.5 and mid < 1, 'ease out: past half at half time, got ' .. mid)
  eq(logic.curse_grow(logic.CURSE_GROW, false), 1)
  eq(logic.curse_grow(10, false), 1)
  eq(logic.curse_grow(0, true), 1, 'reduced motion: no growth')
  eq(logic.curse_grow(-0.2, true), 1)
  eq(logic.curse_grow(nil, false), 1, 'no birth time: fully grown')
  assert(logic.CURSE_GROW >= 0.4 and logic.CURSE_GROW <= 0.6, 'about half a second')
end

T['curse_visible: only while the card is cursed by this live, facing, enabled blind'] = function()
  eq(logic.curse_visible(true, true, 'bl_club', 'bl_club', false, true, true), true)
  eq(logic.curse_visible(false, true, 'bl_club', 'bl_club', false, true, true), false, 'no longer debuffed')
  eq(logic.curse_visible(true, false, 'bl_club', 'bl_club', false, true, true), false, 'debuffed by something else')
  eq(logic.curse_visible(true, nil, 'bl_club', 'bl_club', false, true, true), false)
  eq(logic.curse_visible(true, true, 'bl_club', 'bl_goad', false, true, true), false, 'another blind')
  eq(logic.curse_visible(true, true, 'bl_club', nil, false, true, true), false, 'blind cleared after defeat')
  eq(logic.curse_visible(true, true, 'bl_club', 'bl_club', true, true, true), false, 'disabled (Chicot)')
  eq(logic.curse_visible(true, true, 'bl_club', 'bl_club', false, nil, true), false, 'round over')
  eq(logic.curse_visible(true, true, 'bl_club', 'bl_club', false, true, false), false, 'moves or fx off')
end

T['curse_visible: a FinalBoss twist debuff shows the mark on the disabled blind while it lasts'] = function()
  local leaf = 'bl_final_leaf'
  eq(logic.curse_visible(true, false, leaf, leaf, true, true, true, true), true, 'regrowth after a sale')
  eq(logic.curse_visible(true, true, leaf, leaf, true, true, true, true), true, 'by_blind set too')
  eq(logic.curse_visible(false, true, leaf, leaf, true, true, true, true), false, 'twist debuff gone')
  eq(logic.curse_visible(true, false, leaf, leaf, true, true, true, false), false, 'no twist: disabled hides it')
  eq(logic.curse_visible(true, false, leaf, nil, true, true, true, true), false, 'blind over')
  eq(logic.curse_visible(true, false, leaf, 'bl_club', true, true, true, true), false, 'another blind')
  eq(logic.curse_visible(true, false, leaf, leaf, true, nil, true, true), false, 'round over')
  eq(logic.curse_visible(true, false, leaf, leaf, true, true, false, true), false, 'moves or fx off')
end

local function seq(t) return table.concat(t, ',') end

T['count_steps: the values shown after each step, one at a time'] = function()
  eq(seq(logic.count_steps(4, 1)), '3,2,1', 'the Needle: 4 -> 1')
  eq(seq(logic.count_steps(1, 4)), '2,3,4', 'counting up')
  eq(seq(logic.count_steps(2, 1)), '1', 'one step')
  eq(#logic.count_steps(3, 3), 0, 'nothing to count')
  eq(#logic.count_steps(nil, 3), 0, 'unknown start')
  eq(#logic.count_steps(3, nil), 0, 'unknown end')
end

T['count_steps: at most `max` steps (default STEP_MAX), always landing on the new value'] = function()
  local s = logic.count_steps(20, 1)
  eq(#s, logic.STEP_MAX, 'capped')
  eq(s[#s], 1, 'lands on the new value')
  for i = 2, #s do assert(s[i] < s[i - 1], 'strictly down') end
  for _, v in ipairs(s) do eq(math.floor(v), v, 'whole numbers') end
  s = logic.count_steps(0, 10, 4)
  eq(#s, 4); eq(s[4], 10)
  for i = 2, #s do assert(s[i] > s[i - 1], 'strictly up') end
  eq(seq(logic.count_steps(5, 2, 8)), '4,3,2', 'under the cap: every number')
  assert(logic.STEP_MAX >= 3 and logic.STEP_MAX <= 10, 'a handful of steps')
end

T['step_index: steps done `elapsed` seconds after the first one'] = function()
  eq(logic.step_index(-0.1, 0.18, 3), 0, 'not started')
  eq(logic.step_index(0, 0.18, 3), 1, 'the first step lands at once')
  eq(logic.step_index(0.17, 0.18, 3), 1)
  eq(logic.step_index(0.18, 0.18, 3), 2)
  eq(logic.step_index(0.4, 0.18, 3), 3)
  eq(logic.step_index(9, 0.18, 3), 3, 'never past the last')
  eq(logic.step_index(0.5, 0, 3), 3, 'no step time: all at once')
  eq(logic.step_index(0.5, 0.18, 0), 0, 'no steps')
end

T['shake_offset: a quick side to side shake that dies out, none under reduced motion'] = function()
  eq(logic.shake_offset(-0.1, false), 0, 'not started')
  eq(logic.shake_offset(logic.SHAKE.time, false), 0, 'over')
  eq(logic.shake_offset(5, false), 0)
  local seen, max = {}, 0
  for i = 1, 20 do
    local v = logic.shake_offset(i * logic.SHAKE.time / 21, false)
    max = math.max(max, math.abs(v))
    seen[v > 0 and 'right' or (v < 0 and 'left' or 'mid')] = true
    eq(logic.shake_offset(i * logic.SHAKE.time / 21, true), 0, 'reduced motion: still')
  end
  assert(seen.left and seen.right, 'both ways')
  assert(max > 0 and max <= logic.SHAKE.amp, 'within the amplitude')
  assert(math.abs(logic.shake_offset(logic.SHAKE.time * 0.9, false)) < logic.SHAKE.amp * 0.2, 'dies out')
end

-- smods SMODS.upgrade_poker_hands (src/utils.lua:4089-4097) for one level change queues
-- after 0.9 (sound), before (level text), then delay(1.3).
local function ev(trigger, delay) return {trigger = trigger, delay = delay} end

T['level_tick_slots: finds the level-text event of a level change'] = function()
  local q = {ev('after', 0.5), ev('before', 0), -- older events, before the hook's mark
    ev('before', 0.3), ev('before', 0), ev('before', 0), -- handname, chips, mult texts
    ev('after', 0.2), ev('before', 0), ev('after', 0.9), ev('before', 0), -- chips and mult deltas
    ev('after', 0.9), ev('before', 0), ev('after', 1.3), -- level: sound, text, delay
    ev('immediate', 0), ev('after', 0.06)}
  local fall, hit = logic.level_tick_slots(q, 3)
  eq(fall, 10, 'before the level sound wait'); eq(hit, 12, 'right after the level text')
end

T['level_tick_slots: nil when the pattern is missing or before the mark'] = function()
  eq(logic.level_tick_slots({ev('after', 0.9), ev('before', 0), ev('after', 1.0)}, 1), nil)
  eq(logic.level_tick_slots({ev('after', 0.9), ev('before', 0), ev('after', 1.3)}, 2), nil, 'starts before the mark')
  eq(logic.level_tick_slots({}, 1), nil)
  eq(logic.level_tick_slots({ev('after', 0.9), ev('before', 0), ev('after', 1.3)}, nil), 1, 'default mark 1')
end

T['fist_timing: wait then fall so it lands at the level tick'] = function()
  local wait, fall = logic.fist_timing(0.9, false)
  eq(fall, logic.FIST_FALL); assert(math.abs(wait - (0.9 - logic.FIST_FALL)) < 1e-9, 'wait')
  wait, fall = logic.fist_timing(0.2, false)
  eq(wait, 0); eq(fall, 0.2, 'fast game speed: shorter fall')
  wait, fall = logic.fist_timing(0.9, true)
  eq(fall, 0, 'reduced motion: no fall'); eq(wait, 0.9)
  wait, fall = logic.fist_timing(-1, false)
  eq(wait, 0); eq(fall, 0)
  assert(logic.FIST_FALL >= 0.3 and logic.FIST_FALL <= 0.4, 'about 0.35 s')
end

T['MOVE_KINDS has every trigger kind plus signature'] = function()
  for _, k in ipairs({'play', 'modify', 'hand_debuff', 'card_debuff', 'flipped', 'drawn', 'start', 'set', 'draw',
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
  eq(logic.HUD_IDS.hud_hand_level, 'hand_level')
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

-- Blind-start before -> after ------------------------------------------------------------------------

T['normal_target: a regular boss target (mult 2) at the ante scaling'] = function()
  eq(logic.normal_target(300, 1), 600)
  eq(logic.normal_target(5000, 2), 20000, 'Plasma-style scaling')
  eq(logic.normal_target(nil, 1), 0)
  eq(logic.normal_target(300, nil), 600, 'missing scaling = 1')
end

T['recount_after: what each counter shows once the boss effect applied'] = function()
  local before = {hands = 4, discards = 3, hand_size = 8, target = 600}
  local a = logic.recount_after(before, {hands_sub = 3, discards_sub = 3, mod_delta = -1, chips = 1200})
  eq(a.hands, 1, 'Needle'); eq(a.discards, 0, 'Water'); eq(a.hand_size, 7, 'Manacle'); eq(a.target, 1200, 'Wall')
  local same = logic.recount_after(before, {})
  eq(same.hands, 4); eq(same.discards, 3); eq(same.hand_size, 8); eq(same.target, nil, 'no chips: unknown')
  local floor = logic.recount_after({hands = 1, discards = 0, hand_size = 0}, {hands_sub = 2, discards_sub = 1, mod_delta = -1})
  eq(floor.discards, 0, 'never below 0'); eq(floor.hand_size, 0, 'never below 0'); eq(floor.hands, 0)
  eq(logic.recount_after(nil, {}).hands, nil, 'no snapshot')
end

T['RECOUNT_VALUES names the four counters'] = function()
  for _, v in ipairs({'hands', 'discards', 'hand_size', 'target'}) do assert(logic.RECOUNT_VALUES[v], v) end
end

T['recount_value: holds the old value, then counts to the new one'] = function()
  eq(logic.recount_value(3, 0, 0, 0.3, 0.8, false), 3, 'start')
  eq(logic.recount_value(3, 0, 0.29, 0.3, 0.8, false), 3, 'hold')
  eq(logic.recount_value(3, 0, 1.1, 0.3, 0.8, false), 0, 'end')
  eq(logic.recount_value(3, 0, 5, 0.3, 0.8, false), 0, 'after the end')
  local mid = logic.recount_value(3, 0, 0.5, 0.3, 0.8, false)
  assert(mid == 2 or mid == 1, 'whole steps on the way down, got ' .. tostring(mid))
  local up = logic.recount_value(600, 1200, 0.7, 0.3, 0.8, false)
  assert(up > 600 and up < 1200, 'counts up')
  eq(math.floor(up), up, 'counts in whole numbers')
  eq(logic.recount_value(8, 7, 0.35, 0.3, 0.8, false), 8, 'a drop by one waits until it lands')
  -- monotonic
  local last = 4
  for i = 0, 20 do
    local v = logic.recount_value(4, 1, i * 0.06, 0.1, 1.0, false)
    assert(v <= last, 'never climbs back while draining'); last = v
  end
end

T['recount_value: reduced motion jumps from old to new after the hold'] = function()
  eq(logic.recount_value(3, 0, 0.1, 0.3, 0.8, true), 3)
  eq(logic.recount_value(3, 0, 0.31, 0.3, 0.8, true), 0, 'no counting')
  eq(logic.recount_value(600, 1200, 0.31, 0.3, 0.8, true), 1200)
end

T['recount_value: missing numbers fall back safely'] = function()
  eq(logic.recount_value(nil, 5, 0, 0.3, 0.8, false), 5)
  eq(logic.recount_value(5, nil, 2, 0.3, 0.8, false), 5)
  eq(logic.recount_value(3, 0, 0.5, 0.3, 0, false), 0, 'zero time: at once')
end

T['clean_recipe: recount needs a known value; cue sub-steps are cleaned too; live is kept'] = function()
  local r, w = logic.clean_recipe({live = true,
    {effect = 'recount', target = 'hud_target', value = 'target',
      cue = {{effect = 'crack', target = 'hud_target'}, {effect = 'laser'}}},
    {effect = 'recount', target = 'hud_hands', value = 'gold'},
    {effect = 'sweep', target = 'hand', each = true}})
  eq(#r, 2); eq(r.live, true)
  eq(r[1].effect, 'recount'); eq(#r[1].cue, 1, 'unknown cue effect dropped'); eq(r[1].cue[1].effect, 'crack')
  eq(r[2].each, true)
  eq(#w, 2, 'one bad cue step, one bad value')
end

T['clean_recipe never edits the shared step tables'] = function()
  local cue = {{effect = 'crack', target = 'hud_target'}, {effect = 'laser'}}
  local step = {effect = 'recount', target = 'hud_target', value = 'target', cue = cue}
  logic.clean_recipe({step})
  eq(step.cue, cue); eq(#cue, 2)
end

T['the hand_limit target and set kind exist; new effects are listed'] = function()
  assert(logic.TARGETS.hand_limit, 'hand_limit target')
  assert(logic.MOVE_KINDS.set, 'set kind')
  for _, e in ipairs({'recount', 'land', 'snake'}) do assert(logic.EFFECTS[e], e) end
end

-- The Serpent's draw (smods draw_from_deck_to_hand: delay(0.3) then draw_card 'before' 0.1 events).
local function ev(trigger, delay) return {trigger = trigger, delay = delay} end

T['draw_slots: finds the draw delay and counts the dealt cards'] = function()
  local q = {ev('after', 2), ev('immediate', 0), ev('after', 0.3), ev('before', 0.1), ev('immediate', 0),
    ev('before', 0.1), ev('before', 0.1), ev('immediate', 0), ev('immediate', 0)}
  local start, n = logic.draw_slots(q, 3)
  eq(start, 3); eq(n, 3)
  start, n = logic.draw_slots(q, 1)
  eq(start, 3, 'skips events before the draw'); eq(n, 3)
  eq(logic.draw_slots({ev('after', 0.3), ev('immediate', 0)}, 1), nil, 'no card dealt')
  eq(logic.draw_slots({ev('before', 0.1)}, 1), nil, 'no draw delay')
  eq(logic.draw_slots({}, 1), nil)
end

T['serpent_lead: real seconds until the last card is in the hand'] = function()
  local t = logic.serpent_lead(3, 1)
  assert(math.abs(t - (0.3 + 0.2 + logic.CARD_SETTLE)) < 1e-9, 'three cards at normal speed')
  assert(logic.serpent_lead(3, 2) < t, 'faster game, shorter snake')
  assert(logic.serpent_lead(1, 1) < t)
  assert(logic.serpent_lead(0, 1) > 0, 'never zero')
  assert(logic.serpent_lead(3, 0) > 0, 'bad speed factor')
end

return T
