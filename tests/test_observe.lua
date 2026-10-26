-- observe.lua under stubs (no game): the run at blind set, the jab's vars and options, Chicot.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local SUITS = {'Hearts', 'Spades', 'Clubs', 'Diamonds'}

--- o: jokers (center keys), slots, deck (size), suit (every card this suit when set), dollars,
--- states (blind_states), rerolled (run counter), st (G.GAME.FinalBoss), enc, blind_key.
local function setup(o)
  o = o or {}
  local ctx = {fired = {}, opts = {}, now = 0}
  local cards = {}
  for i, k in ipairs(o.jokers or {}) do cards[i] = {config = {center = {key = k}}} end
  local deck = {}
  for i = 1, o.deck or 52 do deck[i] = {base = {suit = o.suit or SUITS[i % 4 + 1]}} end
  local st = o.st or {}
  if o.enc then st.encounter = o.enc end
  _G.G = {
    GAME = {FinalBoss = st, dollars = o.dollars or 10,
      round_resets = {blind_states = o.states or {Small = 'Defeated', Big = 'Defeated', Boss = 'Current'}},
      round_scores = {times_rerolled = {amt = o.rerolled or 0}},
      blind = {config = {blind = {key = o.blind_key or (o.enc and o.enc.key) or 'bl_hook'}}}},
    jokers = {cards = cards, config = {card_limit = 5, card_count = #cards,
      card_limits = {total_slots = o.slots or 5}}},
    playing_cards = deck,
    STATES = {SELECTING_HAND = 1, HAND_PLAYED = 2}, STATE = 1,
    SETTINGS = {paused = false}, hand = {highlighted = {}},
  }
  _G.localize = function(args) return 'Name of ' .. args.key end
  package.loaded['src.logic'] = nil
  _G.FinalBoss = {
    logic = require('src.logic'),
    config = {dialogue = true},
    util = {now = function() return ctx.now end, log = function() end,
      state = function() G.GAME.FinalBoss = G.GAME.FinalBoss or {}; return G.GAME.FinalBoss end},
    director = {num = function(x) return tonumber(x) or 0 end, vars = function() return {'The Boss'} end,
      read = function(x) return FinalBoss.logic.read_number(x) end,
      pending = nil,
      fire = function(m, opts) ctx.fired[#ctx.fired + 1] = m; ctx.opts[#ctx.opts + 1] = opts or {}; return true end},
    cinematic = {active = function() return false end},
    dialogue = {intro_active = function() return false end},
  }
  package.loaded['src.observe'] = nil
  ctx.O = require('src.observe')
  return ctx
end

T['run_state: jokers, row, skips, rerolls since the mark, money, deck'] = function()
  local ctx = setup{jokers = {'j_blueprint', 'j_joker'}, slots = 6, dollars = 7, rerolled = 9,
    states = {Small = 'Skipped', Big = 'Defeated', Boss = 'Current'}, st = {reroll_mark = 4}, deck = 40,
    suit = 'Spades'}
  local s, rerolled = ctx.O.run_state('bl_hook')
  eq(#s.jokers, 2); eq(s.jokers[1], 'j_blueprint'); eq(s.joker_count, 2); eq(s.joker_slots, 6)
  eq(s.skipped, 1); eq(s.rerolls, 5); eq(rerolled, 9); eq(s.dollars, 7)
  eq(s.deck_size, 40); eq(s.suit_max, 40); eq(s.signature, 'j_luchador')
end

T['run_state: a joker that cannot act is not listed, but still fills the row'] = function()
  local ctx = setup{jokers = {'j_chicot', 'j_blueprint', 'j_joker'}}
  G.jokers.cards[1].debuff = true
  G.jokers.cards[2].getting_sliced = true
  local s = ctx.O.run_state('bl_hook')
  eq(#s.jokers, 1); eq(s.jokers[1], 'j_joker'); eq(s.joker_count, 3)
end

T['on_blind_set: a Chicot that cannot act never gets the counter jab'] = function()
  for _, field in ipairs({'debuff', 'getting_sliced'}) do
    local ctx = setup{jokers = {'j_chicot'}}
    G.jokers.cards[1][field] = true
    local enc = {key = 'bl_mymod_boss'}
    ctx.O.on_blind_set(enc, function(n) if n == nil then return 0 end return 1 end) -- every roll passes
    assert(not (enc.jab and enc.jab.joker == 'j_chicot'), field .. ': no jab at Chicot')
  end
end

--- math.random with the jab's chance roll passing and the first candidate picked.
local function lucky(n) if n == nil then return 0 end return 1 end
--- math.random with the jab's chance roll failing.
local function unlucky(n) if n == nil then return 0.99 end return 1 end

T['on_blind_set: picks the jab and moves the reroll mark'] = function()
  local ctx = setup{rerolled = 8, st = {reroll_mark = 2}, jokers = {'j_joker'}}
  local enc = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc, lucky)
  eq(enc.jab.moment, 'jab_rerolls'); eq(G.GAME.FinalBoss.reroll_mark, 8); eq(enc.idle_said, 0)
  local enc2 = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc2, lucky)
  eq(enc2.jab, nil, 'no rerolls since the mark')
end

T['on_blind_set: a first boss counts rerolls from the start of the run'] = function()
  local ctx = setup{rerolled = 5, jokers = {'j_joker'}}
  local enc = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc, lucky)
  eq(enc.jab.moment, 'jab_rerolls')
end

T['on_blind_set: a failed chance roll keeps the threat; a counter jabs anyway'] = function()
  local ctx = setup{rerolled = 5, jokers = {'j_joker'}}
  local enc = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc, unlucky)
  eq(enc.jab, nil)
  local ctx2 = setup{jokers = {'j_luchador'}}
  local enc2 = {key = 'bl_hook'}
  ctx2.O.on_blind_set(enc2, unlucky)
  eq(enc2.jab.moment, 'jab_counter')
