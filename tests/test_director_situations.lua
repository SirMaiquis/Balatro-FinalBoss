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
  local ctx = {fired = {}, fx = {}, hype = {}, defeat_line = o.defeat_line}
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
    hype = {play = function(kind, opts) ctx.hype[#ctx.hype + 1] = {kind = kind, opts = opts} end},
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
  ctx.enc.hype_said = true -- (1.4: else its meltdown line replaces it)
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
  eq(ctx.D.line_info('bl_other').chips_before, nil, 'another boss: not its fight')
end

-- Luck and hype (1.4) ------------------------------------------------------------------------------------

--- A hand that does not win (no moment: 50 of 1000, three hands left) with luck l tallied while it scored.
local function lucky_hand(ctx, l, hands_played)
  G.GAME.current_round.hands_played = hands_played or G.GAME.current_round.hands_played
  ctx.enc.luck = l
  ctx.play()
end

T['on_hand_after: the hand takes the luck tally, the next hand starts a fresh one'] = function()
  local ctx = setup{chips = 0, delta = 50, hands_played = 0, hands_left = 3}
  eq(ctx.D.line_info('bl_hook').lucky, nil, 'no hand yet')
  ctx.enc.luck = {cards = 1, dollars = 1, joker = 'j_bloodstone'}
  ctx.D.on_hand_after({})
  eq(ctx.D.pending.luck.cards, 1); eq(ctx.D.pending.luck.joker, 'j_bloodstone')
  eq(ctx.enc.luck.cards, 0); eq(ctx.enc.luck.joker, nil, 'reset after it is read')
  local info = ctx.D.line_info('bl_hook').lucky
  eq(info.cards, 1); eq(info.dollars, 1); eq(info.joker, 'j_bloodstone')
  info.cards = 99
  eq(ctx.D.line_info('bl_hook').lucky.cards, 1, 'a fresh table each time')
  ctx.D.flush_pending()
  G.GAME.current_round.hands_played = 1
  ctx.D.on_hand_after({})
  eq(ctx.D.pending.luck.cards, 0, 'no luck seen: an empty tally')
  eq(ctx.D.line_info('bl_hook').lucky.cards, 0)
end

T['react: two Lucky payouts say lucky_cards as the hand line; a chance Joker lucky_joker'] = function()
  local ctx = setup{chips = 0, delta = 50, hands_played = 0, hands_left = 3}
  lucky_hand(ctx, {cards = 2, dollars = 0})
  eq(#ctx.fired, 1); eq(ctx.fired[1].moment, 'lucky_cards'); eq(ctx.fired[1].opts.hand, 0)
  eq(#ctx.hype, 0, 'not stacked: no hype')
  ctx = setup{chips = 0, delta = 50, hands_played = 0, hands_left = 3}
  lucky_hand(ctx, {cards = 0, dollars = 0, joker = 'j_space'})
  eq(ctx.fired[1].moment, 'lucky_joker')
  ctx = setup{chips = 0, delta = 50, hands_played = 0, hands_left = 3}
  lucky_hand(ctx, {cards = 0, dollars = 1})
  eq(ctx.fired[1].moment, 'lucky_cards', 'a $20 payout alone')
end

T['react: the luck line follows the normal gate, else the hand may still get its comment'] = function()
  local ctx = setup{chips = 0, delta = 50, hands_played = 0, hands_left = 3}
  ctx.enc.fired.lucky_cards = true -- once per blind
  lucky_hand(ctx, {cards = 2, dollars = 0})
  for _, f in ipairs(ctx.fired) do assert(f.moment ~= 'lucky_cards', 'lucky_cards said twice') end
  ctx = setup{chips = 0, delta = 50, hands_played = 4, hands_left = 3}
  ctx.enc.last_line_hand = 3 -- light tier: a line on the previous hand
  lucky_hand(ctx, {cards = 2, dollars = 0})
  for _, f in ipairs(ctx.fired) do assert(f.moment ~= 'lucky_cards', 'two hands in a row') end
end

T['react: stacked luck on a hand that does not win: LUCKY! with the meltdown visuals, the luck line'] = function()
  local ctx = setup{chips = 0, delta = 50, hands_played = 0, hands_left = 3}
  lucky_hand(ctx, {cards = 3, dollars = 0})
  eq(#ctx.hype, 1); eq(ctx.hype[1].kind, 'lucky'); eq(ctx.hype[1].opts.meltdown, true)
  eq(ctx.hype[1].opts.enc, ctx.enc); eq(ctx.hype[1].opts.blind, G.GAME.blind)
  eq(ctx.fired[1].moment, 'lucky_cards'); eq(ctx.fired[1].opts.line, nil, 'not the meltdown line')
  eq(ctx.enc.hype_said, true)
end

T['react: at most one hype per blind'] = function()
  local ctx = setup{chips = 0, delta = 50, hands_played = 0, hands_left = 3}
  lucky_hand(ctx, {cards = 1, dollars = 1, joker = 'j_8_ball'})
  eq(#ctx.hype, 1, '$20 with a chance Joker: stacked')
  lucky_hand(ctx, {cards = 3, dollars = 0}, 2)
  eq(#ctx.hype, 1, 'the second stacked hand plays none')
  G.GAME.chips, G.GAME.current_round.hands_played, G.GAME.current_round.hands_left = 100, 3, 1
  SMODS.last_hand_score = 2900 -- a comeback kill
  ctx.play()
  eq(#ctx.hype, 1, 'nor the comeback')
  local last = ctx.fired[#ctx.fired]
  eq(last.moment, 'defeat'); eq(last.opts.line, 'comeback', 'no meltdown: its own defeat line')
end

T['react: a comeback or clutch kill melts down: the meltdown line replaces the defeat line'] = function()
  local ctx = setup{chips = 100, delta = 2900, hands_played = 1, hands_left = 2}
  ctx.play()
  eq(#ctx.hype, 1); eq(ctx.hype[1].kind, 'comeback'); eq(ctx.hype[1].opts.meltdown, true)
  eq(#ctx.fired, 1); eq(ctx.fired[1].moment, 'defeat'); eq(ctx.fired[1].opts.line, 'meltdown')
  ctx = setup{chips = 600, delta = 900, hands_played = 3, hands_left = 0}
  ctx.play()
  eq(ctx.hype[1].kind, 'clutch'); eq(ctx.fired[1].opts.line, 'meltdown')
end

T['react: a photo finish shows its text, no meltdown, with its own defeat line'] = function()
  local ctx = setup{chips = 600, delta = 440, hands_played = 0, hands_left = 3}
  ctx.play()
  eq(ctx.hype[1].kind, 'photo_finish'); eq(ctx.hype[1].opts.meltdown, false)
  eq(ctx.fired[1].opts.line, 'photo_finish')
end

T['react: a killing hand drops its luck line; stacked luck shows LUCKY! with the defeat line'] = function()
  local ctx = setup{chips = 0, delta = 1500, hands_played = 0, hands_left = 3} -- 1.5x, one-hand kill
  ctx.enc.luck = {cards = 2, dollars = 0}
  ctx.play()
  eq(#ctx.fired, 1); eq(ctx.fired[1].moment, 'defeat'); eq(ctx.fired[1].opts.line, nil)
  eq(#ctx.hype, 0, 'not stacked, no situation')
  ctx = setup{chips = 0, delta = 1500, hands_played = 0, hands_left = 3}
  ctx.enc.luck = {cards = 3, dollars = 0}
  ctx.play()
  eq(ctx.hype[1].kind, 'lucky'); eq(ctx.hype[1].opts.meltdown, false, 'text only on a kill')
  eq(ctx.fired[1].moment, 'defeat'); eq(ctx.fired[1].opts.line, nil)
end

T['react: a 100x kill is an overkill: the hype plays, the last words path is unchanged'] = function()
  local ctx = setup{chips = 0, delta = 200000, hands_played = 0, hands_left = 3} -- 200x, fallback tier
  ctx.play()
  eq(#ctx.hype, 1); eq(ctx.hype[1].kind, 'overkill'); eq(ctx.hype[1].opts.meltdown, false)
  eq(#ctx.fired, 0, 'no defeat line: the last words come with the death')
  ctx = setup{chips = 100, delta = 200000, hands_played = 1, hands_left = 2}
  ctx.D.on_hand_after({})
  ctx.enc.fear_said, ctx.enc.fear_hand = 3, ctx.enc.last_hand_seen -- said live while scoring
  ctx.D.flush_pending()
  eq(#ctx.hype, 1); eq(ctx.hype[1].kind, 'overkill', 'a live fear 3 crossing beats the comeback')
  eq(#ctx.fired, 0)
end

T['react: a live fear 2 that stands still gets the hype of the kill'] = function()
  local ctx = setup{chips = 0, delta = 15000, hands_played = 0, hands_left = 3} -- 15x
  ctx.enc.luck = {cards = 3, dollars = 0}
  ctx.D.on_hand_after({})
  ctx.enc.fear_said, ctx.enc.fear_hand = 2, ctx.enc.last_hand_seen
  ctx.D.flush_pending()
  eq(#ctx.fired, 0, 'the live fear line stands')
  eq(ctx.hype[1].kind, 'lucky'); eq(ctx.hype[1].opts.meltdown, false)
end

T['react: a nemesis comeback keeps its own line; the hype visuals still play'] = function()
  local ctx = setup{chips = 100, delta = 2900, hands_played = 1, hands_left = 2, defeat_line = 'nemesis_defeat'}
  ctx.play()
  eq(ctx.fired[1].opts.line, 'nemesis_defeat')
  eq(ctx.hype[1].kind, 'comeback'); eq(ctx.hype[1].opts.meltdown, true)
  eq(ctx.enc.fear_said, nil, 'nothing booked for the nemesis')
end

T['react: an interrupted hand that does not win gets neither its luck line nor a hype'] = function()
  local ctx = setup{chips = 0, delta = 50, hands_played = 0, hands_left = 3}
  ctx.enc.interrupt_hand = 0
  lucky_hand(ctx, {cards = 3, dollars = 0})
  eq(#ctx.fired, 0); eq(#ctx.hype, 0); eq(ctx.enc.hype_said, nil)
  ctx = setup{chips = 100, delta = 2900, hands_played = 1, hands_left = 2}
  ctx.enc.interrupt_hand = 1
  ctx.play()
  eq(ctx.hype[1].kind, 'comeback', 'a killing hand still plays it')
  eq(ctx.fired[1].opts.line, 'meltdown')
end

-- 1.4 playtest: the live crossing came before this hand's context.after ---------------------------------

--- Play is clicked on hand id 1 (hands_left 3 before it; observe.on_play), the base preview shows
--- (current_hand chips x mult) and fear_tick runs before on_hand_after; then context.after and react.
local function gap_hand(ctx, chips, mult)
  ctx.enc.last_hand_seen = 0 -- the previous hand
  G.GAME.current_round.hands_played, G.GAME.current_round.hands_left = 1, 3
  FinalBoss.observe.on_play()
  G.GAME.current_round.hands_left = 2 -- vanilla's queued -1
  G.GAME.current_round.current_hand = {chips = chips, mult = mult}
  FinalBoss.observe.fear_tick()
end

T['react: a fear 3 crossed before on_hand_after plays the overkill, no defeat line (playtest)'] = function()
  local ctx = setup{chips = 0, delta = 2909110, hands_played = 1, hands_left = 2}
  G.GAME.blind.chips = 22000
  gap_hand(ctx, 6910, 421) -- 2.9M of 22,000: past 100x at the click
  eq(#ctx.fired, 1); eq(ctx.fired[1].moment, 'fear_3', 'said live')
  ctx.play()
  eq(#ctx.hype, 1, 'a hype'); eq(ctx.hype[1].kind, 'overkill', 'the overkill')
  eq(#ctx.fired, 1, 'no defeat line: the last words come with the death')
  eq(ctx.D.death_tier(ctx.enc, ctx.p.total, ctx.p.required), 3, 'the 100x death')
end

T['react: a fear 1 crossed before on_hand_after on a candidate hand is held back (playtest)'] = function()
  local ctx = setup{chips = 100, delta = 2900, hands_played = 1, hands_left = 2}
  gap_hand(ctx, 100, 25) -- 100 + 2500: 2.6x on a comeback candidate (100 < 25% of 1000)
  eq(#ctx.fired, 0, 'held back'); eq(ctx.enc.fear_said, nil)
  ctx.play()
  eq(ctx.p.situation, 'comeback')
  eq(#ctx.hype, 1); eq(ctx.hype[1].kind, 'comeback'); eq(ctx.hype[1].opts.meltdown, true)
  eq(#ctx.fired, 1); eq(ctx.fired[1].opts.line, 'meltdown', 'the comeback meltdown line, no fear line')
end

return T
