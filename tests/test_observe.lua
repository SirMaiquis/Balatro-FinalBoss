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

-- In-fight comments and overkill --------------------------------------------------------------------

local function pending(o)
  local p = {total = 5, required = 100, delta = 5, hand_type = 'Flush', streak = 1, discards_left = 1,
    discards_used = 0, hands_left = 3, cards_played = 5, hand = 1, moment = nil}
  for k, v in pairs(o or {}) do p[k] = v end
  return p
end

T['comment_for: weak first, then a read; never on the winning hand'] = function()
  local ctx = setup()
  local enc = {tier = 'light', fired = {}, reactions = 0}
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
  local enc = {tier = 'full', fired = {}, reactions = 0, comments = 1, last_comment_hand = 2}
  local pair = {delta = 20, total = 20, hand_type = 'Pair'}
  pair.hand = 3
  eq(ctx.O.comment_for(enc, pending(pair)), nil, 'the hand after a comment')
  pair.hand = 4
  eq(ctx.O.comment_for(enc, pending(pair)), 'read_weakhand')
  enc.comments = 3
  eq(ctx.O.comment_for(enc, pending(pair)), nil, 'cap reached')
  eq(ctx.O.comment_for(enc, pending{hand = 3}), 'weak', 'weak is outside the cap and the rule')
end

T['overkill_line: a defeat with twice the requirement, on a passing roll'] = function()
  local ctx = setup()
  local pass = function() return 0 end
  eq(ctx.O.overkill_line({moment = 'defeat', total = 250, required = 100}, pass), 'overkill')
  eq(ctx.O.overkill_line({moment = 'defeat', total = 150, required = 100}, pass), nil)
  eq(ctx.O.overkill_line({moment = 'close', total = 250, required = 100}, pass), nil)
  eq(ctx.O.overkill_line({moment = 'defeat', total = 0, required = 0}, pass), nil, 'no requirement')
end

T['overkill_line: a failed roll keeps the boss its own defeat line'] = function()
  local ctx = setup()
  eq(FinalBoss.logic.OVERKILL_CHANCE, 0.5)
  eq(ctx.O.overkill_line({moment = 'defeat', total = 250, required = 100}, function() return 0.5 end), nil)
  eq(ctx.O.overkill_line({moment = 'defeat', total = 250, required = 100}, function() return 0.49 end), 'overkill')
end

-- Idle taunts ------------------------------------------------------------------------------------------

local function idle_setup()
  return setup{enc = {key = 'bl_hook', boss = true, tier = 'light', ended = false, fired = {}, reactions = 0}}
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
  local ctx = setup{enc = {key = 'bl_final_bell', boss = true, tier = 'full', ended = false, fired = {}, reactions = 0}}
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
  eq(ctx.O.dev_jab({}), nil, 'the neutral run has no jab')
  local none = setup()
  eq(none.O.dev_jab({dollars = 0}), nil, 'no encounter')
end

return T
