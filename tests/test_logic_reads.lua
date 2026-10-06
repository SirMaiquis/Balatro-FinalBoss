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
  eq(read{discards_left = 0, hands_left = 3}, 'read_discardspam'); eq(read{discards_left = 0, hands_left = 2}, nil)
  eq(read{discards_left = 0, discards_used = 0, hands_left = 3}, nil, 'The Water took them: no spam')
  eq(read{cards_played = 1}, 'read_onecard')
end

T['fight_read: order, and nothing repeats in a blind'] = function()
  eq(read{streak = 3, cards_played = 1, hand_type = 'High Card'}, 'read_repeat')
  eq(read({streak = 3, cards_played = 1, hand_type = 'High Card'}, {read_repeat = true}), 'read_onecard')
  eq(read({cards_played = 1, hand_type = 'High Card'}, {read_onecard = true, read_weakhand = true}), nil)
end

local CAN = {moment = 'read_onecard', tier = 'full', fired = {}, reactions = 0, comments = 0, hand = 3}
local function can(o) return logic.can_comment(with(CAN, o)) end

T['can_comment: the light tier uses its single reaction slot'] = function()
  eq(can{tier = 'light'}, true)
  eq(can{tier = 'light', reactions = 1}, false)
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
  eq(can{moment = 'weak', tier = 'light', reactions = 1}, false)
  eq(can{moment = 'weak', fired = {weak = true}}, false)
  eq(can{moment = 'weak', tier = 'none'}, false)
end

T['pick_comment: weak neither waits for nor feeds the comment caps'] = function()
  local a = {weak = true, hand_type = 'Flush', streak = 1, discards_left = 1, discards_used = 0,
    hands_left = 3, cards_played = 5, tier = 'full', fired = {}, reactions = 0, comments = 3,
    last_comment_hand = 3, hand = 4}
  eq(logic.pick_comment(a), 'weak', 'cap reached and consecutive, still weak')
  a.fired = {weak = true}
  eq(logic.pick_comment(a), nil)
end

T['pick_comment: the weak line first, then a read, within the caps'] = function()
  local a = {weak = true, hand_type = 'High Card', streak = 1, discards_left = 1, discards_used = 0,
    hands_left = 3, cards_played = 2, tier = 'full', fired = {}, reactions = 0, comments = 0, hand = 4}
  eq(logic.pick_comment(a), 'weak')
  a.fired = {weak = true}
  eq(logic.pick_comment(a), 'read_weakhand')
  a.last_comment_hand = 3
  eq(logic.pick_comment(a), nil, 'consecutive hand')
  local light = {weak = false, hand_type = 'Flush', streak = 1, discards_left = 1, discards_used = 0,
    hands_left = 3, cards_played = 5, tier = 'light', fired = {}, reactions = 0, comments = 0, hand = 1}
  eq(logic.pick_comment(light), nil, 'nothing to say')
  light.weak = true; light.reactions = 1
  eq(logic.pick_comment(light), nil, 'the light slot is taken')
end

T['note_comment: books fired, the slot, the count and the hand'] = function()
  local enc = {fired = {}, reactions = 0}
  logic.note_comment(enc, 'read_onecard', 2)
  eq(enc.fired.read_onecard, true); eq(enc.reactions, 1); eq(enc.comments, 1); eq(enc.last_comment_hand, 2)
  logic.note_comment(enc, 'read_repeat', 4)
  eq(enc.comments, 2); eq(enc.last_comment_hand, 4)
end

T['note_comment: weak is a reaction, not a run comment'] = function()
  local enc = {fired = {}, reactions = 0}
  logic.note_comment(enc, 'weak', 2)
  eq(enc.fired.weak, true); eq(enc.reactions, 1)
  eq(enc.comments or 0, 0, 'no run comment'); eq(enc.last_comment_hand, nil, 'no hand booked')
end

T['is_overkill: at least twice the requirement'] = function()
  eq(logic.is_overkill(200, 100), true); eq(logic.is_overkill(199, 100), false)
  eq(logic.is_overkill(10, 0), false); eq(logic.is_overkill(10, nil), false)
end

T['idle_due: 25 s, then 45 s more, at most two'] = function()
  eq(logic.idle_due(24.9, 0), false); eq(logic.idle_due(25, 0), true)
  eq(logic.idle_due(44.9, 1), false); eq(logic.idle_due(45, 1), true)
  eq(logic.idle_due(999, 2), false)
end

T['can_fire: idle may repeat; comments are not reactions'] = function()
  eq(logic.can_fire('idle', 'light', {idle = true}, 1), true)
  eq(logic.can_fire('idle', 'none', {}, 0), false)
  eq(logic.REACTIONS.weak, nil); eq(logic.COMMENTS.weak, true); eq(logic.COMMENTS.read_repeat, true)
  eq(logic.COMMENTS.idle, nil)
end

T['personality moments: 18 run moments, 1 or 2 variants each'] = function()
  eq(#logic.PERSONALITY_MOMENTS, 18)
  for _, m in ipairs(logic.PERSONALITY_MOMENTS) do
    local n = logic.personality_variants(m)
    assert(n == 1 or n == 2, m .. ' variants ' .. tostring(n))
  end
  eq(logic.personality_variants('idle'), 2); eq(logic.personality_variants('overkill'), 2)
  eq(logic.personality_variants('read_repeat'), 2); eq(logic.personality_variants('jab_broke'), 1)
end

return T