end

T['on_blind_set: the last jab said this run is skipped'] = function()
  local ctx = setup{rerolled = 5, dollars = 0, jokers = {'j_joker'}, st = {last_jab = 'jab_rerolls'}}
  eq(ctx.O.run_state('bl_hook').last_jab, 'jab_rerolls')
  local enc = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc, lucky)
  eq(enc.jab.moment, 'jab_broke')
end

T['on_blind_set: the jab reads the arrival snapshot, not a run a boss emptied'] = function()
  local ctx = setup{dollars = 0, jokers = {'j_joker'}}
  local snap = ctx.O.run_state('bl_hook')
  snap.dollars = 2000
  ctx.O.arrival = {key = 'bl_hook', state = snap, rerolled = 0}
  local enc = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc, lucky)
  assert(not (enc.jab and enc.jab.moment == 'jab_broke'), 'no broke jab')
  eq(enc.jab.moment, 'jab_loaded')
end

T['on_blind_set: with no snapshot the jab reads the live run'] = function()
  local ctx = setup{dollars = 0, jokers = {'j_joker'}}
  local enc = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc, lucky)
  eq(enc.jab.moment, 'jab_broke')
end

T['on_blind_set: a snapshot for another blind is ignored'] = function()
  local ctx = setup{dollars = 0, jokers = {'j_joker'}}
  local snap = ctx.O.run_state('bl_hook')
  snap.dollars = 2000
  ctx.O.arrival = {key = 'bl_other', state = snap, rerolled = 0}
  local enc = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc, lucky)
  eq(enc.jab.moment, 'jab_broke')
end

T['on_blind_set: the arrival snapshot is cleared after use'] = function()
  local ctx = setup{jokers = {'j_joker'}}
  ctx.O.arrival = {key = 'bl_hook', state = ctx.O.run_state('bl_hook'), rerolled = 0}
  ctx.O.on_blind_set({key = 'bl_hook'}, lucky)
  eq(ctx.O.arrival, nil)
  ctx.O.arrival = {key = 'bl_other', state = ctx.O.run_state('bl_hook'), rerolled = 0}
  ctx.O.on_blind_set({key = 'bl_hook'}, lucky)
  eq(ctx.O.arrival, nil, 'cleared on a mismatch too')
end

T['mark_said: the jab is said once and becomes the last jab'] = function()
  local ctx = setup()
  local enc = {key = 'bl_hook', jab = {moment = 'jab_broke'}}
  ctx.O.mark_said(enc)
  eq(enc.jab_said, true); eq(G.GAME.FinalBoss.last_jab, 'jab_broke')
end

