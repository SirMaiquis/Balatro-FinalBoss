-- director.lua under stubs (1.4): the winning hand's situation, the candidate hand that holds back the
-- live fear 1 and 2 lines, the defeat line react says, and the line hook's chips_before.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- A light-tier boss fight on bl_hook: round score o.chips of a 1000 requirement, o.hands_played hands
--- before this one (vanilla's count at context.after), o.hands_left after it, this hand scoring o.delta.
local function setup(o)
  o = o or {}
  local ctx = {fired = {}, fx = {}, defeat_line = o.defeat_line}
  local enc = {key = 'bl_hook', boss = true, tier = 'light', ended = false, fired = {}}
  ctx.enc = enc
  _G.Event = function(t) return t end
  _G.G = {
    GAME = {FinalBoss = {encounter = enc}, chips = o.chips or 0,
      blind = {chips = 1000, config = {blind = {key = 'bl_hook'}}},
      current_round = {hands_played = o.hands_played or 0, hands_left = o.hands_left or 3,
        discards_left = 1, discards_used = 0}},
    E_MANAGER = {add_event = function() end},
    STATES = {SELECTING_HAND = 1, HAND_PLAYED = 2}, STATE = 2,
    SETTINGS = {reduced_motion = false},
    play = {cards = {}},
  }
  _G.SMODS = {last_hand_score = o.delta or 0, last_hand_oneshot = false}
  package.loaded['src.logic'] = nil
  package.loaded['src.observe'] = nil
  package.loaded['src.director'] = nil
  _G.FinalBoss = {
    logic = require('src.logic'),
    config = {dialogue = true, dev_mode = false},
    util = {now = function() return 0 end, log = function() end,
      state = function() return G.GAME.FinalBoss end,
      guard = function(_, f, ...) return f(...) end},
    memory = {defeat_line = function() return ctx.defeat_line end},
    cinematic = {active = function() return false end},
    dialogue = {intro_active = function() return false end},
  }
  FinalBoss.observe = require('src.observe')
  ctx.D = require('src.director')
  FinalBoss.director = ctx.D
  ctx.D.fire = function(m, opts) ctx.fired[#ctx.fired + 1] = {moment = m, opts = opts or {}}; return true end
  ctx.D.fear_fx = function(_, _, t) ctx.fx[#ctx.fx + 1] = t end
  -- The hand: context.after, then the score lands (react).
  ctx.play = function()
    ctx.D.on_hand_after({scoring_name = 'Flush', full_hand = {1, 2, 3, 4, 5}})
    ctx.p = ctx.D.pending
    ctx.D.flush_pending()
  end
  return ctx
end

-- on_hand_after: the situation ------------------------------------------------------------------------

T['on_hand_after: a comeback on the second hand (vanilla counts this hand after context.after)'] = function()
  local ctx = setup{chips = 100, delta = 1000, hands_played = 1, hands_left = 2}
  ctx.D.on_hand_after({})
  eq(ctx.D.pending.situation, 'comeback', '100 < 25% of 1000, two hands played')
  eq(ctx.enc.candidate_hand, 1, 'the hand id on_hand_after books')
end

T['on_hand_after: a one-hand kill is never clutch or comeback'] = function()
  local ctx = setup{chips = 0, delta = 3000, hands_played = 0, hands_left = 0}
  ctx.D.on_hand_after({})
  eq(ctx.D.pending.situation, nil, 'the first hand of the blind')
  eq(ctx.enc.candidate_hand, nil)
end

T['on_hand_after: clutch on the last hand; photo finish; nothing'] = function()
  local ctx = setup{chips = 600, delta = 900, hands_played = 3, hands_left = 0}
  ctx.D.on_hand_after({})
  eq(ctx.D.pending.situation, 'clutch')
  eq(ctx.enc.candidate_hand, 3)
  ctx = setup{chips = 600, delta = 440, hands_played = 0, hands_left = 3}
  ctx.D.on_hand_after({})
  eq(ctx.D.pending.situation, 'photo_finish', '1040: 4% over, no hand floor')
  eq(ctx.enc.candidate_hand, nil)
  ctx = setup{chips = 600, delta = 900, hands_played = 2, hands_left = 1}
  ctx.D.on_hand_after({})
  eq(ctx.D.pending.situation, nil)
end

T['on_hand_after: a candidate hand that does not win has no situation'] = function()
  local ctx = setup{chips = 100, delta = 50, hands_played = 2, hands_left = 1}
  ctx.D.on_hand_after({})
  eq(ctx.D.pending.won, false); eq(ctx.D.pending.situation, nil)
  eq(ctx.enc.candidate_hand, 2, 'still a candidate: its live fear 1 and 2 are held back')
end

T['on_hand_after: an unknown score has no situation'] = function()
  local ctx = setup{chips = 100, delta = 'garbage', hands_played = 2, hands_left = 0}
  ctx.D.on_hand_after({})
  eq(ctx.D.pending.unknown, true); eq(ctx.D.pending.situation, nil)
end

T['on_hand_after: the candidate mark clears on the next hand'] = function()
  local ctx = setup{chips = 100, delta = 50, hands_played = 1, hands_left = 2}
  ctx.D.on_hand_after({})
  eq(ctx.enc.candidate_hand, 1)
  G.GAME.chips, G.GAME.current_round.hands_played = 400, 2
  ctx.D.on_hand_after({})
  eq(ctx.enc.candidate_hand, nil)
end

-- react: the defeat line ---------------------------------------------------------------------------------

T['react: a comeback says its line as the defeat moment, with no fear visuals'] = function()
  local ctx = setup{chips = 100, delta = 2900, hands_played = 1, hands_left = 2} -- 3000: 3x, fear 1
  ctx.play()
  eq(#ctx.fired, 1); eq(ctx.fired[1].moment, 'defeat'); eq(ctx.fired[1].opts.line, 'comeback')
  eq(#ctx.fx, 0); eq(ctx.enc.fear_said, nil, 'no fear tier booked')
end

T['react: no situation keeps the fear fallback and its visuals'] = function()
  local ctx = setup{chips = 0, delta = 15000, hands_played = 0, hands_left = 3} -- 15x, one-hand kill
  ctx.play()
  eq(ctx.fired[1].opts.line, 'fear_2'); eq(#ctx.fx, 1); eq(ctx.fx[1], 2)
end

T['react: the nemesis defeat line wins over a situation'] = function()
  local ctx = setup{chips = 100, delta = 2900, hands_played = 1, hands_left = 2, defeat_line = 'nemesis_defeat'}
  ctx.play()
  eq(ctx.fired[1].opts.line, 'nemesis_defeat')
end

T['react: a live fear 3 on a comeback hand stands, then the last words path'] = function()
  local ctx = setup{chips = 100, delta = 200000, hands_played = 1, hands_left = 2} -- 200x
  ctx.D.on_hand_after({})
  ctx.enc.fear_said, ctx.enc.fear_hand = 3, ctx.enc.last_hand_seen -- said live while scoring
  ctx.D.flush_pending()
  eq(#ctx.fired, 0, 'the 100x death: no defeat line (no finale on light tier)')
end

-- line_info: chips_before ----------------------------------------------------------------------------

T['line_info: chips_before is the score before the hand being resolved'] = function()
  local ctx = setup{chips = 100, delta = 2900, hands_played = 1, hands_left = 2}
  eq(ctx.D.line_info('bl_hook').chips_before, nil, 'no hand yet')
  ctx.D.on_hand_after({})
  eq(ctx.D.line_info('bl_hook').chips_before, 100, 'pending: a live line while it scores')
  local seen
  ctx.D.fire = function() seen = ctx.D.line_info('bl_hook').chips_before; return true end
  G.GAME.chips = 3000 -- the score landed
  ctx.D.flush_pending()
  eq(ctx.D.pending, nil)
  eq(seen, 100, 'the defeat line is resolved after the pending reaction is taken')
  eq(ctx.D.line_info('bl_hook').lucky, nil, 'Task 4 fills it')
  eq(ctx.D.line_info('bl_other').chips_before, nil, 'another boss: not its fight')
end

return T
