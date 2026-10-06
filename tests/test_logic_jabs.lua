local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- A scripted math.random: rand() (the chance roll) gives roll; rand(n) gives pick(n), else 1.
--- calls records every call: 'roll' or the n asked for.
local function script(roll, pick)
  local r = {calls = {}}
  setmetatable(r, {__call = function(_, n)
    if n == nil then
      r.calls[#r.calls + 1] = 'roll'
      return roll
    end
    r.calls[#r.calls + 1] = n
    return pick and pick(n) or 1
  end})
  return r
end

local function first() return 1 end
local function last(n) return n end
local PASS = 0                             -- a chance roll that passes (< JAB_CHANCE)
local FAIL = 0.99                          -- a chance roll that fails
local function no_roll(n)                  -- rand for a counter jab: the chance roll must not happen
  if n == nil then error('chance rolled for a counter jab', 2) end
  return n
end

--- A run no jab applies to, with overrides.
local function run(o)
  local s = {jokers = {'j_joker'}, joker_count = 1, joker_slots = 5, skipped = 0, rerolls = 0, dollars = 10,
    deck_size = 52, suit_max = 13, signature = 'j_luchador'}
  for k, v in pairs(o or {}) do s[k] = v end
  return s
end

--- The jab for run(o); rand defaults to a passing chance roll and the first candidate.
local function jab(o, rand)
  local j = logic.intro_jab(run(o), rand or script(PASS, first))
  if not j then return nil end
  return j.moment, j.joker
end

T['intro_jab: a plain run gets no jab'] = function() eq(jab(), nil) end

T['intro_jab: the chance is a third'] = function() eq(logic.JAB_CHANCE, 1 / 3) end

T['intro_jab: thresholds'] = function()
  eq(jab{skipped = 1}, 'jab_skipped'); eq(jab{skipped = 2}, 'jab_skipped_both')
  eq(jab{rerolls = 4}, nil); eq(jab{rerolls = 5}, 'jab_rerolls')
  eq(jab{dollars = 3}, 'jab_broke'); eq(jab{dollars = 4}, nil)
  eq(jab{dollars = 49}, nil); eq(jab{dollars = 50}, 'jab_loaded')
  eq(jab{suit_max = 39}, 'jab_onesuit', '39 of 52 is 75%'); eq(jab{suit_max = 38}, nil)
  eq(jab{deck_size = 30, suit_max = 8}, 'jab_tinydeck'); eq(jab{deck_size = 31, suit_max = 8}, nil)
  eq(jab{deck_size = 70, suit_max = 18}, 'jab_hugedeck'); eq(jab{deck_size = 69, suit_max = 18}, nil)
  eq(jab{jokers = {}, joker_count = 0}, 'jab_nojokers')
  eq(jab{joker_count = 5}, 'jab_fulljokers'); eq(jab{joker_count = 4}, nil)
end

T['intro_jab: a counter always wins, with no chance roll; the signature counter first'] = function()
  local m, j = jab({jokers = {'j_matador', 'j_blueprint'}, skipped = 2, dollars = 0}, no_roll)
  eq(m, 'jab_counter'); eq(j, 'j_matador')
  m, j = jab({jokers = {'j_mr_bones', 'j_luchador'}}, no_roll)
  eq(j, 'j_luchador', 'the signature wins over rand')
  m, j = jab({jokers = {'j_chicot'}, signature = 'j_chicot'}, no_roll)
  eq(m, 'jab_counter'); eq(j, 'j_chicot')
  m, j = jab({jokers = {'j_chicot', 'j_mr_bones'}}, no_roll)
  eq(j, 'j_mr_bones', 'no signature owned: rand picks among the owned counters')
  m = jab({jokers = {'j_luchador'}, last_jab = 'jab_counter'}, no_roll)
  eq(m, 'jab_counter', 'a counter even right after a counter jab')
end

T['intro_jab: the chance roll fails, no jab'] = function()
  eq(jab({skipped = 2, dollars = 0}, script(FAIL)), nil)
  eq(jab({skipped = 2, dollars = 0}, script(logic.JAB_CHANCE)), nil, 'the roll must be below the chance')
end

T['intro_jab: the roll passes, every applicable jab is a candidate, no tiers'] = function()
  local applies = {skipped = 2, dollars = 0, jokers = {'j_blueprint'}, joker_count = 5}
  local want = {'jab_skipped_both', 'jab_broke', 'jab_fulljokers', 'jab_famous'}
  for i, moment in ipairs(want) do
    local rand = script(PASS, function(n) return n == #want and i or 1 end)
    eq(jab(applies, rand), moment, 'pick ' .. i)
    eq(rand.calls[1], 'roll', 'the chance is rolled first')
    eq(rand.calls[2], #want, 'one flat list of candidates')
  end
  local m, j = jab({jokers = {'j_joker', 'j_baron', 'j_dna'}}, script(PASS, last))
  eq(m, 'jab_famous'); eq(j, 'j_dna', 'a famous joker passes its key')
end

T['intro_jab: the last jab said this run is no candidate'] = function()
  local rand = script(PASS, first)
  eq(jab({skipped = 2, dollars = 0, last_jab = 'jab_skipped_both'}, rand), 'jab_broke')
  eq(rand.calls[2], 1, 'one candidate left')
  eq(jab({skipped = 2, dollars = 0, last_jab = 'jab_broke'}, script(PASS, last)), 'jab_skipped_both')
end

T['intro_jab: the only candidate was the last jab, no jab'] = function()
  local rand = script(PASS)
  eq(jab({dollars = 0, last_jab = 'jab_broke'}, rand), nil)
  eq(#rand.calls, 0, 'no roll without a candidate')
end

T['intro_jab: force skips the chance roll'] = function()
  local rand = script(FAIL, first)
  eq(jab({dollars = 0, force = true}, rand), 'jab_broke')
  eq(rand.calls[1], 1, 'no chance roll')
end

T['signature_counter: Chicot for the final bosses, Luchador for the rest'] = function()
  for _, k in ipairs(logic.FINAL_BOSSES) do eq(logic.signature_counter(k), 'j_chicot', k) end
  eq(logic.signature_counter('bl_hook'), 'j_luchador')
  eq(logic.signature_counter('bl_mymod_boss'), 'j_luchador')
end

T['apply_jab: the jab replaces the threat; memory lines stay'] = function()
  local plan, at = logic.apply_jab({'name', 'intro'}, 'jab_broke')
  eq(table.concat(plan, ','), 'name,jab_broke'); eq(at, 2)
  plan, at = logic.apply_jab({'intro'}, nil)
  eq(table.concat(plan, ','), 'intro'); eq(at, 1)
  plan, at = logic.apply_jab({'nemesis_intro'}, 'jab_broke')
  eq(table.concat(plan, ','), 'nemesis_intro'); eq(at, nil)
  plan, at = logic.apply_jab({'rematch_won', 'intro'}, 'jab_famous')
  eq(table.concat(plan, ','), 'rematch_won,jab_famous'); eq(at, 2)
end

T['apply_jab: a light-tier rematch line gives way to the jab, a nemesis line does not'] = function()
  local plan, at = logic.apply_jab({'rematch_won'}, 'jab_broke')
  eq(table.concat(plan, ','), 'jab_broke'); eq(at, 1)
  plan, at = logic.apply_jab({'rematch_lost'}, 'jab_counter')
  eq(table.concat(plan, ','), 'jab_counter'); eq(at, 1)
  plan, at = logic.apply_jab({'rematch_lost'}, nil)
  eq(table.concat(plan, ','), 'rematch_lost'); eq(at, nil)
  plan, at = logic.apply_jab({'nemesis_intro'}, nil)
  eq(table.concat(plan, ','), 'nemesis_intro'); eq(at, nil)
end

T['apply_jab: with the real intro plan, nemesis > jab > rematch > threat (light tier)'] = function()
  local function plan(a)
    a.tier, a.memory = 'light', true
    return logic.intro_plan(a)
  end
  local p = logic.apply_jab(plan{nemesis = true, last = 'lost', roll = 0}, 'jab_broke')
  eq(p[1], 'nemesis_intro')
  p = logic.apply_jab(plan{last = 'won', roll = 0}, 'jab_broke')
  eq(p[1], 'jab_broke', 'the jab beats the rematch line')
  p = logic.apply_jab(plan{last = 'won', roll = 0}, nil)
  eq(p[1], 'rematch_won', 'no jab: the rematch line stands')
  p = logic.apply_jab(plan{roll = 0}, 'jab_broke')
  eq(p[1], 'jab_broke', 'the jab beats the threat')
  p = logic.apply_jab(plan{roll = 0}, nil)
  eq(p[1], 'intro')
end

T['apply_jab: full tier, two lines; the jab replaces the threat whatever the name line became'] = function()
  local function plan(a)
    a.tier, a.memory = 'full', true
    return logic.intro_plan(a)
  end
  local p, at = logic.apply_jab(plan{nemesis = true}, 'jab_broke')
  eq(table.concat(p, ','), 'nemesis_intro,jab_broke'); eq(at, 2)
  p, at = logic.apply_jab(plan{last = 'lost'}, 'jab_broke')
  eq(table.concat(p, ','), 'rematch_lost,jab_broke'); eq(at, 2)
  p, at = logic.apply_jab(plan{}, 'jab_broke')
  eq(table.concat(p, ','), 'name,jab_broke'); eq(at, 2)
  p, at = logic.apply_jab(plan{}, nil)
  eq(table.concat(p, ','), 'name,intro'); eq(at, 2)
end

T['has_censored: a letter followed by a star'] = function()
  for _, s in ipairs({'f***', 'Holy sh*t!', 'Move, a**.', 'You f***ing clown', 'Sch*iße', 'ク*', 'г*вно'}) do
    eq(logic.has_censored(s), true, s)
  end
  for _, s in ipairs({'damn', 'hell no', '5 * 3', '* * *', '', '#1#!'}) do eq(logic.has_censored(s), false, s) end
  eq(logic.has_censored(nil), false)
end

T['bleep: a vanilla sound, pitched high'] = function()
  eq(type(logic.BLEEP.sound), 'string')
  assert(logic.BLEEP.pitch > 1.5, 'high pitch')
  assert(logic.BLEEP.volume > 0 and logic.BLEEP.volume <= 1, 'volume in (0, 1]')
end

return T