T['jab_opts: the boss line only for its signature counter'] = function()
  local ctx = setup()
  eq(ctx.O.jab_opts({key = 'bl_hook', jab = {moment = 'jab_counter', joker = 'j_matador'}}).skip_boss, true)
  eq(ctx.O.jab_opts({key = 'bl_hook', jab = {moment = 'jab_counter', joker = 'j_luchador'}}).skip_boss, false)
  eq(ctx.O.jab_opts({key = 'bl_final_bell', jab = {moment = 'jab_counter', joker = 'j_chicot'}}).skip_boss, false)
  eq(ctx.O.jab_opts({key = 'bl_hook', jab = {moment = 'jab_broke'}}), nil)
end

T['jab_vars: the boss name, then the joker name'] = function()
  local ctx = setup()
  local v = ctx.O.jab_vars({key = 'bl_hook', jab = {moment = 'jab_famous', joker = 'j_dna'}}, G.GAME.blind)
  eq(v[1], 'The Boss'); eq(v[2], 'Name of j_dna')
  eq(ctx.O.jab_vars({key = 'bl_hook', jab = {moment = 'jab_broke'}}, G.GAME.blind)[2], nil)
end

T['jab_vars: a combo names both jokers'] = function()
  local ctx = setup()
  local v = ctx.O.jab_vars({key = 'bl_hook', jab = {moment = 'jab_combo', combo = {'j_blueprint', 'j_brainstorm'}}},
    G.GAME.blind)
  eq(v[2], 'Name of j_blueprint & Name of j_brainstorm')
end

T['joker_name: falls back to the key when localize fails'] = function()
  local ctx = setup()
  _G.localize = function() return 'ERROR' end
  eq(ctx.O.joker_name('j_dna'), 'j_dna')
  _G.localize = function() error('boom') end
  eq(ctx.O.joker_name('j_dna'), 'j_dna')
end

T['disabled_jab: a Chicot counter jab, once'] = function()
  local ctx = setup()
  local enc = {key = 'bl_final_bell', jab = {moment = 'jab_counter', joker = 'j_chicot'}}
  local opts = ctx.O.disabled_jab(enc, G.GAME.blind)
  eq(opts.line, 'jab_counter'); eq(opts.skip_boss, false); eq(opts.vars[2], 'Name of j_chicot')
  eq(G.GAME.FinalBoss.last_jab, 'jab_counter')
  eq(ctx.O.disabled_jab(enc, G.GAME.blind), nil, 'only once')
  eq(ctx.O.disabled_jab({key = 'bl_hook', jab = {moment = 'jab_counter', joker = 'j_luchador'}}, G.GAME.blind), nil)
  eq(ctx.O.disabled_jab({key = 'bl_hook'}, G.GAME.blind), nil)
end

T['on_blind_set: a Chicot that will act is always the jab'] = function()
  local ctx = setup{jokers = {'j_luchador', 'j_chicot'}}
  local enc = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc)
  eq(enc.jab.moment, 'jab_counter'); eq(enc.jab.joker, 'j_chicot', 'not the signature Luchador')
  local ctx2 = setup{jokers = {'j_luchador', 'j_chicot'}}
  G.jokers.cards[2].getting_sliced = true
  local enc2 = {key = 'bl_hook'}
  ctx2.O.on_blind_set(enc2)
  eq(enc2.jab.joker, 'j_luchador', 'a sliced Chicot never acts')
  local ctx3 = setup{jokers = {'j_luchador', 'j_chicot'}}
  G.jokers.cards[2].debuff = true
  local enc3 = {key = 'bl_hook'}
  ctx3.O.on_blind_set(enc3)
  eq(enc3.jab.joker, 'j_luchador', 'a debuffed Chicot never acts')
end

-- In-fight comments and the fear scale --------------------------------------------------------------

local function pending(o)
  local p = {total = 5, required = 100, delta = 5, hand_type = 'Flush', streak = 1, discards_left = 1,
    discards_used = 0, hands_left = 3, cards_played = 5, hand = 1, moment = nil}
  for k, v in pairs(o or {}) do p[k] = v end
  return p
end

