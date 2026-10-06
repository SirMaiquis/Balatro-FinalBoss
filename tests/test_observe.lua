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
  local ctx = {fired = {}, opts = {}, now = 0, flexed = 0}
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
      pending = nil,
      fire = function(m, opts) ctx.fired[#ctx.fired + 1] = m; ctx.opts[#ctx.opts + 1] = opts or {}; return true end},
    cinematic = {active = function() return false end},
    dialogue = {intro_active = function() return false end},
    moves = {flex = function() ctx.flexed = ctx.flexed + 1 end},
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

T['on_blind_set: picks the jab and moves the reroll mark'] = function()
  local ctx = setup{rerolled = 8, st = {reroll_mark = 2}, jokers = {'j_joker'}}
  local enc = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc)
  eq(enc.jab.moment, 'jab_rerolls'); eq(G.GAME.FinalBoss.reroll_mark, 8); eq(enc.idle_said, 0)
  local enc2 = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc2)
  eq(enc2.jab, nil, 'no rerolls since the mark')
end

T['on_blind_set: a first boss counts rerolls from the start of the run'] = function()
  local ctx = setup{rerolled = 5, jokers = {'j_joker'}}
  local enc = {key = 'bl_hook'}
  ctx.O.on_blind_set(enc)
  eq(enc.jab.moment, 'jab_rerolls')
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
  eq(ctx.O.disabled_jab(enc, G.GAME.blind), nil, 'only once')
  eq(ctx.O.disabled_jab({key = 'bl_hook', jab = {moment = 'jab_counter', joker = 'j_luchador'}}, G.GAME.blind), nil)
  eq(ctx.O.disabled_jab({key = 'bl_hook'}, G.GAME.blind), nil)
end

return T
