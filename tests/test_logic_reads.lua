local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function with(base, o)
  local t = {}
  for k, v in pairs(base) do t[k] = v end
  for k, v in pairs(o or {}) do t[k] = v end
  return t
end

T['next_streak: same hand type grows, another restarts, none clears'] = function()
  eq(logic.next_streak(nil, 0, 'Pair'), 1)
  eq(logic.next_streak('Pair', 1, 'Pair'), 2)
  eq(logic.next_streak('Pair', 2, 'Flush'), 1)
  eq(logic.next_streak('Pair', 2, nil), 0)
end

local HAND = {hand_type = 'Flush', big = false, streak = 1, discards_left = 2, discards_used = 1,
  hands_left = 2, cards_played = 5}
local function read(o, fired) return logic.fight_read(with(HAND, o), fired) end

T['fight_read: each trigger'] = function()
  eq(read(), nil)
  eq(read{hand_type = 'High Card'}, 'read_weakhand'); eq(read{hand_type = 'Pair'}, 'read_weakhand')
  eq(read{hand_type = 'Pair', big = true}, nil, 'a big Pair is no weak hand')
  eq(read{streak = 3}, 'read_repeat'); eq(read{streak = 2}, nil)
  eq(read{discards_left = 0, hands_left = 2}, 'read_discardspam', 'burned them all with 3 hands to play'); eq(read{discards_left = 0, hands_left = 1}, nil)
  eq(read{discards_left = 0, discards_used = 0, hands_left = 3}, nil, 'The Water took them: no spam')
  eq(read{cards_played = 1}, 'read_onecard')
end

T['fight_read: order, and nothing repeats in a blind'] = function()
  eq(read{streak = 3, cards_played = 1, hand_type = 'High Card'}, 'read_repeat')
  eq(read({streak = 3, cards_played = 1, hand_type = 'High Card'}, {read_repeat = true}), 'read_onecard')
  eq(read({cards_played = 1, hand_type = 'High Card'}, {read_onecard = true, read_weakhand = true}), nil)
end

local CAN = {moment = 'read_onecard', tier = 'full', fired = {}, comments = 0, hand = 3}
local function can(o) return logic.can_comment(with(CAN, o)) end

T['can_comment: light tier, never right after a line'] = function()
  eq(can{tier = 'light'}, true)
  eq(can{tier = 'light', hand = 3, last_line_hand = 3}, false, 'same hand')
  eq(can{tier = 'light', hand = 3, last_line_hand = 2}, false, 'consecutive')
  eq(can{tier = 'light', hand = 3, last_line_hand = 1}, true)
end

T['can_comment: light tier, one read per blind even when spaced'] = function()
  eq(can{tier = 'light', comments = 1, hand = 5, last_line_hand = 1}, false)
  eq(can{tier = 'light', moment = 'read_repeat', comments = 1}, false)
  eq(can{tier = 'light', moment = 'weak', comments = 1, hand = 5, last_line_hand = 1}, true, 'weak is the boss own line')
end

T['can_comment: the full tier caps at 3, never on consecutive hands'] = function()
  eq(can{comments = 2, last_comment_hand = 1}, true)
  eq(can{comments = 3, last_comment_hand = 1}, false)
  eq(can{comments = 1, last_comment_hand = 2}, false, 'consecutive')
  eq(can{comments = 1, last_comment_hand = 1}, true)
end

T['can_comment: once per blind; never below light tier'] = function()
  eq(can{fired = {read_onecard = true}}, false)
  eq(can{tier = 'none'}, false)
end

T['can_comment: weak ignores the run-comment cap and the consecutive rule'] = function()
  eq(can{moment = 'weak', comments = 3, last_comment_hand = 2}, true)
  eq(can{moment = 'weak', tier = 'light'}, true)
  eq(can{moment = 'weak', tier = 'light', hand = 3, last_line_hand = 2}, false, 'light: weak follows the spacing')
  eq(can{moment = 'weak', fired = {weak = true}}, false)
  eq(can{moment = 'weak', tier = 'none'}, false)
end

T['pick_comment: weak neither waits for nor feeds the comment caps'] = function()
  local a = {weak = true, hand_type = 'Flush', streak = 1, discards_left = 1, discards_used = 0,
    hands_left = 3, cards_played = 5, tier = 'full', fired = {}, comments = 3,
    last_comment_hand = 3, hand = 4}
  eq(logic.pick_comment(a), 'weak', 'cap reached and consecutive, still weak')
  a.fired = {weak = true}
  eq(logic.pick_comment(a), nil)