T['comment_for: weak first, then a read; never on the winning hand'] = function()
  local ctx = setup()
  local enc = {tier = 'light', fired = {}}
  eq(ctx.O.comment_for(enc, pending()), 'weak')
  eq(ctx.O.comment_for(enc, pending{delta = 20, total = 20}), nil, 'a normal Flush says nothing')
  eq(ctx.O.comment_for(enc, pending{delta = 20, total = 20, hand_type = 'Pair'}), 'read_weakhand')
  eq(ctx.O.comment_for(enc, pending{delta = 120, total = 120}), nil, 'the winning hand')
  eq(ctx.O.comment_for({tier = 'light', fired = {}, last_line_hand = 1}, pending{hand = 2}), nil,
    'the boss spoke on the hand before')
  eq(ctx.O.comment_for({tier = 'light', fired = {}, last_line_hand = 1}, pending{hand = 3}), 'weak')
  eq(ctx.O.comment_for({tier = 'light', fired = {}, comments = 1},
    pending{delta = 20, total = 20, hand_type = 'Pair'}), nil, 'one read per blind on the light tier')
end

T['comment_for: full tier reads are capped and never on consecutive hands'] = function()
  local ctx = setup()
  local enc = {tier = 'full', fired = {}, comments = 1, last_comment_hand = 2}
  local pair = {delta = 20, total = 20, hand_type = 'Pair'}
  pair.hand = 3
  eq(ctx.O.comment_for(enc, pending(pair)), nil, 'the hand after a comment')
  pair.hand = 4
  eq(ctx.O.comment_for(enc, pending(pair)), 'read_weakhand')
  enc.comments = 3
  eq(ctx.O.comment_for(enc, pending(pair)), nil, 'cap reached')
  eq(ctx.O.comment_for(enc, pending{hand = 3}), 'weak', 'weak is outside the cap and the rule')
end

T['comment_for: no weak line or read on a won or unknown hand (1.3.1)'] = function()
  local ctx = setup()
  local enc = {tier = 'full', fired = {}}
  -- a big-number win whose numbers read as 0: the outcome says won
  eq(ctx.O.comment_for(enc, pending{delta = 0, total = 0, won = true}), nil, 'won')
  local function unread(o) local p = pending(o); p.delta, p.total = nil, nil; return p end
  eq(ctx.O.comment_for(enc, unread{unknown = true}), nil, 'unknown')
  eq(ctx.O.comment_for(enc, unread{hand_type = 'Pair', unknown = true}), nil, 'no read either')
  eq(ctx.O.comment_for(enc, unread()), nil, 'missing numbers')
  eq(ctx.O.comment_for(enc, pending{unknown = true}), nil, 'unknown even with numbers left over')
  eq(ctx.O.comment_for(enc, pending{won = false, unknown = false}), 'weak', 'a known weak hand still is')
end

T['fear_line: a won hand with unreadable numbers says the plain defeat line'] = function()
  local ctx = setup()
  eq(ctx.O.fear_line({moment = 'defeat', won = true, total = nil, required = nil, hand = 1}, {}), nil)
  eq(ctx.O.fear_line({moment = 'defeat', won = true, total = 2500, required = 1000, hand = 1}, {}), 'fear_1')
  eq(ctx.O.fear_line({moment = 'defeat', won = false, total = 2500, required = 1000, hand = 1}, {}), nil)
end

T['fear_line: only the winning defeat hand, by tier, always'] = function()
  local ctx = setup()
  eq(ctx.O.fear_line({moment = 'defeat', total = 250, required = 100}), 'fear_1')
  eq(ctx.O.fear_line({moment = 'defeat', total = 1500, required = 100}), 'fear_2')
  eq(ctx.O.fear_line({moment = 'defeat', total = 1e6, required = 100}), 'fear_3')
  eq(ctx.O.fear_line({moment = 'defeat', total = 150, required = 100}), nil)
  eq(ctx.O.fear_line({moment = 'close', total = 5000, required = 100}), nil)
  eq(ctx.O.fear_line({moment = 'defeat', total = 0, required = 0}), nil, 'no requirement')
end

T['fear_line: a fear line said live on this hand skips the defeat line; else a fallback, once'] = function()
  local ctx = setup()
  local win = {moment = 'defeat', total = 1500, required = 100, hand = 3}
  eq(ctx.O.fear_line(win, {fear_said = 2, fear_hand = 3}), false, 'said live on this hand')
  eq(ctx.O.fear_line(win, {fear_said = 2, fear_hand = 2}), nil,
    'said on the hand before: this hand keeps its defeat line')
  eq(ctx.O.fear_line(win, {fear_said = 1, fear_hand = 4}), 'fear_2', 'another hand id never skips')
  local enc = {}
  eq(ctx.O.fear_line(win, enc), 'fear_2', 'never said live: the fallback')
  eq(enc.fear_said, 2); eq(enc.fear_hand, 3, 'booked like a live crossing')
  eq(ctx.O.fear_line(win, {fear_said = 2, fear_hand = 1}), nil, 'this tier was said on an earlier hand')
  eq(ctx.O.fear_line(win, {fear_said = 1, fear_hand = 1}), 'fear_2', 'a higher tier than an earlier hand')
  eq(ctx.O.fear_line({moment = 'defeat', total = 150, required = 100, hand = 3}, {}), nil, 'below 2x')
