-- moves.restore_marks under stubs (no game): on Continue the blind flag is recomputed through
-- SMODS.recalc_debuff, and only the cards the blind really debuffs get their curse mark back.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- cards: list of {debuff, blind} (blind: Blind:debuff_card would debuff it). Saved cards never
--- carry debuffed_by_blind. recalc: optional replacement for SMODS.recalc_debuff.
local function setup(cards, recalc)
  local ctx = {recalced = {}, marked = nil, logs = 0}
  local hand = {}
  for i, c in ipairs(cards) do
    hand[i] = {id = i, debuff = c[1], blind = c[2], ability = {}}
  end
  ctx.hand = hand
  _G.G = {hand = {cards = hand}}
  _G.SMODS = {recalc_debuff = recalc or function(c)
    ctx.recalced[#ctx.recalced + 1] = c.id
    c.debuff = c.blind and true or false
    c.debuffed_by_blind = c.blind and true or false
  end}
  package.loaded['src.logic'] = nil
  _G.FinalBoss = {logic = require('src.logic'),
    util = {log = function() ctx.logs = ctx.logs + 1 end, now = function() return 0 end}}
  package.loaded['src.moves'] = nil
  local M = require('src.moves')
  M.mark_cursed = function(_, list) ctx.marked = list end
  return M, ctx
end

local blind = {config = {blind = {key = 'bl_club'}}}

local function ids(list)
  local out = {}
  for _, c in ipairs(list or {}) do out[#out + 1] = c.id end
  return table.concat(out, ',')
end

T['restore_marks: recomputes the flag and marks only the cards the blind debuffs'] = function()
  -- 1: debuffed by the blind; 2: debuffed by something else (recalc keeps it, no flag);
  -- 3: not debuffed; 4: debuffed by the blind
  local M, ctx = setup({{true, true}, {true, false}, {false, false}, {true, true}}, nil)
  SMODS.recalc_debuff = function(c)
    ctx.recalced[#ctx.recalced + 1] = c.id
    c.debuffed_by_blind = c.blind and true or false
  end
  M.restore_marks(blind)
  eq(ids(ctx.marked), '1,4', 'marked')
  eq(table.concat(ctx.recalced, ','), '1,2,4', 'only debuffed cards are recomputed')
  eq(M.stamped[ctx.hand[1]], true, 'stamped: the next draw does not curse it anew')
  eq(M.stamped[ctx.hand[2]], nil, 'not stamped')
end

T['restore_marks: a stamped card is left alone; nothing to mark marks nothing'] = function()
  local M, ctx = setup({{true, true}})
  M.stamped[ctx.hand[1]] = true
  M.restore_marks(blind)
  eq(ctx.marked, nil, 'no mark')
  eq(#ctx.recalced, 0, 'no recompute')
end

T['restore_marks: never sets the flag itself; a failed recompute skips the card'] = function()
  local M, ctx = setup({{true, true}, {true, true}}, function(c)
    if c.id == 1 then error('boom') end
    c.debuffed_by_blind = true
  end)
  M.restore_marks(blind)
  eq(ids(ctx.marked), '2', 'only the recomputed card')
  eq(ctx.hand[1].debuffed_by_blind, nil, 'flag untouched')
  eq(ctx.logs, 1, 'failure logged')
end

T['restore_marks: no blind key does nothing'] = function()
  local M, ctx = setup({{true, true}})
  M.restore_marks({config = {}})
  eq(ctx.marked, nil)
  eq(#ctx.recalced, 0)
end

return T