end

T['pick_comment: the weak line first, then a read, within the caps'] = function()
  local a = {weak = true, hand_type = 'High Card', streak = 1, discards_left = 1, discards_used = 0,
    hands_left = 3, cards_played = 2, tier = 'full', fired = {}, comments = 0, hand = 4}
  eq(logic.pick_comment(a), 'weak')
  a.fired = {weak = true}
  eq(logic.pick_comment(a), 'read_weakhand')
  a.last_comment_hand = 3
  eq(logic.pick_comment(a), nil, 'consecutive hand')
  local light = {weak = false, hand_type = 'Flush', streak = 1, discards_left = 1, discards_used = 0,
    hands_left = 3, cards_played = 5, tier = 'light', fired = {}, comments = 0, hand = 1}
  eq(logic.pick_comment(light), nil, 'nothing to say')
  light.weak = true; light.hand = 2; light.last_line_hand = 1
  eq(logic.pick_comment(light), nil, 'the boss spoke on the hand before')
  light.hand = 3
  eq(logic.pick_comment(light), 'weak')
end

T['note_comment: books fired, the count and the hand'] = function()
  local enc = {fired = {}}
  logic.note_comment(enc, 'read_onecard', 2)
  eq(enc.fired.read_onecard, true); eq(enc.comments, 1); eq(enc.last_comment_hand, 2)
  eq(enc.reactions, nil, 'no reaction counter')
  eq(enc.last_line_hand, 2, 'the light tier spacing')
  logic.note_comment(enc, 'read_repeat', 4)
  eq(enc.comments, 2); eq(enc.last_comment_hand, 4); eq(enc.last_line_hand, 4)
end

T['note_comment: weak is a reaction, not a run comment'] = function()
  local enc = {fired = {}}
  logic.note_comment(enc, 'weak', 2)
  eq(enc.fired.weak, true)
  eq(enc.comments or 0, 0, 'no run comment'); eq(enc.last_comment_hand, nil, 'no comment hand booked')
  eq(enc.last_line_hand, 2, 'weak follows the light tier spacing')
end

T['fear_tier: 2x sore, 10x scared, 100x terrified'] = function()
  eq(logic.fear_tier(199, 100), nil); eq(logic.fear_tier(200, 100), 1)
  eq(logic.fear_tier(999, 100), 1); eq(logic.fear_tier(1000, 100), 2)
  eq(logic.fear_tier(9999, 100), 2); eq(logic.fear_tier(10000, 100), 3)
  eq(logic.fear_tier(1e300, 100), 3, 'huge')
  eq(logic.fear_tier(50, 0), nil, 'no requirement'); eq(logic.fear_tier(nil, 100), nil)
  eq(logic.fear_tier(math.huge, 100), 3, 'an infinite total over a finite requirement')
  eq(logic.fear_tier(math.huge, math.huge), nil, 'inf over inf')
  eq(logic.fear_tier(1e300, math.huge), nil, 'an infinite requirement')
  eq(logic.fear_tier(1.7e308, 1e306), 3, 'no overflow near the double cap')
  eq(logic.fear_tier(1.79e308, 1.7e306), 3, 'capped total, 100x+')
  eq(logic.fear_tier(1.7e308, 1e307), 2, '17x near the cap')
  eq(logic.fear_tier(1e308, 1e-10), nil, 'an overflowing ratio')
  eq(logic.fear_tier(0/0, 100), nil, 'nan'); eq(logic.fear_tier(100, 0/0), nil, 'nan requirement')
end
T['fear moments replace overkill in every personality'] = function()
  local has = {}
  for _, m in ipairs(logic.PERSONALITY_MOMENTS) do has[m] = true end
  assert(not has.overkill)
  for t = 1, 3 do assert(has['fear_' .. t]); eq(logic.personality_variants('fear_' .. t), 3) end
end
T['fear_reaction: scared trembles, terrified cowers and flashes; reduced motion flashes only'] = function()
  eq(logic.fear_reaction(1), nil, 'sore keeps the plain defeat'); eq(logic.fear_reaction(nil), nil)
  local scared, terrified = logic.fear_reaction(2), logic.fear_reaction(3)
  assert(scared.shake and scared.bounces and not scared.flash)
  assert(terrified.shake > 0 and terrified.recoil and terrified.flash == 'white')
  assert(terrified.shake_amp > scared.shake_amp, 'terrified shakes harder')
  for t = 2, 3 do
    local r = logic.fear_reaction(t, true)
    for _, k in ipairs({'juice', 'rot', 'shake', 'shake_amp', 'recoil', 'bounces', 'jiggle'}) do
      eq(r[k], nil, t .. ' ' .. k)
    end
    assert(r.flash, 'reduced motion still flashes')
  end
  logic.fear_reaction(2).shake = 99
  eq(logic.FEAR_REACTIONS[2].shake, 1.2, 'a copy')