end

-- The live fear scale -------------------------------------------------------------------------------

--- A boss fight with a hand scoring: round score 100 of a 1000 requirement, displayed chips x mult.
local function fear_setup(o)
  o = o or {}
  local enc = {key = 'bl_hook', boss = true, tier = o.tier or 'full', ended = false, fired = {}}
  local ctx = setup{enc = enc}
  ctx.enc = enc
  ctx.fx = {}
  G.STATE = G.STATES.HAND_PLAYED
  G.GAME.chips = 100
  G.GAME.blind.chips = 1000
  -- vanilla's +1 runs before the score display: hands_played is one ahead of the hand being scored
  enc.last_hand_seen = 1
  G.GAME.current_round = {hands_played = 2, current_hand = {chips = 0, mult = 0}}
  FinalBoss.director.fear_fx = function(e, b, t) ctx.fx[#ctx.fx + 1] = t end
  ctx.show = function(chips, mult)
    G.GAME.current_round.current_hand.chips = chips
    G.GAME.current_round.current_hand.mult = mult
    ctx.O.fear_tick()
  end
  return ctx
end

T['fear_tick: the displayed total crosses 2x, 10x, 100x: each line once, forced and free'] = function()
  local ctx = fear_setup()
  ctx.show(30, 4)
  eq(#ctx.fired, 0, 'below 2x')
  ctx.show(100, 19)
  eq(#ctx.fired, 1); eq(ctx.fired[1], 'fear_1', '100 + 1900 = 2x')
  eq(ctx.opts[1].force, true); eq(ctx.opts[1].nobook, true)
  eq(ctx.opts[1].free, nil, 'a real line: it starts the reaction gap')
  eq(ctx.enc.fear_said, 1); eq(ctx.enc.fear_hand, 1, 'the id on_hand_after booked, not hands_played')
  ctx.show(100, 20)
  eq(#ctx.fired, 1, 'the same tier again says nothing')
  ctx.show(100, 99)
  eq(ctx.fired[2], 'fear_2', 'escalation replaces the bubble')
  ctx.show(1000, 100)
  eq(ctx.fired[3], 'fear_3'); eq(ctx.enc.fear_said, 3)
  eq(#ctx.fx, 3); eq(ctx.fx[1], 1); eq(ctx.fx[2], 2); eq(ctx.fx[3], 3)
  ctx.show(0, 0)
  eq(#ctx.fired, 3, 'the hand clears: nothing new')
end

T['fear_tick then the defeat line: the same hand skips it, the next hand does not'] = function()
  local ctx = fear_setup()
  ctx.show(100, 99)
  eq(ctx.fired[1], 'fear_2')
  eq(ctx.O.fear_line({moment = 'defeat', total = 10000, required = 1000, hand = 1}, ctx.enc), false,
    'the hand that crossed live')
  eq(ctx.O.fear_line({moment = 'defeat', total = 10000, required = 1000, hand = 2}, ctx.enc), nil,
    'a later winning hand at the same tier says its defeat line')
end

T['fear_tick: a jump straight past a tier announces only the top one'] = function()
  local ctx = fear_setup()
  ctx.show(500, 200)
  eq(#ctx.fired, 1); eq(ctx.fired[1], 'fear_3')
end

T['fear_tick: only while a hand scores in a live boss fight with no intro'] = function()
  local ctx = fear_setup()
  G.STATE = G.STATES.SELECTING_HAND
  ctx.show(100, 99)
  eq(#ctx.fired, 0, 'not scoring (choosing cards)')
  G.STATE = G.STATES.HAND_PLAYED
  ctx.enc.ended = true
  ctx.show(100, 99)
  eq(#ctx.fired, 0, 'the fight is over')
  ctx.enc.ended = false
  FinalBoss.dialogue.intro_active = function() return true end
  ctx.show(100, 99)
  eq(#ctx.fired, 0, 'the intro is still running')
  FinalBoss.dialogue.intro_active = function() return false end
  G.GAME.blind.config.blind.key = 'bl_other'
  ctx.show(100, 99)
  eq(#ctx.fired, 0, 'another blind')
  G.GAME.blind.config.blind.key = 'bl_hook'
  ctx.enc.tier = 'none'
  ctx.show(100, 99)
  eq(#ctx.fired, 0, 'a silent encounter')
  ctx.enc.tier = 'light'
  ctx.show(100, 99)
  eq(#ctx.fired, 1, 'the light tier is watched too')
end

T['fear_tick: no live tier when the displayed score cannot be read (1.3.1)'] = function()
  local ctx = fear_setup()
  ctx.show('?', '?')
  eq(#ctx.fired, 0, "vanilla's face-down '?'")
  ctx.show(setmetatable({}, {}), 1e9)
  eq(#ctx.fired, 0, 'an unreadable big number')
  G.GAME.chips = {}
  ctx.show(100, 99)
  eq(#ctx.fired, 0, 'an unreadable round score')
  G.GAME.chips = 100
  G.GAME.blind.chips = {}
  ctx.show(100, 99)
  eq(#ctx.fired, 0, 'an unreadable requirement')
end

T['fear_tick: big-number displayed values are read (1.3.1)'] = function()
  local ctx = fear_setup()
  local big = function(s) return setmetatable({}, {__tostring = function() return s end}) end
  G.GAME.chips = big('100')
  G.GAME.blind.chips = big('1000')
  ctx.show(big('100'), big('19'))
  eq(ctx.fired[1], 'fear_1', '100 + 1900 = 2x')
end

--- smods' scoring calculation API: SMODS.calculate_round_score(true) applies the active calculation
--- to the displayed parameters (G.GAME.current_round.current_hand).
local function with_calc(calc)
  G.GAME.current_scoring_calculation = calc
  _G.SMODS = {calculate_round_score = function(flames)
    assert(flames == true, 'the displayed values, not the precomputed ones')
    local h = G.GAME.current_round.current_hand
    return calc:func(h.chips, h.mult, flames)
  end}
end

T['fear_tick: a custom scoring calculation decides the live total (1.3.1)'] = function()
  local ctx = fear_setup()
  -- mult-only: chips are shown but do not count
  with_calc({parameters = {'mult'}, func = function(self, chips, mult) return mult end})
  ctx.show(1000, 50)
  eq(#ctx.fired, 0, 'chips x mult would be 50000 (100x); mult-only is 150 of 1000')
  ctx.show(1000, 1900)
  eq(ctx.fired[1], 'fear_1', '100 + 1900 = 2x')
  _G.SMODS = nil
end

T['fear_tick: a failing or unreadable calculation fires nothing (1.3.1)'] = function()
  local ctx = fear_setup()
  with_calc({func = function() error('mod bug') end})
  ctx.show(1000, 1000)
  eq(#ctx.fired, 0, 'the calculation errors')
  with_calc({func = function() return {} end})
  ctx.show(1000, 1000)
  eq(#ctx.fired, 0, 'the calculation gives an unreadable value')
  with_calc({parameters = {'chips', 'mult', 'xchips'}, func = function(self, c, m) return c * m end})
  ctx.show(1000, 1000)
  eq(#ctx.fired, 0, 'a parameter it uses is not shown')
  _G.SMODS = nil
end

T['fear_tick: a visual failure is logged and the line is still said'] = function()
  local ctx = fear_setup()
  FinalBoss.director.fear_fx = function() error('no chip') end
  ctx.show(100, 99)
  eq(ctx.fired[1], 'fear_2'); eq(ctx.enc.fear_said, 2)
end

-- Idle taunts ------------------------------------------------------------------------------------------

local function idle_setup()
  return setup{enc = {key = 'bl_hook', boss = true, tier = 'light', ended = false, fired = {}}}
end

local function tick_at(ctx, t) ctx.now = t; ctx.O.idle_tick() end

T['idle: 25 s, then 45 s more, at most two per blind'] = function()
  local ctx = idle_setup()
  tick_at(ctx, 0); tick_at(ctx, 24.9)
  eq(#ctx.fired, 0)
  tick_at(ctx, 25)
  eq(#ctx.fired, 1); eq(ctx.fired[1], 'idle')
  tick_at(ctx, 69.9)
  eq(#ctx.fired, 1)
  tick_at(ctx, 70)
  eq(#ctx.fired, 2)
  tick_at(ctx, 500)
  eq(#ctx.fired, 2, 'max two'); eq(G.GAME.FinalBoss.encounter.idle_said, 2)
end

T['idle: input and a highlight change restart the clock'] = function()
  local ctx = idle_setup()
  tick_at(ctx, 0)
  ctx.now = 20; ctx.O.on_input()
  tick_at(ctx, 25)
  eq(#ctx.fired, 0)
  tick_at(ctx, 45)
  eq(#ctx.fired, 1)
  local ctx2 = idle_setup()
  tick_at(ctx2, 0)
  G.hand.highlighted = {{}}
  tick_at(ctx2, 20); tick_at(ctx2, 25)
  eq(#ctx2.fired, 0)
  tick_at(ctx2, 45)
  eq(#ctx2.fired, 1)
end

T['idle: never paused, in a menu, outside SELECTING_HAND, in the intro, or with dialogue off'] = function()
  local blockers = {
    function() G.SETTINGS.paused = true end,
    function() G.OVERLAY_MENU = {} end,
    function() G.STATE = G.STATES.HAND_PLAYED end,
    function() FinalBoss.dialogue.intro_active = function() return true end end,
    function() FinalBoss.cinematic.active = function() return true end end,
    function() FinalBoss.config.dialogue = false end,
    function() FinalBoss.director.pending = {} end,
    function() G.GAME.FinalBoss.encounter.ended = true end,
    function() G.GAME.blind = {config = {blind = {key = 'bl_other'}}} end,
  }
  for i, block in ipairs(blockers) do
    local ctx = idle_setup()
    tick_at(ctx, 0)
    block()
    tick_at(ctx, 30); tick_at(ctx, 100)
    eq(#ctx.fired, 0, 'blocker ' .. i)
  end
end

T['idle: a pause restarts the clock'] = function()
  local ctx = idle_setup()
  tick_at(ctx, 0)
  G.SETTINGS.paused = true
  tick_at(ctx, 20)
  G.SETTINGS.paused = false
  tick_at(ctx, 40)
  eq(#ctx.fired, 0)
  tick_at(ctx, 45)
  eq(#ctx.fired, 1)
end

T['idle: a new blind starts a fresh count and clock'] = function()
  local ctx = idle_setup()
  tick_at(ctx, 0); tick_at(ctx, 25)
  eq(#ctx.fired, 1)
  local enc = G.GAME.FinalBoss.encounter
  ctx.now = 30; ctx.O.on_blind_set(enc)
  eq(enc.idle_said, 0)
  tick_at(ctx, 31); tick_at(ctx, 55.9)
  eq(#ctx.fired, 1)
  tick_at(ctx, 56)
  eq(#ctx.fired, 2)
end

T['dev_jab: fakes a run and says its jab now'] = function()
  local ctx = setup{enc = {key = 'bl_final_bell', boss = true, tier = 'full', ended = false, fired = {}}}
  local roll = math.random
  math.random = unlucky -- the developer key ignores the chance roll
  local ok, m = pcall(ctx.O.dev_jab, {dollars = 0})
  math.random = roll
  assert(ok, m)
  eq(m, 'jab_broke')
  eq(ctx.fired[1], 'intro'); eq(ctx.opts[1].force, true); eq(ctx.opts[1].line, 'jab_broke')
  eq(G.GAME.FinalBoss.last_jab, 'jab_broke')
  G.GAME.FinalBoss.last_jab = nil
  eq(ctx.O.dev_jab({counter = true}), 'jab_counter')
  eq(ctx.opts[2].skip_boss, false); eq(ctx.opts[2].vars[2], 'Name of j_chicot')
  eq(G.GAME.FinalBoss.encounter.jab.joker, 'j_chicot')
  G.GAME.FinalBoss.last_jab = nil
  eq(ctx.O.dev_jab({combo = true}), 'jab_combo')
  eq(G.GAME.FinalBoss.encounter.jab.combo[1], 'j_blueprint')
  G.GAME.FinalBoss.last_jab = nil
  eq(ctx.O.dev_jab({}), nil, 'the neutral run has no jab')
  local none = setup()
  eq(none.O.dev_jab({dollars = 0}), nil, 'no encounter')
end

return T
