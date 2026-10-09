-- tricks.lua under stubs (no game): which consumables and new jokers get a boss line, and when not.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local S = {SELECTING_HAND = 1, HAND_PLAYED = 2, PLAY_TAROT = 3, SHOP = 5}

--- o: enc (overrides), dialogue, state, interrupt (G.TAROT_INTERRUPT), intro, overlay, paused.
local function setup(o)
  o = o or {}
  local ctx = {fired = {}, opts = {}, now = 100}
  local enc = {key = 'bl_ox', boss = true, ended = false, tier = 'light', fired = {}, last_line_hand = 1,
    comments = 0}
  for k, v in pairs(o.enc or {}) do enc[k] = v end
  ctx.enc = enc
  _G.G = {
    GAME = {FinalBoss = {encounter = enc}, blind = {config = {blind = {key = 'bl_ox'}}, loc_name = 'The Ox'},
      hands = o.hands},
    STATES = S, STATE = o.state or S.PLAY_TAROT,
    TAROT_INTERRUPT = o.interrupt == nil and S.SELECTING_HAND or o.interrupt or nil,
    SETTINGS = {paused = o.paused or false},
    OVERLAY_MENU = o.overlay,
  }
  -- The use's events: run at once, or held in ctx.queue while ctx.hold (run them with flush).
  ctx.queue = {}
  _G.Event = function(t) return t end
  _G.G.E_MANAGER = {add_event = function(_, ev)
    if ctx.hold then ctx.queue[#ctx.queue + 1] = ev else ev.func() end
  end}
  _G.G.jokers = {cards = o.jokers or {}}
  package.loaded['src.logic'] = nil
  _G.FinalBoss = {
    logic = require('src.logic'),
    config = {dialogue = o.dialogue ~= false},
    util = {now = function() return ctx.now end, guard = function(_, fn, ...) return pcall(fn, ...) end},
    director = {fire = function(m, opts)
      ctx.fired[#ctx.fired + 1] = m; ctx.opts[#ctx.opts + 1] = opts
      return true, not ctx.drop -- ctx.drop: dialogue drops the line (its REACTION_GAP)
    end, vars = function(blind) return {blind.loc_name} end},
    cinematic = {active = function() return false end},
    dialogue = {intro_active = function() return o.intro or false end},
  }
  -- vanilla localize (functions/misc_functions.lua): name_text of a center, or a misc category entry
  _G.localize = function(args, cat)
    if type(args) == 'table' then return 'name:' .. args.set .. ':' .. args.key end
    return cat == 'poker_hands' and ('hand:' .. args) or 'ERROR'
  end
  package.loaded['src.tricks'] = nil
  ctx.R = require('src.tricks')
  return ctx
end

local function card(set) return {ability = {set = set}} end
local function keyed(set, key) return {ability = {set = set}, config = {center = {key = key}}} end

T['a created joker: once per blind'] = function()
  local ctx = setup()
  ctx.R.on_joker_added(card('Joker'), false, false)
  ctx.now = 200; ctx.R.on_joker_added(card('Joker'), false, false)
  eq(#ctx.fired, 1)
end

T['a tarot used in the fight: a free line'] = function()
  local ctx = setup()
  ctx.R.on_consumable(card('Tarot'))
  eq(#ctx.fired, 1); eq(ctx.fired[1], 'used_tarot'); eq(ctx.opts[1].free, true)
  eq(ctx.enc.tricks.last, 100, 'plain data on the encounter')
end

T['a second tarot: collapsed inside the gap, a line after it'] = function()
  local ctx = setup()
  ctx.R.on_consumable(card('Tarot'))
  ctx.now = 102; ctx.R.on_consumable(card('Tarot'))
  eq(#ctx.fired, 1, 'spam collapsed')
  ctx.now = 200; ctx.R.on_consumable(card('Tarot'))
  eq(#ctx.fired, 2, 'after the gap')
end

T['a vanilla tarot or spectral: its group line, naming the card'] = function()
  local ctx = setup()
  ctx.R.on_consumable(keyed('Tarot', 'c_heirophant'))
  eq(ctx.fired[1], 'used_tarot_enhance'); eq(ctx.opts[1].free, true)
  eq(ctx.opts[1].vars[1], 'The Ox'); eq(ctx.opts[1].vars[2], 'name:Tarot:c_heirophant')
  ctx.now = 110; ctx.R.on_consumable(keyed('Spectral', 'c_black_hole'))
  eq(ctx.fired[2], 'used_spectral_blackhole'); eq(ctx.opts[2].vars[2], 'name:Spectral:c_black_hole')
  ctx.now = 120; ctx.R.on_consumable(keyed('Tarot', 'c_mymod_card'))
  eq(ctx.fired[3], 'used_tarot', 'a modded tarot: the fallback')
end

T['a card whose name fails to localize: its key'] = function()
  local ctx = setup()
  _G.localize = function() return 'ERROR' end
  ctx.R.on_consumable(keyed('Tarot', 'c_death'))
  eq(ctx.fired[1], 'used_tarot_copy'); eq(ctx.opts[1].vars[2], 'c_death')
end

local function planet(hand)
  local c = keyed('Planet', 'c_planet_' .. tostring(hand)); c.ability.consumeable = {hand_type = hand}; return c
end

T['a planet for your most played hand: main, with the new level'] = function()
  local ctx = setup{hands = {Pair = {played = 9, level = 4}, Flush = {played = 9, level = 1},
    ['High Card'] = {played = 2, level = 1}}}
  ctx.R.on_consumable(planet('Pair'))
  eq(ctx.fired[1], 'used_planet_main', 'ties count')
  eq(ctx.opts[1].vars[2], 'hand:Pair'); eq(ctx.opts[1].vars[3], 4, 'the level vanilla already raised')
end

T['a planet for a hand you never play: waste'] = function()
  local ctx = setup{hands = {Pair = {played = 30, level = 1}, Flush = {played = 2, level = 3}}}
  ctx.R.on_consumable(planet('Flush'))
  eq(ctx.fired[1], 'used_planet_waste'); eq(ctx.opts[1].vars[2], 'hand:Flush')
  ctx.now = 110; G.GAME.hands.Flush.played = 5
  FinalBoss.logic.trick_new_turn(ctx.enc.tricks) -- the same planet: a hand was played in between
  ctx.R.on_consumable(planet('Flush'))
  eq(ctx.fired[2], 'used_planet', 'in between: the fallback')
end

T['a planet with no known hand: the plain fallback'] = function()
  local ctx = setup{hands = {Pair = {played = 3, level = 1}}}
  ctx.R.on_consumable(planet('Mystery Hand'))
  ctx.now = 110; ctx.R.on_consumable(planet(nil))
  eq(ctx.fired[1], 'used_planet'); eq(ctx.fired[2], 'used_planet'); eq(ctx.opts[1].vars, nil)
end

T['spectral and planet get their own lines'] = function()
  local ctx = setup()
  ctx.R.on_consumable(card('Spectral'))
  ctx.now = 110; ctx.R.on_consumable(card('Planet'))
  eq(ctx.fired[1], 'used_spectral'); eq(ctx.fired[2], 'used_planet')
end

T['tricks never touch the fight bookkeeping'] = function()
  local ctx = setup()
  ctx.R.on_consumable(card('Tarot'))
  eq(next(ctx.enc.fired), nil); eq(ctx.enc.last_line_hand, 1); eq(ctx.enc.comments, 0)
end

T['no trick line outside the live fight'] = function()
  local cases = {{intro = true}, {enc = {ended = true}}, {enc = {win_hand = 3}}, {enc = {finale = true}},
    {enc = {boss = false}}, {enc = {tier = 'none'}}, {state = S.SHOP, interrupt = false},
    {state = S.PLAY_TAROT, interrupt = S.SHOP}, {paused = true}, {overlay = {}}}
  for i, o in ipairs(cases) do
    local ctx = setup(o)
    ctx.R.on_consumable(card('Tarot'))
    ctx.R.on_joker_added(card('Joker'), false, false)
    eq(#ctx.fired, 0, 'case ' .. i)
  end
  local ctx = setup()
  G.GAME.blind.config.blind.key = 'bl_wall'
  ctx.R.on_consumable(card('Tarot'))
  eq(#ctx.fired, 0, 'another blind')
end

T['a joker made while a hand is picked or scored'] = function()
  for _, st in ipairs({S.SELECTING_HAND, S.HAND_PLAYED, S.PLAY_TAROT}) do
    local ctx = setup{state = st}
    ctx.R.on_joker_added(card('Joker'), false, false)
    eq(ctx.fired[1], 'joker_created', 'state ' .. st); eq(ctx.opts[1].free, true)
  end
end

T['playing cards and vouchers are not jokers; other consumable sets say nothing'] = function()
  local ctx = setup()
  ctx.R.on_joker_added(card('Default'), false, false)
  ctx.R.on_joker_added(card('Enhanced'), false, false)
  ctx.R.on_joker_added(card('Voucher'), false, false)
  ctx.R.on_consumable(card('Voucher'))
  ctx.R.on_consumable(card('Booster'))
  ctx.R.on_consumable(nil)
  eq(#ctx.fired, 0)
end

T['a joker back from a debuff, already in the deck, or restored from a save: nothing'] = function()
  local ctx = setup()
  ctx.R.on_joker_added(card('Joker'), true, false)
  ctx.R.on_joker_added(card('Joker'), false, true)
  ctx.R.restoring = true
  ctx.R.on_joker_added(card('Joker'), false, false)
  eq(#ctx.fired, 0)
  eq(ctx.enc.tricks, nil, 'not booked either')
  ctx.R.restoring = false
  ctx.R.on_joker_added(card('Joker'), false, false)
  eq(ctx.fired[1], 'joker_created')
end

T['a joker already in the joker slots that transforms: nothing'] = function()
  local ctx = setup()
  ctx.R.on_joker_added(card('Joker'), nil, false, true)
  eq(#ctx.fired, 0)
  eq(ctx.enc.tricks, nil, 'not booked either')
end

T['a line the dialogue dropped is not used up'] = function()
  local ctx = setup()
  ctx.drop = true
  ctx.R.on_consumable(card('Tarot'))
  eq(#ctx.fired, 1, 'tried')
  eq(ctx.enc.tricks.last, nil, 'gap unbooked')
  ctx.drop = false
  ctx.now = 101; ctx.R.on_consumable(card('Tarot'))
  eq(#ctx.fired, 2); eq(ctx.fired[2], 'used_tarot')
  eq(ctx.enc.tricks.last, 101)
end

T['a dropped line puts back the previous gap mark'] = function()
  local ctx = setup()
  ctx.R.on_consumable(card('Planet'))
  ctx.drop = true
  ctx.now = 110; ctx.R.on_consumable(card('Tarot'))
  eq(ctx.enc.tricks.last, 100)
end

T['a spectral that makes a joker: one line'] = function()
  local ctx = setup()
  ctx.R.on_consumable(card('Spectral'))
  ctx.now = 101; ctx.R.on_joker_added(card('Joker'), false, false)
  eq(#ctx.fired, 1); eq(ctx.fired[1], 'used_spectral')
end

T['dialogue off: no line, the trick is still booked'] = function()
  local ctx = setup{dialogue = false}
  ctx.R.on_consumable(card('Tarot'))
  eq(#ctx.fired, 0)
  eq(ctx.enc.tricks.last, 100)
end

-- 1.3 revisions: once per card per turn, joker-making cards, the Wheel of Fortune -----------------

local function flush(ctx)
  local q = ctx.queue
  ctx.queue = {}
  for _, ev in ipairs(q) do eq(ev.func(), true, 'the event completes') end
end

local function joker(key, edition) return {ability = {set = 'Joker'}, config = {center = {key = key}}, edition = edition} end

T['the same card twice in one turn: one line; again after a hand is played'] = function()
  local ctx = setup()
  ctx.R.on_consumable(keyed('Tarot', 'c_star'))
  ctx.now = 200; ctx.R.on_consumable(keyed('Tarot', 'c_star'))
  eq(#ctx.fired, 1, 'same key, same turn, gap passed')
  ctx.now = 300; ctx.R.on_consumable(keyed('Tarot', 'c_moon'))
  eq(#ctx.fired, 2, 'another card')
  FinalBoss.logic.trick_new_turn(ctx.enc.tricks)
  ctx.now = 400; ctx.R.on_consumable(keyed('Tarot', 'c_star'))
  eq(#ctx.fired, 3, 'a hand was played')
end

T['a dropped card line leaves the card free this turn'] = function()
  local ctx = setup()
  ctx.drop = true
  ctx.R.on_consumable(keyed('Tarot', 'c_star'))
  eq(ctx.enc.tricks.turn_keys.c_star, nil)
  ctx.drop = false
  ctx.now = 101; ctx.R.on_consumable(keyed('Tarot', 'c_star'))
  eq(#ctx.fired, 2)
end

T['the line waits for the use events; a joker they make takes it, named'] = function()
  local ctx = setup()
  ctx.hold = true
  ctx.R.on_consumable(keyed('Tarot', 'c_judgement'))
  eq(#ctx.fired, 0, 'not before the effects')
  ctx.R.on_joker_added(joker('j_joker'), false, false, false)
  eq(#ctx.fired, 0, 'the joker waits for its card')
  flush(ctx)
  eq(#ctx.fired, 1); eq(ctx.fired[1], 'joker_created'); eq(ctx.opts[1].free, true)
  eq(ctx.opts[1].vars[1], 'The Ox'); eq(ctx.opts[1].vars[2], 'name:Joker:j_joker')
  eq(ctx.enc.tricks.seen.Joker, true); eq(ctx.enc.tricks.turn_keys.c_judgement, true)
  eq(ctx.R.pending, nil)
end

T['a joker card after joker_created was said: the card line'] = function()
  local ctx = setup()
  ctx.R.on_joker_added(joker('j_joker'), false, false, false)
  eq(ctx.fired[1], 'joker_created')
  ctx.hold = true
  ctx.now = 200; ctx.R.on_consumable(keyed('Spectral', 'c_soul'))
  ctx.R.on_joker_added(joker('j_caino'), false, false, false)
  flush(ctx)
  eq(#ctx.fired, 2); eq(ctx.fired[2], 'used_spectral_joker'); eq(ctx.opts[2].vars[2], 'name:Spectral:c_soul')
end

T['a joker card that makes no joker: the card line once its events ran'] = function()
  local ctx = setup()
  ctx.hold = true
  ctx.R.on_consumable(keyed('Spectral', 'c_wraith'))
  flush(ctx)
  eq(ctx.fired[1], 'used_spectral_joker')
end

T['a joker line the dialogue dropped frees the joker and the card'] = function()
  local ctx = setup()
  ctx.hold = true; ctx.drop = true
  ctx.R.on_consumable(keyed('Spectral', 'c_ankh'))
  ctx.R.on_joker_added(joker('j_joker'), false, false, false)
  flush(ctx)
  eq(ctx.fired[1], 'joker_created')
  eq(ctx.enc.tricks.seen.Joker, nil); eq(ctx.enc.tricks.turn_keys.c_ankh, nil); eq(ctx.enc.tricks.last, nil)
end

T['a joker made mid-hand names itself'] = function()
  local ctx = setup{state = S.HAND_PLAYED}
  ctx.R.on_joker_added(joker('j_cavendish'), false, false, false)
  eq(ctx.fired[1], 'joker_created'); eq(ctx.opts[1].vars[2], 'name:Joker:j_cavendish')
end

T['a stale pending card does not swallow a later joker'] = function()
  local ctx = setup()
  ctx.hold = true
  ctx.R.on_consumable(keyed('Tarot', 'c_fool'))
  ctx.queue = {} -- the queue was cleared: the resolve never runs
  ctx.now = 100 + ctx.R.PENDING_MAX + 1
  ctx.R.on_joker_added(joker('j_joker'), false, false, false)
  eq(ctx.fired[1], 'joker_created'); eq(ctx.R.pending, nil)
end

T['no pending card and no event outside the fight'] = function()
  local ctx = setup{intro = true}
  ctx.hold = true
  ctx.R.on_consumable(keyed('Tarot', 'c_judgement'))
  eq(#ctx.queue, 0); eq(ctx.R.pending, nil)
end

local function wheel() local c = keyed('Tarot', 'c_wheel_of_fortune'); c.ability.extra = 4; return c end

T['wheel of fortune: an edition landing is a hit'] = function()
  local a, b = joker('j_a'), joker('j_b', {foil = true})
  local ctx = setup{jokers = {a, b}}
  ctx.hold = true; G.GAME.probabilities = {normal = 1}
  local w = wheel()
  local before = ctx.R.snapshot(w)
  eq(before[a], true); eq(before[b], nil, 'already has an edition')
  ctx.R.on_consumable(w, before)
  a.edition = {holo = true} -- vanilla's queued set_edition
  flush(ctx)
  eq(ctx.fired[1], 'used_tarot_wheel_hit'); eq(ctx.opts[1].vars[2], 'name:Tarot:c_wheel_of_fortune')
end

T['wheel of fortune: no edition is a miss; rigged odds win on either'] = function()
  local ctx = setup{jokers = {joker('j_a')}}
  G.GAME.probabilities = {normal = 1}
  local w = wheel()
  ctx.R.on_consumable(w, ctx.R.snapshot(w))
  eq(ctx.fired[1], 'used_tarot_wheel_miss')
  local j = joker('j_a')
  ctx = setup{jokers = {j}}
  ctx.hold = true; G.GAME.probabilities = {normal = 2} -- Oops! All 6s
  w = wheel()
  ctx.R.on_consumable(w, ctx.R.snapshot(w))
  j.edition = {polychrome = true}
  flush(ctx)
  eq(ctx.fired[1], 'used_tarot_wheel_rigged')
end

T['snapshot: only the Wheel of Fortune; without one the wheel keeps its gamble line'] = function()
  local ctx = setup{jokers = {joker('j_a')}}
  eq(ctx.R.snapshot(keyed('Tarot', 'c_judgement')), nil)
  eq(ctx.R.snapshot(keyed('Spectral', 'c_wheel_of_fortune')), nil)
  eq(ctx.R.snapshot(nil), nil)
  ctx.R.on_consumable(wheel(), nil)
  eq(ctx.fired[1], 'used_tarot_gamble')
end

return T