end

T['idle_due: 25 s, then 45 s more, at most two'] = function()
  eq(logic.idle_due(24.9, 0), false); eq(logic.idle_due(25, 0), true)
  eq(logic.idle_due(44.9, 1), false); eq(logic.idle_due(45, 1), true)
  eq(logic.idle_due(999, 2), false)
end

T['can_fire: idle may repeat and is not spaced; comments have their own gate'] = function()
  eq(logic.can_fire('idle', 'light', {idle = true}, 2, 1), true)
  eq(logic.can_fire('idle', 'none', {}), false)
  eq(logic.SPACED.weak, nil); eq(logic.COMMENTS.weak, true); eq(logic.COMMENTS.read_repeat, true)
  eq(logic.COMMENTS.idle, nil)
end

T['personality moments: 47 run moments, 1 to 3 variants each'] = function()
  eq(#logic.PERSONALITY_MOMENTS, 47)
  for _, m in ipairs(logic.PERSONALITY_MOMENTS) do
    local n = logic.personality_variants(m)
    assert(n >= 1 and n <= 3, m .. ' variants ' .. tostring(n))
  end
  eq(logic.personality_variants('idle'), 2); eq(logic.personality_variants('fear_2'), 3)
  eq(logic.personality_variants('read_repeat'), 2); eq(logic.personality_variants('jab_broke'), 1)
end

T['live_total: the round score plus the displayed hand score; nil when either is missing'] = function()
  eq(logic.live_total(100, 120), 220)
  eq(logic.live_total(0, 120), 120)
  eq(logic.live_total(nil, 120), nil, 'an unreadable round score is no total')
  eq(logic.live_total(100, nil), nil, 'an unreadable hand score is no total')
  eq(logic.live_total(100, '?'), nil, 'a text value')
  eq(logic.live_total(100, 0 / 0), nil, 'nan')
  eq(logic.live_total(100, math.huge), math.huge, 'an infinite hand is a reading')
end

-- Reading scores (1.3.1) ---------------------------------------------------------------------------

--- A big-number object that only prints itself (Amulet-like).
local function printed(s) return setmetatable({}, {__tostring = function() return s end}) end

T['read_number: numbers, numeric strings, nil and other types'] = function()
  eq(logic.read_number(42), 42); eq(logic.read_number(-1.5), -1.5); eq(logic.read_number(0), 0)
  eq(logic.read_number(math.huge), math.huge, 'an infinity is a reading')
  eq(logic.read_number('1500'), 1500); eq(logic.read_number('1.5e3'), 1500)
  eq(logic.read_number('?'), nil, 'a text value'); eq(logic.read_number(''), nil)
  eq(logic.read_number(nil), nil); eq(logic.read_number(true), nil)
end

T['read_number: big-number tables, in reader order'] = function()
  eq(logic.read_number(printed('1.5e300')), 1.5e300, '__tostring')
  eq(logic.read_number(printed('1e400')), math.huge, 'past a double: infinity')
  eq(logic.read_number({to_number = function(self) return self.v end, v = 7}), 7, 'a to_number method')
  eq(logic.read_number({to_number = 8}), 8, 'a to_number field')
  eq(logic.read_number({}, function() return 9 end), 9, 'the global converter')
  eq(logic.read_number({to_number = function() return 7 end}, function() return 9 end), 9,
    'the global converter first')
  eq(logic.read_number({to_number = function() return 7 end}, function() error('not mine') end), 7,
    'a failing converter falls through')
  eq(logic.read_number({m = 1.5, e = 300}), 1.5e300, 'Talisman BigNum layout')
  eq(logic.read_number({array = {1234}, sign = 1}), 1234, 'OmegaNum, small')
  eq(logic.read_number({array = {20, 1}, sign = -1}), -1e20, 'OmegaNum, one 10^')
  eq(logic.read_number({array = {20, 2}, sign = 1}), math.huge, 'OmegaNum, past a double')
end

T['read_number: an unreadable table is nil, never 0'] = function()
  eq(logic.read_number({}), nil)
  eq(logic.read_number(printed('lots')), nil)
  eq(logic.read_number({to_number = function() error('broken') end}), nil, 'a failing method')
  eq(logic.read_number({to_number = function() return 0 / 0 end}), nil, 'nan')
  eq(logic.read_number({}, function(x) return x end), nil, 'a converter that gives a table back')
  local trap = setmetatable({}, {__index = function() error('no fields') end})
  eq(logic.read_number(trap), nil, 'a table that errors on every read')
end

T['hand_outcome: the plain numbers decide when nothing else does'] = function()
  local won, unknown, total = logic.hand_outcome{start = 400, delta = 700, required = 1000}
  eq(won, true); eq(unknown, false); eq(total, 1100)
  won, unknown, total = logic.hand_outcome{start = 100, delta = 5, required = 1000}
  eq(won, false); eq(unknown, false); eq(total, 105)
end

T['hand_outcome: a big-number win counts even when the plain numbers say otherwise'] = function()
  -- the bug: an unreadable score read as 0, so a 2x win looked like a near-0 hand
  local won, unknown = logic.hand_outcome{own = true, start = 0, delta = 0, required = 1000}
  eq(won, true, 'the own-type compare'); eq(unknown, false)
  won = logic.hand_outcome{oneshot = true, own = false, start = 0, delta = 0, required = 1000}
  eq(won, true, 'oneshot first')
  won = logic.hand_outcome{own = false, start = 900, delta = 200, required = 1000}
  eq(won, false, 'a compare that ran decides')
end

T['hand_outcome: unreadable numbers are unknown unless something proves the win'] = function()
  local won, unknown, total = logic.hand_outcome{start = 100, delta = nil, required = 1000}
  eq(won, false); eq(unknown, true); eq(total, nil)
  won, unknown = logic.hand_outcome{start = nil, delta = 50, required = 1000}
  eq(unknown, true, 'an unreadable round score')
  won, unknown = logic.hand_outcome{start = 100, delta = 50, required = nil}
  eq(unknown, true, 'an unreadable requirement')
  won, unknown = logic.hand_outcome{own = false, start = 100, delta = nil, required = 1000}
  eq(won, false); eq(unknown, true, 'short by the compare, but no score to measure')
  won, unknown, total = logic.hand_outcome{oneshot = true, delta = nil, start = nil, required = 1000}
  eq(won, true); eq(unknown, false)
  eq(total, 1000, 'a won hand with no readable total counts as the requirement')
  eq(logic.fear_tier(total, 1000), nil, 'so no fear tier is guessed')
  won, unknown, total = logic.hand_outcome{own = true}
  eq(won, true); eq(unknown, false); eq(total, nil)
end

--- A scored hand through the director's rules: outcome, moment, then the comment gate's inputs.
local function score(o)
  local won, unknown, total = logic.hand_outcome(o)
  local moment = logic.detect_moments{delta = o.delta, total = total, required = o.required,
    hands_left = o.hands_left or 3, fired = {}, tier = 'full', hand = 2, won = won, unknown = unknown}
  return moment, won, unknown, total
end

T['scored hand: a big-number winning hand is the defeat, never weak'] = function()
  local moment, won = score{own = true, start = nil, delta = nil, required = 1000}
  eq(moment, 'defeat'); eq(won, true)
  eq(logic.hit_size(nil, 1000), 'normal', 'an unreadable hand is never weak')
  moment = score{oneshot = true, start = 0, delta = 0, required = 1000}
  eq(moment, 'defeat', 'oneshot with numbers read as 0')
end

T['scored hand: an unknown score fires only last_hand'] = function()
  local moment, won, unknown = score{start = 100, delta = nil, required = 1000}
  eq(moment, nil); eq(won, false); eq(unknown, true)
  eq(score{start = 100, delta = nil, required = 1000, hands_left = 1}, 'last_hand')
  eq(score{start = nil, delta = 900, required = 1000}, nil, 'never big_hand or close')
end

T['fear_step: only a higher tier is announced, once'] = function()
  eq(logic.fear_step(nil, 1), 1, 'first crossing'); eq(logic.fear_step(0, 2), 2)
  eq(logic.fear_step(1, 2), 2, 'escalation'); eq(logic.fear_step(1, 3), 3, 'a skipped tier')
  eq(logic.fear_step(2, 2), nil, 'already said'); eq(logic.fear_step(3, 2), nil, 'lower')
  eq(logic.fear_step(2, nil), nil, 'below 2x'); eq(logic.fear_step(nil, nil), nil)
  eq(logic.fear_step('x', 1), 1, 'a broken saved value counts as none')
end

T['death_tier: the higher of the live tier and the final tier, nil-safe'] = function()
  eq(logic.death_tier(nil, nil), nil); eq(logic.death_tier(0, nil), nil)
  eq(logic.death_tier(2, nil), 2, 'said live, final below'); eq(logic.death_tier(nil, 3), 3, 'never said live')
  eq(logic.death_tier(3, 2), 3); eq(logic.death_tier(1, 2), 2)
end

T['fear_watch: a live boss fight on its blind, a hand scoring, no intro or cinematic'] = function()
  local function a(o)
    local t = {boss = true, ended = false, same_blind = true, hand_played = true, tier = 'light'}
    for k, v in pairs(o or {}) do t[k] = v end
    return t
  end
  eq(logic.fear_watch(a()), true); eq(logic.fear_watch(a{tier = 'full'}), true)
  eq(logic.fear_watch(a{tier = 'none'}), false, 'silent tier')
  eq(logic.fear_watch(a{boss = false}), false); eq(logic.fear_watch(a{ended = true}), false)
  eq(logic.fear_watch(a{same_blind = false}), false); eq(logic.fear_watch(a{hand_played = false}), false)
  eq(logic.fear_watch(a{intro = true}), false); eq(logic.fear_watch(a{cinematic = true}), false)
end

T['slowmo: each death tier plays the tier above it: short at 2x, longer with a flash at 10x, longest at 100x'] = function()
  eq(logic.slowmo(0), nil); eq(logic.slowmo(nil), nil); eq(logic.slowmo(4), nil)
  local s1, s2, s3 = logic.slowmo(1), logic.slowmo(2), logic.slowmo(3)
  eq(s1.duration, 0.6, '2x: the former 10x'); eq(s1.flash, nil)
  eq(s2.duration, 1.2, '10x: the former 100x'); eq(s2.flash, true)
  assert(s3.duration > s2.duration and s3.duration >= 1.8, '100x: the longest freeze')
  assert(s3.scale < s2.scale and s2.scale < s1.scale and s1.scale < 1, 'slower for the bigger win')
  for _, s in ipairs({s1, s2, s3}) do
    assert(s.scale ~= 0.35, 'never the phase freeze value (phases.lua tells them apart by it)')
  end
  for t = 1, 3 do eq(logic.slowmo(t, true), nil, 'reduced motion ' .. t) end
  s1.duration = 99
  eq(logic.SLOWMO[1].duration, 0.6, 'a copy')
end

T['death_boom: 100x explodes inside the freeze once the last words are readable'] = function()
  eq(logic.death_boom(1), 0.6, 'after the slow motion'); eq(logic.death_boom(2), 1.2)
  eq(logic.death_boom(1, true), 0, 'reduced motion: no slow motion to wait for')
  local b = logic.death_boom(3)
  assert(b >= 1.2 and b <= 1.5, 'readable first: ' .. tostring(b))
  assert(b < logic.SLOWMO[3].duration, 'inside the freeze')
  eq(logic.death_boom(3, true), b, 'reduced motion still waits for the line')
  eq(logic.slowmo(3).explode_at, b)
  eq(logic.death_boom(nil), nil); eq(logic.death_boom(0), nil)
end

T['last words: only the 100x death, never a nemesis; the moment has 3 variants'] = function()
  eq(logic.last_words_due(3), true); eq(logic.last_words_due(3, false), true)
  eq(logic.last_words_due(3, true), false, 'a nemesis says its own defeat line')
  eq(logic.last_words_due(2), false); eq(logic.last_words_due(1), false); eq(logic.last_words_due(nil), false)
  local has = false
  for _, m in ipairs(logic.PERSONALITY_MOMENTS) do if m == 'last_words' then has = true end end
  assert(has, 'a personality moment'); eq(logic.personality_variants('last_words'), 3)
end

T['tremble: the avatar shakes harder with the tier, violent at 100x'] = function()
  eq(logic.tremble(0), nil); eq(logic.tremble(nil), nil)
  local t1, t2, t3 = logic.tremble(1), logic.tremble(2), logic.tremble(3)
  assert(t2.amp >= 2 * t1.amp, '10x: clearly more than the plain tremble')
  assert(t3.amp >= 2 * t2.amp and t3.rot, '100x: violent, with a twitching tilt')
end

return T
