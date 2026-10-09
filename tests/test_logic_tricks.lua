local logic = require('src.logic')
local T = {}
local function eq(a, e, m) if a ~= e then error((m or 'value') .. ': expected ' .. tostring(e) .. ', got ' .. tostring(a), 2) end end

T['trick: once per kind per blind, one shared gap'] = function()
  local s = {}
  eq(logic.trick_reaction(s, 'Tarot', 10), 'used_tarot')
  eq(logic.trick_reaction(s, 'Tarot', 30), nil, 'tarot again: once per blind')
  eq(logic.trick_reaction(s, 'Planet', 12), nil, 'inside the gap')
  eq(logic.trick_reaction(s, 'Planet', 14), 'used_planet', 'gap over')
  eq(logic.trick_reaction(s, 'Joker', 15), nil, 'a spectral that makes a joker: one line')
  eq(logic.trick_reaction(s, 'Joker', 19), 'joker_created')
  eq(logic.trick_reaction(s, 'Spectral', 40), 'used_spectral')
  eq(logic.trick_reaction(s, 'Voucher', 50), nil, 'unknown kind')
end
T['trick: a kind refused by the gap can still fire later'] = function()
  local s = {}
  eq(logic.trick_reaction(s, 'Tarot', 10), 'used_tarot')
  eq(logic.trick_reaction(s, 'Planet', 11), nil)
  eq(logic.trick_reaction(s, 'Planet', 20), 'used_planet')
end
T['trick: a clock that went backwards (loaded save) does not block'] = function()
  local s = {last = 1000}
  eq(logic.trick_reaction(s, 'Tarot', 5), 'used_tarot')
end
T['trick_allowed: only in the live fight'] = function()
  local ok = {boss = true, ended = false, won = false, same_blind = true, tier = 'light', playing = true,
    intro = false, cinematic = false, overlay = false, paused = false}
  assert(logic.trick_allowed(ok))
  for _, k in ipairs({'ended', 'won', 'intro', 'cinematic', 'overlay', 'paused'}) do
    local a = {}; for x, v in pairs(ok) do a[x] = v end; a[k] = true
    assert(not logic.trick_allowed(a), k)
  end
  for _, k in ipairs({'boss', 'same_blind', 'playing'}) do
    local a = {}; for x, v in pairs(ok) do a[x] = v end; a[k] = false
    assert(not logic.trick_allowed(a), k)
  end
  local a = {}; for x, v in pairs(ok) do a[x] = v end; a.tier = 'none'
  assert(not logic.trick_allowed(a), 'below the dialogue ante')
end
T['trick moments are personality moments with 3 variants'] = function()
  local has = {}
  for _, m in ipairs(logic.PERSONALITY_MOMENTS) do has[m] = true end
  for _, m in ipairs({'used_tarot', 'used_spectral', 'used_planet', 'joker_created'}) do
    assert(has[m], m); eq(logic.personality_variants(m), 3)
  end
end
return T
