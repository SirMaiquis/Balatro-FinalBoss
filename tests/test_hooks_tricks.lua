-- hooks.lua's trick wraps under stubs (no game): Card:add_to_deck passes what it read before the
-- original ran, Game:start_run sets and always clears the restoring flag.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local NAMES = {'G', 'FinalBoss', 'Blind', 'Card', 'Game', 'love', 'SMODS', 'end_round',
  'ease_background_colour_blind', 'Event', 'create_UIBox_blind_select'}

--- Load hooks.lua over stub engine tables; run f(ctx); put the globals back.
local function with_hooks(f)
  local saved = {}
  for _, k in ipairs(NAMES) do saved[k] = _G[k] end
  local ctx = {joker_calls = {}, seen_restoring = {}, order = {}, luck = {}, events = {}, rerolls = {}, selects = 0}
  local ok, err = pcall(function()
    _G.G = {GAME = {round_resets = {blind_choices = {Boss = 'bl_hook'}}}, jokers = {},
      E_MANAGER = {add_event = function(_, e) ctx.events[#ctx.events + 1] = e end},
      -- Vanilla on the blind-select screen: the new boss is picked in a queued event.
      FUNCS = {reroll_boss = function()
        ctx.events[#ctx.events + 1] = {func = function()
          G.GAME.round_resets.blind_choices.Boss = ctx.next_boss; return true end}
        return 'rerolled'
      end}}
    _G.Event = function(def) return def end
    _G.create_UIBox_blind_select = function() return 'select_ui' end
    _G.Blind, _G.love, _G.SMODS = {}, {}, {}
    _G.end_round = function() end
    _G.ease_background_colour_blind = function() end
    _G.Card = {add_to_deck = function(self) self.added_to_deck = true; return 'added' end,
      use_consumeable = function() ctx.order[#ctx.order + 1] = 'original'; return 'used', 7 end}
    _G.Game = {start_run = function(self, args)
      ctx.seen_restoring[#ctx.seen_restoring + 1] = FinalBoss.tricks.restoring
      if args and args.boom then error('boom', 0) end
      return 'run', 2
    end}
    _G.FinalBoss = {
      util = {guard = function(_, fn, ...) return fn(...) end},
      mod = {},
      director = {enabled = function() return true end},
      tricks = {restoring = false, on_joker_added = function(card, from_debuff, was_added, in_jokers)
        ctx.joker_calls[#ctx.joker_calls + 1] = {card = card, from_debuff = from_debuff, was_added = was_added,
          in_jokers = in_jokers}
      end,
      snapshot = function(card) ctx.order[#ctx.order + 1] = 'snapshot'; return {of = card} end,
      on_consumable = function(card, before) ctx.order[#ctx.order + 1] = 'use'; ctx.use = {card, before} end},
      moments = {on_blind_select = function() ctx.selects = ctx.selects + 1 end,
        on_reroll = function(old, new) ctx.rerolls[#ctx.rerolls + 1] = old .. '>' .. new end,
        on_reroll_click = function(old)
          ctx.rerolls[#ctx.rerolls + 1] = 'click:' .. old .. '@' .. G.GAME.round_resets.blind_choices.Boss
        end},
      observe = {on_luck = function(kind, key) ctx.luck[#ctx.luck + 1] = {kind = kind, key = key} end},
    }
    package.loaded['src.hooks'] = nil
    require('src.hooks')
    f(ctx)
  end)
  for _, k in ipairs(NAMES) do _G[k] = saved[k] end
  package.loaded['src.hooks'] = nil
  if not ok then error(err, 0) end
end

T['add_to_deck: a new joker, then one transforming in the joker slots'] = function()
  with_hooks(function(ctx)
    local new = setmetatable({}, {__index = Card})
    eq(new:add_to_deck(), 'added', 'original result passed on')
    local c = ctx.joker_calls[1]
    eq(c.card, new); eq(c.was_added, nil); eq(c.in_jokers, false)
    local old = setmetatable({area = G.jokers}, {__index = Card})
    old:add_to_deck()
    eq(ctx.joker_calls[2].in_jokers, true, 'already in G.jokers before the call')
  end)
end

T['use_consumeable: snapshot before the original, passed to on_consumable after'] = function()
  with_hooks(function(ctx)
    local c = setmetatable({}, {__index = Card})
    local a, b = c:use_consumeable()
    eq(a, 'used'); eq(b, 7, 'all results passed on')
    eq(table.concat(ctx.order, ','), 'snapshot,original,use')
    eq(ctx.use[1], c); eq(ctx.use[2].of, c, 'the snapshot reaches on_consumable')
  end)
end

T['start_run: restoring only while a save loads, cleared after'] = function()
  with_hooks(function(ctx)
    local a, b = Game.start_run({}, {savetext = {}})
    eq(a, 'run'); eq(b, 2, 'all results passed on')
    eq(ctx.seen_restoring[1], true, 'set during a Continue')
    eq(FinalBoss.tricks.restoring, false, 'cleared after')
    Game.start_run({}, {})
    eq(ctx.seen_restoring[2], false, 'a new run is not a restore')
  end)
end

T['start_run: a consumable still waiting from the old run is dropped'] = function()
  with_hooks(function()
    FinalBoss.tricks.pending = {key = 'c_judgement', t = 1}
    Game.start_run({}, {})
    eq(FinalBoss.tricks.pending, nil)
  end)
end

-- Luck (1.4): smods' pseudorandom_result contexts reach the mod's calculate --------------------------

local function roll(identifier, result, obj)
  return {pseudorandom_result = true, result = result, identifier = identifier, trigger_obj = obj,
    numerator = 1, denominator = 5}
end
local LUCKY = {ability = {set = 'Enhanced', effect = 'Lucky Card'}, config = {center = {key = 'm_lucky'}}}
local BLOODSTONE = {ability = {set = 'Joker'}, config = {center = {key = 'j_bloodstone'}}}

T['calculate: a Lucky card mult and $20 payout, and a chance Joker hit, are luck'] = function()
  with_hooks(function(ctx)
    FinalBoss.mod.calculate(FinalBoss.mod, roll('lucky_mult', true, LUCKY))
    FinalBoss.mod.calculate(FinalBoss.mod, roll('lucky_money', true, LUCKY))
    FinalBoss.mod.calculate(FinalBoss.mod, roll('bloodstone', true, BLOODSTONE))
    eq(#ctx.luck, 3)
    eq(ctx.luck[1].kind, 'card'); eq(ctx.luck[2].kind, 'dollars')
    eq(ctx.luck[3].kind, 'joker'); eq(ctx.luck[3].key, 'j_bloodstone')
  end)
end

T['calculate: a guaranteed roll is not luck, a 1-in-2 roll is'] = function()
  with_hooks(function(ctx)
    local function odds(r, n, d) r.numerator = n; r.denominator = d; return r end
    FinalBoss.mod.calculate(FinalBoss.mod, odds(roll('j', true, BLOODSTONE), 2, 2))
    FinalBoss.mod.calculate(FinalBoss.mod, odds(roll('lucky_mult', true, LUCKY), 8, 5))
    eq(#ctx.luck, 0)
    FinalBoss.mod.calculate(FinalBoss.mod, odds(roll('j', true, BLOODSTONE), 1, 2))
    eq(#ctx.luck, 1)
  end)
end

T['calculate: a failed roll, a non-Joker roll or the Lucky card scoring context is not luck'] = function()
  with_hooks(function(ctx)
    FinalBoss.mod.calculate(FinalBoss.mod, roll('lucky_mult', false, LUCKY))
    FinalBoss.mod.calculate(FinalBoss.mod, roll('bloodstone', false, BLOODSTONE))
    FinalBoss.mod.calculate(FinalBoss.mod, roll('wheel_of_fortune', true,
      {ability = {set = 'Tarot'}, config = {center = {key = 'c_wheel_of_fortune'}}}))
    FinalBoss.mod.calculate(FinalBoss.mod, roll('glass', true, LUCKY))
    FinalBoss.mod.calculate(FinalBoss.mod, roll('lucky_mult', true, nil))
    -- The payout is counted from its roll (above), never again from the scoring context that follows.
    G.play = {}
    FinalBoss.mod.calculate(FinalBoss.mod, {individual = true, cardarea = G.play,
      other_card = {lucky_trigger = true, ability = LUCKY.ability}})
    eq(#ctx.luck, 0)
  end)
end

T['calculate: no luck while FinalBoss is disabled for the run'] = function()
  with_hooks(function(ctx)
    FinalBoss.director.enabled = function() return false end
    FinalBoss.mod.calculate(FinalBoss.mod, roll('lucky_mult', true, LUCKY))
    eq(#ctx.luck, 0)
  end)
end

T['start_run: an error is passed on unchanged'] = function()
  with_hooks(function()
    local ok, err = pcall(Game.start_run, {}, {savetext = {}, boom = true})
    eq(ok, false); eq(err, 'boom')
  end)
end

--- Run the queued events in order, like the base queue (each blocking event before the next).
local function run_events(ctx)
  local i = 1
  while ctx.events[i] do ctx.events[i].func(); i = i + 1 end
  ctx.events = {}
end

T['reroll_boss: on the blind-select screen, moments hears the click, then old and new once the swap ran'] = function()
  with_hooks(function(ctx)
    G.blind_select_opts = {boss = {}}
    ctx.next_boss = 'bl_wall'
    eq(G.FUNCS.reroll_boss(), 'rerolled', 'the original result')
    eq(table.concat(ctx.rerolls, ','), 'click:bl_hook@bl_hook', 'the click, the old boss still the Boss choice')
    run_events(ctx)
    eq(table.concat(ctx.rerolls, ','), 'click:bl_hook@bl_hook,bl_hook>bl_wall', 'then old and new after the swap')
  end)
end

T['reroll_boss: off the blind-select screen, no lines'] = function()
  with_hooks(function(ctx)
    ctx.next_boss = 'bl_wall'
    G.FUNCS.reroll_boss()
    run_events(ctx)
    eq(#ctx.rerolls, 0)
  end)
end

T['create_UIBox_blind_select: the screen tells moments, result unchanged'] = function()
  with_hooks(function(ctx)
    eq(create_UIBox_blind_select(), 'select_ui')
    eq(ctx.selects, 1)
  end)
end

return T
