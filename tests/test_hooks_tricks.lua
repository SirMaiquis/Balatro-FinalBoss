-- hooks.lua's trick wraps under stubs (no game): Card:add_to_deck passes what it read before the
-- original ran, Game:start_run sets and always clears the restoring flag.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

local NAMES = {'G', 'FinalBoss', 'Blind', 'Card', 'Game', 'love', 'SMODS', 'end_round',
  'ease_background_colour_blind'}

--- Load hooks.lua over stub engine tables; run f(ctx); put the globals back.
local function with_hooks(f)
  local saved = {}
  for _, k in ipairs(NAMES) do saved[k] = _G[k] end
  local ctx = {joker_calls = {}, seen_restoring = {}, order = {}}
  local ok, err = pcall(function()
    _G.G = {GAME = {}, jokers = {}}
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

T['start_run: an error is passed on unchanged'] = function()
  with_hooks(function()
    local ok, err = pcall(Game.start_run, {}, {savetext = {}, boom = true})
    eq(ok, false); eq(err, 'boom')
  end)
end

return T
