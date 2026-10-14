local logic = require('src.logic')
local T = {}
local function eq(a, e, m) if a ~= e then error((m or 'value') .. ': expected ' .. tostring(e) .. ', got ' .. tostring(a), 2) end end

T['trick: consumables fire whenever the gap has passed, a joker once per blind'] = function()
  local s = {}
  eq(logic.trick_reaction(s, 'Tarot', 10), 'used_tarot')
  eq(logic.trick_reaction(s, 'Tarot', 12), nil, 'a second tarot inside the gap: collapsed')
  eq(logic.trick_reaction(s, 'Planet', 12), nil, 'inside the gap')
  eq(logic.trick_reaction(s, 'Planet', 14), 'used_planet', 'gap over')
  eq(logic.trick_reaction(s, 'Joker', 15), nil, 'a spectral that makes a joker: one line')
  eq(logic.trick_reaction(s, 'Joker', 19), 'joker_created')
  eq(logic.trick_reaction(s, 'Joker', 40), nil, 'joker again: once per blind')
  eq(logic.trick_reaction(s, 'Tarot', 30), 'used_tarot', 'tarot again after the gap: fires')
  eq(logic.trick_reaction(s, 'Spectral', 40), 'used_spectral')
  eq(logic.trick_reaction(s, 'Spectral', 44), 'used_spectral', 'exactly the gap: fires')
  eq(logic.trick_reaction(s, 'Planet', 50), 'used_planet')
  eq(logic.trick_reaction(s, 'Planet', 53.9), nil, 'planet spam inside the gap')
  eq(logic.trick_reaction(s, 'Voucher', 70), nil, 'unknown kind')
  eq(s.seen.Tarot, nil, 'consumables are never marked seen')
end

-- consumable_moment ---------------------------------------------------------------------------------

local GROUPS = {
  Tarot = {enhance = {'c_magician', 'c_empress', 'c_heirophant', 'c_lovers', 'c_chariot', 'c_justice',
    'c_devil', 'c_tower'}, suit = {'c_star', 'c_moon', 'c_sun', 'c_world'}, rank = {'c_strength'},
    destroy = {'c_hanged_man'}, copy = {'c_death'}, money = {'c_hermit', 'c_temperance'},
    create = {'c_fool', 'c_high_priestess', 'c_emperor', 'c_judgement'}, gamble = {'c_wheel_of_fortune'}},
  Spectral = {joker = {'c_soul', 'c_wraith', 'c_ankh', 'c_hex', 'c_ectoplasm'},
    deck = {'c_familiar', 'c_grim', 'c_incantation', 'c_immolate', 'c_cryptid'},
    seal = {'c_talisman', 'c_deja_vu', 'c_trance', 'c_medium'}, transform = {'c_sigil', 'c_ouija', 'c_aura'},
    blackhole = {'c_black_hole'}},
}

T['consumable_moment: every vanilla tarot and spectral maps to its group'] = function()
  local n = {Tarot = 0, Spectral = 0}
  for set, groups in pairs(GROUPS) do
    for group, keys in pairs(groups) do
      for _, key in ipairs(keys) do
        local want = (set == 'Tarot' and 'used_tarot_' or 'used_spectral_') .. group
        eq(logic.consumable_moment(set, key), want, key)
        n[set] = n[set] + 1
      end
    end
  end
  eq(n.Tarot, 22, 'all 22 tarots'); eq(n.Spectral, 18, 'all 18 spectrals')
  local listed = 0
  for _, set in pairs(logic.CONSUMABLE_GROUPS) do for _ in pairs(set) do listed = listed + 1 end end
  eq(listed, 40, 'no extra keys in CONSUMABLE_GROUPS')
end

T['consumable_moment: a modded card uses the set fallback'] = function()
  eq(logic.consumable_moment('Tarot', 'c_mymod_thing'), 'used_tarot')
  eq(logic.consumable_moment('Spectral', 'c_mymod_ghost'), 'used_spectral')
  eq(logic.consumable_moment('Tarot', nil), 'used_tarot', 'no key')
  eq(logic.consumable_moment('Tarot', 'c_soul'), 'used_tarot', 'a spectral key under Tarot')
  eq(logic.consumable_moment('Voucher', 'v_overstock'), nil)
  eq(logic.consumable_moment('Joker', 'j_joker'), nil)
end

