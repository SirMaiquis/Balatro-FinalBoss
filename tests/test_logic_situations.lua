-- Win situations, defeat choice, luck tally and hype rules (1.4): pure logic, no game.
local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function win(t)
  local a = {start = 50, total = 120, required = 100, hands_left = 0, hands_played = 3}
  for k, v in pairs(t) do a[k] = v end
  return logic.win_situation(a)
end

function T.win_situation_kinds()
  eq(win({start = 10, total = 110}), 'comeback', 'under 25% before')
  eq(win({}), 'clutch', 'last hand')
  eq(win({total = 104, hands_left = 2}), 'photo_finish')
  eq(win({total = 105, hands_left = 2}), 'photo_finish', 'exactly 5%')
  eq(win({total = 106, hands_left = 2}), nil, 'just over 5%')
  eq(win({start = 0, total = 150, hands_left = 3, hands_played = 1}), nil, 'first hand')
  eq(win({start = 0, total = 102, hands_left = 0, hands_played = 1}), 'photo_finish', 'no hand floor')
  eq(win({start = 10, total = 120, hands_left = 0}), 'comeback', 'comeback beats clutch')
  eq(win({start = 10, total = 102, hands_left = 0}), 'comeback', 'comeback beats photo finish')
  eq(win({total = 101, hands_left = 0}), 'clutch', 'clutch beats photo finish')
  eq(win({start = 25, total = 150, hands_left = 1}), nil, '25% is not under 25%')
end

function T.win_situation_nil_numbers()
  for _, k in ipairs({'start', 'total', 'required', 'hands_left', 'hands_played'}) do
    local a = {start = 10, total = 110, required = 100, hands_left = 0, hands_played = 3}
    a[k] = nil
    eq(logic.win_situation(a), nil, 'nil ' .. k)
    a[k] = 0 / 0
    eq(logic.win_situation(a), nil, 'nan ' .. k)
  end
end

function T.situation_candidate_cases()
  local function cand(t)
    local a = {start = 50, required = 100, hands_left = 1, hands_played = 2}
    for k, v in pairs(t) do a[k] = v end
    return logic.situation_candidate(a)
  end
  eq(cand({hands_left = 0}), true, 'last hand')
  eq(cand({start = 10}), true, 'low start')
  eq(cand({}), false, 'neither')
  eq(cand({hands_left = 0, hands_played = 1}), false, 'first hand')
  eq(cand({start = 10, hands_played = 1}), false, 'first hand low start')
  eq(cand({start = false, hands_left = 1}), false, 'nil start')
end

function T.defeat_choice_priority()
  local function pick(s, t) return logic.defeat_choice({situation = s, fear_tier = t}) end
  eq(pick('comeback', 3), 'fear_3')
  eq(pick('comeback', 2), 'comeback')
  eq(pick('clutch', 1), 'clutch')
  eq(pick('clutch', nil), 'clutch')
  eq(pick('photo_finish', 2), 'photo_finish')
  eq(pick(nil, 3), 'fear_3')
  eq(pick(nil, 2), 'fear_2')
  eq(pick(nil, 1), 'fear_1')
  eq(pick(nil, 0), 'defeat')
  eq(pick(nil, nil), 'defeat')
end

local function luck(...)
  local t = logic.new_luck()
  for _, k in ipairs({...}) do logic.note_luck(t, k, k == 'joker' and 'j_oops' or nil) end
  return t
end

function T.luck_tally()
  local t = logic.new_luck()
  eq(t.cards, 0); eq(t.dollars, 0); eq(t.joker, nil)
  eq(logic.luck_moment(t), nil)
  t = luck('card', 'card')
  eq(logic.luck_moment(t), 'lucky_cards'); eq(logic.luck_stacked(t), false)
  eq(logic.luck_moment(luck('card')), nil)
  eq(logic.luck_moment(luck('dollars')), 'lucky_cards')
  t = luck('joker')
  eq(logic.luck_moment(t), 'lucky_joker'); eq(t.joker, 'j_oops')
  eq(logic.luck_stacked(luck('card', 'card', 'card')), true)
  eq(logic.luck_stacked(luck('dollars', 'joker')), true)
  eq(logic.luck_stacked(luck('card', 'joker')), false)
  eq(logic.luck_moment(luck('card', 'joker')), 'lucky_joker')
end

function T.hype_text()
  eq(logic.HYPE_TEXT.clutch, 'CLUTCH!'); eq(logic.HYPE_TEXT.overkill, 'OVERKILL!')
  eq(logic.HYPE_TEXT.photo_finish, 'PHOTO FINISH!'); eq(logic.HYPE_TEXT.lucky, 'LUCKY!')
  eq(logic.HYPE_TEXT.comeback, 'COMEBACK!')
  eq(logic.PHOTO_FINISH, 0.05); eq(logic.COMEBACK_RATIO, 0.25); eq(logic.SITUATION_MIN_HANDS, 2)
end

function T.hype_for_rules()
  local function h(said, moment, stacked) return logic.hype_for({said = said, defeat_moment = moment, stacked = stacked}) end
  local r = h(false, 'fear_3', false); eq(r.kind, 'overkill'); eq(r.meltdown, false)
  r = h(false, 'fear_3', true); eq(r.kind, 'overkill', 'overkill beats lucky')
  r = h(false, 'comeback', false); eq(r.kind, 'comeback'); eq(r.meltdown, true)
  r = h(false, 'clutch', false); eq(r.kind, 'clutch'); eq(r.meltdown, true)
  r = h(false, 'photo_finish', false); eq(r.kind, 'photo_finish'); eq(r.meltdown, false)
  r = h(false, nil, true); eq(r.kind, 'lucky'); eq(r.meltdown, true)
  r = h(false, 'fear_2', true); eq(r.kind, 'lucky'); eq(r.meltdown, false)
  r = h(false, 'defeat', true); eq(r.kind, 'lucky'); eq(r.meltdown, false)
  eq(h(false, nil, false), nil); eq(h(false, 'fear_2', false), nil); eq(h(false, 'defeat', false), nil)
  for _, m in ipairs({'fear_3', 'comeback', 'clutch', 'photo_finish', 'fear_2', 'defeat'}) do
    eq(h(true, m, true), nil, 'said ' .. m)
  end
  eq(h(true, nil, true), nil)
end

return T
