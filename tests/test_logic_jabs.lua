local logic = require('src.logic')
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local function first() return 1 end
local function last(n) return n end

--- A run no jab applies to, with overrides.
local function run(o)
  local s = {jokers = {'j_joker'}, joker_count = 1, joker_slots = 5, skipped = 0, rerolls = 0, dollars = 10,
    deck_size = 52, suit_max = 13, signature = 'j_luchador'}
  for k, v in pairs(o or {}) do s[k] = v end
  return s
end

local function jab(o, rand)
  local j = logic.intro_jab(run(o), rand or first)
  if not j then return nil end
  return j.moment, j.joker
end

T['intro_jab: a plain run gets no jab'] = function() eq(jab(), nil) end

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

T['intro_jab: counters come first, the signature counter before the others'] = function()
  local m, j = jab{jokers = {'j_matador', 'j_blueprint'}, skipped = 2, dollars = 0}
  eq(m, 'jab_counter'); eq(j, 'j_matador')
  m, j = jab({jokers = {'j_mr_bones', 'j_luchador'}}, last)
  eq(j, 'j_luchador', 'the signature wins over rand')
  m, j = jab{jokers = {'j_chicot'}, signature = 'j_chicot'}
  eq(m, 'jab_counter'); eq(j, 'j_chicot')
  m, j = jab({jokers = {'j_chicot', 'j_mr_bones'}}, last)
  eq(j, 'j_mr_bones', 'no signature owned: rand picks among the owned counters')
end

T['intro_jab: priority 2 beats 3 beats 4; ties go to rand'] = function()
  eq(jab{skipped = 1, jokers = {}, joker_count = 0}, 'jab_skipped')
  eq(jab{jokers = {'j_blueprint'}, joker_count = 5}, 'jab_fulljokers')
  local m, j = jab{jokers = {'j_blueprint'}}
  eq(m, 'jab_famous'); eq(j, 'j_blueprint')
  eq(jab({skipped = 1, dollars = 0}, first), 'jab_skipped')
  eq(jab({skipped = 1, dollars = 0}, last), 'jab_broke')
end

T['intro_jab: a famous joker passes its key'] = function()
  local m, j = jab({jokers = {'j_joker', 'j_baron', 'j_dna'}}, last)
  eq(m, 'jab_famous'); eq(j, 'j_dna')
end

T['signature_counter: Chicot for the final bosses, Luchador for the rest'] = function()
  for _, k in ipairs(logic.FINAL_BOSSES) do eq(logic.signature_counter(k), 'j_chicot', k) end
  eq(logic.signature_counter('bl_hook'), 'j_luchador')
  eq(logic.signature_counter('bl_mymod_boss'), 'j_luchador')
end

T['apply_jab: the jab replaces the threat; memory lines stay'] = function()
  local plan, at = logic.apply_jab({'opener', 'name', 'intro', 'closer'}, 'jab_broke')
  eq(table.concat(plan, ','), 'opener,name,jab_broke,closer'); eq(at, 3)
  plan, at = logic.apply_jab({'intro'}, nil)
  eq(table.concat(plan, ','), 'intro'); eq(at, 1)
  plan, at = logic.apply_jab({'nemesis_intro'}, 'jab_broke')
  eq(table.concat(plan, ','), 'nemesis_intro'); eq(at, nil)
  plan, at = logic.apply_jab({'rematch_won', 'generic_name', 'intro', 'closer'}, 'jab_famous')
  eq(plan[3], 'jab_famous'); eq(at, 3)
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

T['apply_jab: full tier, the jab replaces the threat whatever the opener became'] = function()
  local function plan(a)
    a.tier, a.memory = 'full', true
    return logic.intro_plan(a)
  end
  local p, at = logic.apply_jab(plan{nemesis = true}, 'jab_broke')
  eq(table.concat(p, ','), 'nemesis_intro,generic_name,jab_broke,closer'); eq(at, 3)
  p, at = logic.apply_jab(plan{last = 'lost'}, 'jab_broke')
  eq(table.concat(p, ','), 'rematch_lost,generic_name,jab_broke,closer'); eq(at, 3)
  p, at = logic.apply_jab(plan{}, 'jab_broke')
  eq(table.concat(p, ','), 'opener,name,jab_broke,closer'); eq(at, 3)
end

T['has_censored: a letter followed by a star'] = function()
  for _, s in ipairs({'f***', 'Holy sh*t!', 'Move, a**.', 'You f***ing clown', 'Sch*iße', 'ク*', 'г*вно'}) do
    eq(logic.has_censored(s), true, s)
  end
  for _, s in ipairs({'damn', 'hell no', '5 * 3', '* * *', '', '#1#!'}) do eq(logic.has_censored(s), false, s) end
  eq(logic.has_censored(nil), false)
end

T['flex_recipe: flex, then signature, then the generic burst'] = function()
  eq(logic.flex_recipe({flex = 'f', signature = 's'}), 'f')
  eq(logic.flex_recipe({signature = 's'}), 's')
  eq(logic.flex_recipe({play = {}}), logic.GENERIC_RECIPE)
  eq(logic.flex_recipe(nil), logic.GENERIC_RECIPE)
  assert(logic.MOVE_KINDS.flex, 'flex is a move kind')
end

T['bleep: a vanilla sound, pitched high'] = function()
  eq(type(logic.BLEEP.sound), 'string')
  assert(logic.BLEEP.pitch > 1.5, 'high pitch')
  assert(logic.BLEEP.volume > 0 and logic.BLEEP.volume <= 1, 'volume in (0, 1]')
end

return T