T['consumable_moment: planets read the hand history'] = function()
  local function p(played, max_played) return logic.consumable_moment('Planet', 'c_mercury',
    {played = played, max_played = max_played}) end
  eq(p(12, 12), 'used_planet_main', 'the most played hand, or tied for it')
  eq(p(0, 30), 'used_planet_waste', 'never played')
  eq(p(2, 30), 'used_planet_waste', 'under a tenth')
  eq(p(3, 30), 'used_planet', 'exactly a tenth: neither')
  eq(p(10, 30), 'used_planet', 'in between')
  eq(p(0, 0), 'used_planet_waste', 'nothing played yet: waste (the hand has 0 played)')
  eq(p(1, 1), 'used_planet_main', 'the only hand played once')
  eq(logic.consumable_moment('Planet', 'c_mymod_planet', nil), 'used_planet', 'no history: fallback')
end

T['card-specific moments are personality moments with 2 variants; the fallbacks have 2'] = function()
  local has = {}
  for _, m in ipairs(logic.PERSONALITY_MOMENTS) do has[m] = true end
  for _, g in ipairs(logic.TAROT_GROUPS) do
    assert(has['used_tarot_' .. g], g); eq(logic.personality_variants('used_tarot_' .. g), 2)
  end
  for _, g in ipairs(logic.SPECTRAL_GROUPS) do
    assert(has['used_spectral_' .. g], g); eq(logic.personality_variants('used_spectral_' .. g), 2)
  end
  for _, m in ipairs({'used_planet_main', 'used_planet_waste', 'used_tarot', 'used_spectral', 'used_planet'}) do
    assert(has[m], m); eq(logic.personality_variants(m), 2, m)
  end
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
T['trick: the same card once per turn'] = function()
  local s = {}
  eq(logic.trick_reaction(s, 'Tarot', 10, 'c_star'), 'used_tarot')
  eq(logic.trick_reaction(s, 'Tarot', 20, 'c_star'), nil, 'same key, same turn, gap passed')
  eq(logic.trick_reaction(s, 'Tarot', 12, 'c_moon'), nil, 'another key inside the gap')
  eq(s.turn_keys.c_moon, nil, 'refused: not booked')
  eq(logic.trick_reaction(s, 'Tarot', 30, 'c_moon'), 'used_tarot', 'another key after the gap')
  eq(logic.trick_reaction(s, 'Joker', 40, 'c_star'), nil, 'a joker line for a booked card')
  logic.trick_new_turn(s)
  eq(s.turn_keys, nil)
  eq(logic.trick_reaction(s, 'Tarot', 40, 'c_star'), 'used_tarot', 'a hand was played')
  eq(logic.trick_reaction(s, 'Tarot', 50), 'used_tarot', 'no key: never booked')
  logic.trick_new_turn(nil) -- no tricks yet: nothing to clear
end
T['joker_card_resolution: the joker line only for a new joker not yet named this blind'] = function()
  eq(logic.joker_card_resolution(true, false), 'Joker')
  eq(logic.joker_card_resolution(true, true), 'card', 'joker_created already said')
  eq(logic.joker_card_resolution(false, false), 'card', 'no joker came (full slots)')
  eq(logic.joker_card_resolution(nil, nil), 'card')
end
T['wheel_moment: hit, miss, rigged on either, nil-safe'] = function()
  eq(logic.wheel_moment(true, 1, 4), 'used_tarot_wheel_hit')
  eq(logic.wheel_moment(false, 1, 4), 'used_tarot_wheel_miss')
  eq(logic.wheel_moment(true, 2, 4), 'used_tarot_wheel_rigged', 'Oops! All 6s, hit')
  eq(logic.wheel_moment(false, 2, 4), 'used_tarot_wheel_rigged', 'Oops! All 6s, miss')
  eq(logic.wheel_moment(nil, nil, nil), 'used_tarot_wheel_miss')
  eq(logic.wheel_moment(true, 2, nil), 'used_tarot_wheel_hit', 'unknown odds are fair')
  eq(logic.wheel_moment(false, 2, 0), 'used_tarot_wheel_miss', 'no divide by zero')
  eq(logic.wheel_moment(true, 0.5, 4), 'used_tarot_wheel_hit', 'worse odds are not rigged')
end
T['wheel moments are personality moments with 2 variants'] = function()
  local has = {}
  for _, m in ipairs(logic.PERSONALITY_MOMENTS) do has[m] = true end
  for _, r in ipairs({'hit', 'miss', 'rigged'}) do
    assert(has['used_tarot_wheel_' .. r], r); eq(logic.personality_variants('used_tarot_wheel_' .. r), 2)
  end
end
T['joker_created is a personality moment with 3 variants'] = function()
  local has = {}
  for _, m in ipairs(logic.PERSONALITY_MOMENTS) do has[m] = true end
  assert(has.joker_created); eq(logic.personality_variants('joker_created'), 3)
end
return T
