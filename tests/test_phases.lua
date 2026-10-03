-- phases.lua routing under stubs (no game): when a transformation starts, the weak-hit delay, the
-- timeline steps and their gates (reduced motion, Boss moves), Continue restore, F8 and reset.
local T = {}

local function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
  end
end

--- Fresh phases module with stubbed globals and a REAL-time event queue driven by ctx.advance(s).
local function setup(opts)
  opts = opts or {}
  local ctx = {calls = {}, args = {}, clock = 0, events = {}}
  local function rec(name, ret)
    return function(...)
      ctx.calls[#ctx.calls + 1] = name
      ctx.args[name] = {...}
      return ret
    end
  end
  function ctx.count(name)
    local n = 0
    for _, c in ipairs(ctx.calls) do if c == name then n = n + 1 end end
    return n
  end
  function ctx.advance(seconds)
    local stop = ctx.clock + seconds
    while true do
      local best
      for i, e in ipairs(ctx.events) do
        if e.at <= stop and (not best or e.at < ctx.events[best].at) then best = i end
      end
      if not best then break end
      local e = table.remove(ctx.events, best)
      ctx.clock = e.at
      e.func()
    end
    ctx.clock = stop
  end
  local key = opts.key or 'bl_final_x'
  local enc = {key = key, showdown = true, cinematic = true, fired = {}, ended = false,
    twists_on = opts.twists or false, twists = {applied = {}, leaf_sold = false}}
  local blind = {config = {blind = {key = key}}, chips = 1000}
  ctx.enc, ctx.blind = enc, blind
  -- hand cards / jokers for the twists (debuffed through the SMODS.debuff_card stub below)
  local function cards(n)
    local out = {}
    for i = 1, n do
      out[i] = {id = i, ability = {}, facing = 'front',
        flip = function(self) self.facing = (self.facing == 'front') and 'back' or 'front' end,
        set_debuff = function(self, d) self.debuff = d end, juice_up = function() end}
    end
    return out
  end
  ctx.hand, ctx.jokers = cards(opts.hand or 0), cards(opts.jokers or 0)
  _G.G = {SETTINGS = {reduced_motion = opts.reduced or false},
    GAME = {FinalBoss = {encounter = enc}, blind = blind, chips = 600},
    hand = {cards = ctx.hand, add_to_highlighted = function(_, c)
      ctx.calls[#ctx.calls + 1] = 'highlight'
      c.highlighted = true
    end},
    jokers = {cards = ctx.jokers, unhighlight_all = function() end, set_ranks = rec('set_ranks')},
    playing_cards = ctx.hand,
    E_MANAGER = {add_event = function(_, ev) ctx.events[#ctx.events + 1] = {at = ctx.clock + (ev.delay or 0), func = ev.func} end}}
  _G.Event = function(t) return t end
  _G.play_sound = rec('sound')
  _G.number_format = function(n) return tostring(n) end
  -- smods: a card is debuffed while a debuff source holds or (a joker) the Heart's flag is set
  -- (Blind:debuff_card as smods lovely/fixes.toml patches it)
  local function recalc(c)
    local any = c.ability.crimson_heart_chosen or false
    for _, v in pairs(c.ability.debuff_sources or {}) do any = any or v end
    c.debuff = any and true or false
  end
  _G.SMODS = {recalc_debuff = recalc, debuff_card = function(c, debuff, source)
    c.ability.debuff_sources = c.ability.debuff_sources or {}
    c.ability.debuff_sources[source] = debuff
    recalc(c)
  end}
  package.loaded['src.logic'] = nil
  _G.FinalBoss = {
    timescale = 1,
    logic = require('src.logic'),
    config = {cinematic = true, fx = true, moves = opts.moves ~= false},
    avatar = {exists = function() return not opts.no_avatar end, roar = rec('roar'), flash = rec('avatar_flash'),
      set_stance = rec('set_stance'), set_wound = rec('set_wound')},
    hpbar = {set_phase = rec('set_phase'), heal = rec('heal')},
    moves = {hold = rec('hold'), boss_colour = function() return {1, 0, 0, 1} end,
      performer = function() return {x = 0, y = 0, w = 1, h = 1} end, voice = function() return 1 end,
      signature = rec('signature')},
    effects = {ring = rec('ring'), glare = rec('glare')},
    curse = {mark = rec('curse_mark')},
    cinematic = {phase = nil},
    fx = {play = rec('fx_flash')},
    music = {duck = rec('duck'), unduck = rec('unduck')},
    director = {fire = rec('fire', true), num = function(x) return x end},
    arena = {state = {stage = 1}, on_hit = rec('arena_hit')},
    util = {guard = function(_, fn, ...) return pcall(fn, ...) end, log = function() end},
    -- records what the rule awards (achievements.lua runs it the same way)
    achievements = {award_from = function(_, rule, ...)
      for _, id in ipairs(rule(...)) do ctx.awarded[#ctx.awarded + 1] = id end
    end},
  }
  ctx.awarded = {}
  package.loaded['src.phases'] = nil
  return require('src.phases'), ctx
end

-- 1000 HP: a total of 600 leaves 40% (phase II), 800 leaves 20% (phase III).
local function hand(total, moment, hands_left)
  return {total = total, required = 1000, moment = moment, hands_left = hands_left or 2}
end

T['phases.check: crossing 50% starts phase II at once and records it'] = function()
  local P, ctx = setup()
  eq(P.check(ctx.enc, ctx.blind, hand(600)), true)
  eq(ctx.enc.phase, 2, 'enc.phase')
  eq(ctx.count('hold'), 1, 'moves held')
  eq(FinalBoss.timescale, P.SLOW, 'slow motion')
  ctx.advance(2)
  eq(FinalBoss.timescale, 1, 'time restored')
  eq(ctx.args.fire[1], 'phase2', 'phase line')
  eq(ctx.args.fire[2].force, true, 'forced')
  eq(ctx.args.set_stance[1], 2, 'stance')
  eq(ctx.args.set_phase[1], 2, 'marker')
  eq(ctx.count('signature'), 1, 'eruption')
  eq(ctx.count('roar'), 1, 'roar')
end

T['phases.check: no transformation above 50%, on the defeat hand or the last hand'] = function()
  local P, ctx = setup()
  eq(P.check(ctx.enc, ctx.blind, hand(300)), false, 'above 50%')
  eq(P.check(ctx.enc, ctx.blind, hand(1000, 'defeat')), false, 'defeat')
  eq(P.check(ctx.enc, ctx.blind, hand(600, nil, 0)), false, 'last hand')
  eq(ctx.enc.phase, nil, 'still phase I')
  eq(ctx.count('hold'), 0)
end

T['phases.check: both thresholds at once go straight to phase III, never back'] = function()
  local P, ctx = setup()
  eq(P.check(ctx.enc, ctx.blind, hand(800)), true)
  eq(ctx.enc.phase, 3)
  ctx.advance(2)
  eq(ctx.args.fire[1], 'phase3')
  eq(P.check(ctx.enc, ctx.blind, hand(600)), false, 'a heal never undoes a phase')
  eq(P.check(ctx.enc, ctx.blind, hand(900)), false, 'phase III is the last')
end

T['phases: Phase Skipper only for phase I to III in one hand'] = function()
  local P, ctx = setup()
  P.check(ctx.enc, ctx.blind, hand(800))
  eq(#ctx.awarded, 1); eq(ctx.awarded[1], 'fb_phase_skipper')
  P, ctx = setup()
  P.check(ctx.enc, ctx.blind, hand(600))
  ctx.advance(3)
  P.check(ctx.enc, ctx.blind, hand(800))
  eq(ctx.enc.phase, 3)
  eq(#ctx.awarded, 0, 'I to II, then II to III: no Phase Skipper')
end

T['phases.check: a weak hit waits for the laugh before transforming'] = function()
  local P, ctx = setup()
  eq(P.check(ctx.enc, ctx.blind, hand(600), 1.2), true)
  eq(ctx.enc.phase, 2, 'recorded at once (a save keeps it)')
  eq(ctx.count('hold'), 0, 'not started yet')
  eq(FinalBoss.timescale, 1, 'no slow motion during the laugh')
  ctx.advance(1.1)
  eq(ctx.count('hold'), 0, 'still waiting')
  ctx.advance(0.2)
  eq(ctx.count('hold'), 1, 'started after the laugh')
  ctx.advance(2)
  eq(ctx.args.fire[1], 'phase2')
end

T['phases.check: a reset during the laugh cancels the pending transformation'] = function()
  local P, ctx = setup()
  P.check(ctx.enc, ctx.blind, hand(600), 1.2)
  P.reset()
  ctx.advance(3)
  eq(ctx.count('hold'), 0)
  eq(ctx.count('fire'), 0)
end

T['phases.check: needs a cinematic showdown with the avatar out'] = function()
  local P, ctx = setup({no_avatar = true})
  eq(P.check(ctx.enc, ctx.blind, hand(600)), false, 'no avatar')
  P, ctx = setup()
  FinalBoss.config.cinematic = false
  eq(P.check(ctx.enc, ctx.blind, hand(600)), false, 'cinematics off')
  P, ctx = setup()
  ctx.enc.showdown = false
  eq(P.check(ctx.enc, ctx.blind, hand(600)), false, 'not a showdown')
end

T['phases.transform: reduced motion keeps flash, line, stance and marker only'] = function()
  local P, ctx = setup({reduced = true})
  P.transform(ctx.enc, ctx.blind, 2, 1)
  eq(FinalBoss.timescale, 1, 'no slow motion')
  ctx.advance(2)
  eq(ctx.count('roar'), 0, 'roar')
  eq(ctx.count('ring'), 0, 'rings')
  eq(ctx.count('signature'), 0, 'eruption')
  eq(ctx.count('fx_flash'), 1, 'flash')
  eq(ctx.count('fire'), 1, 'line')
  eq(ctx.count('set_stance'), 1, 'stance')
  eq(ctx.count('set_phase'), 1, 'marker')
end

T['phases.transform: Boss moves off skips the eruption only'] = function()
  local P, ctx = setup({moves = false})
  P.transform(ctx.enc, ctx.blind, 2, 1)
  ctx.advance(2)
  eq(ctx.count('signature'), 0, 'eruption')
  eq(ctx.count('roar'), 1, 'roar')
  eq(ctx.count('fire'), 1, 'line')
end

T['phases.transform: the encounter ending stops the rest but restores time and music'] = function()
  local P, ctx = setup()
  P.transform(ctx.enc, ctx.blind, 2, 1)
  ctx.enc.ended = true
  ctx.advance(2)
  eq(ctx.count('fire'), 0, 'line')
  eq(ctx.count('set_stance'), 0, 'stance')
  eq(FinalBoss.timescale, 1, 'time')
  eq(ctx.count('unduck') >= 1, true, 'music')
end

T['phases.transform: the slow-motion restore never clobbers the finale'] = function()
  local P, ctx = setup()
  P.transform(ctx.enc, ctx.blind, 2, 1)
  -- the finale took the time over with the same 0.35 (cinematic.play_finale)
  FinalBoss.timescale = 0.35
  FinalBoss.cinematic.phase = 'finale'
  ctx.advance(2)
  eq(FinalBoss.timescale, 0.35)
end

T['phases.reset: never cuts the finale slow motion'] = function()
  local P, ctx = setup()
  P.transform(ctx.enc, ctx.blind, 2, 1)
  FinalBoss.timescale = 0.35
  FinalBoss.cinematic.phase = 'finale'
  P.reset()
  eq(FinalBoss.timescale, 0.35)
  ctx.advance(2)
  eq(FinalBoss.timescale, 0.35, 'nor the later restore')
end

T['phases: the finale stops a running transformation and refuses F8'] = function()
  local P, ctx = setup()
  P.transform(ctx.enc, ctx.blind, 2, 1)
  ctx.enc.finale = true
  ctx.advance(2)
  eq(ctx.count('fire'), 0, 'line')
  eq(ctx.count('set_stance'), 0, 'stance')
  eq(P.force_next(), nil, 'F8')
end

T['phases.check: the winning hand never transforms, whatever the moment'] = function()
  local P, ctx = setup()
  eq(P.check(ctx.enc, ctx.blind, hand(1000)), false, 'exactly the requirement')
  eq(P.check(ctx.enc, ctx.blind, hand(1500, 'big_hit')), false, 'overkill')
  eq(ctx.enc.phase, nil)
end

T['phases: a disabled final boss (Chicot) never transforms'] = function()
  local P, ctx = setup()
  ctx.blind.disabled = true
  eq(P.check(ctx.enc, ctx.blind, hand(600)), false, 'check')
  eq(P.force_next(), nil, 'F8')
  ctx.enc.phase = 2
  P.restore(ctx.enc, ctx.blind)
  eq(ctx.count('set_stance'), 0, 'no restore')
end

T['phases: Verdant Leaf disabled by a joker sale keeps transforming'] = function()
  local P, ctx = setup({key = 'bl_final_leaf'})
  P.on_disable(ctx.blind, true)
  ctx.blind.disabled = true
  eq(ctx.enc.twists.leaf_sold, true)
  eq(P.check(ctx.enc, ctx.blind, hand(600)), true)
end

-- Twists ------------------------------------------------------------------------------------------

T['twists: Violet Vessel heals 10% of the original requirement once per phase'] = function()
  local P, ctx = setup({key = 'bl_final_vessel', twists = true})
  ctx.enc.phase = 2
  P.apply_once(ctx.enc, ctx.blind, 2)
  eq(ctx.blind.chips, 1100)
  eq(ctx.blind.chip_text, '1100')
  eq(ctx.args.heal[1], 600, 'bar total')
  eq(ctx.args.heal[2], 1100, 'bar requirement')
  P.apply_once(ctx.enc, ctx.blind, 2)
  eq(ctx.blind.chips, 1100, 'never twice (Continue)')
  ctx.enc.phase = 3
  P.apply_once(ctx.enc, ctx.blind, 3)
  eq(ctx.blind.chips, 1200, '10% of the ORIGINAL requirement')
end

T['twists: off, phase I or a disabled blind apply nothing'] = function()
  local P, ctx = setup({key = 'bl_final_vessel'})
  ctx.enc.phase = 2
  P.apply_once(ctx.enc, ctx.blind, 2)
  eq(ctx.blind.chips, 1000, 'twists off')
  P, ctx = setup({key = 'bl_final_vessel', twists = true})
  P.apply_once(ctx.enc, ctx.blind, 2)
  eq(ctx.blind.chips, 1000, 'phase I')
  ctx.enc.phase = 2
  ctx.blind.disabled = true
  P.apply_once(ctx.enc, ctx.blind, 2)
  eq(ctx.blind.chips, 1000, 'disabled')
end

T['twists: the transformation return step applies the one-shot twist'] = function()
  local P, ctx = setup({key = 'bl_final_vessel', twists = true})
  P.transform(ctx.enc, ctx.blind, 2, 1)
  eq(ctx.blind.chips, 1000, 'not before the return')
  ctx.advance(2)
  eq(ctx.blind.chips, 1100)
end

T['twists: Amber Acorn hides the jokers again and shuffles them three times'] = function()
  local P, ctx = setup({key = 'bl_final_acorn', twists = true, jokers = 3})
  ctx.enc.phase = 2
  ctx.jokers[1].facing = 'back'
  P.apply_once(ctx.enc, ctx.blind, 2)
  for i, j in ipairs(ctx.jokers) do eq(j.facing, 'back', 'joker ' .. i) end
  ctx.advance(2)
  eq(ctx.count('set_ranks'), 3, 'three shuffles')
  eq(#G.jokers.cards, 3, 'same jokers')
end

T['twists: Verdant Leaf regrows on 1 (II) / 2 (III) cards per draw after a sale, re-rolled'] = function()
  local P, ctx = setup({key = 'bl_final_leaf', twists = true, hand = 5})
  ctx.enc.phase = 2
  local function withered()
    local n = 0
    for _, c in ipairs(ctx.hand) do
      if c.debuff and c.ability.debuff_sources[P.LEAF_SOURCE] then n = n + 1 end
    end
    return n
  end
  P.on_drawn(ctx.blind, {})
  eq(withered(), 0, 'with its power the leaf already debuffs everything')
  P.on_disable(ctx.blind, true)
  ctx.blind.disabled = true
  P.on_drawn(ctx.blind, {})
  eq(withered(), 1, 'phase II')
  eq(ctx.args.curse_mark[2], 'vine', 'vine mark')
  eq(ctx.args.curse_mark[5], true, 'fresh mark')
  P.on_drawn(ctx.blind, {})
  eq(withered(), 1, 're-rolled, not piled up')
  ctx.enc.phase = 3
  P.on_drawn(ctx.blind, {})
  eq(withered(), 2, 'phase III')
  P.clear_twists()
  eq(withered(), 0, 'cleared when the fight ends')
end

T['twists: a Chicot-disabled Leaf (no sale) gets no regrowth'] = function()
  local P, ctx = setup({key = 'bl_final_leaf', twists = true, hand = 5})
  ctx.enc.phase = 2
  P.on_disable(ctx.blind, false)
  ctx.blind.disabled = true
  P.on_drawn(ctx.blind, {})
  eq(ctx.count('curse_mark'), 0)
end

--- smods' Crimson Heart draw (lovely/fixes.toml:265-310): un-flag last hand's chosen jokers, then flag
--- one joker that is not debuffed and was not chosen last hand (first one: deterministic).
local function heart_draw(jokers)
  local prev = {}
  for _, j in ipairs(jokers) do
    if j.ability.crimson_heart_chosen then
      prev[j] = true
      j.ability.crimson_heart_chosen = nil
      SMODS.recalc_debuff(j)
    end
  end
  for _, j in ipairs(jokers) do
    if not j.debuff and not prev[j] then
      j.ability.crimson_heart_chosen = true
      SMODS.recalc_debuff(j)
      return
    end
  end
end

T['twists: Crimson Heart disables one more joker after a played hand; phase III beams it'] = function()
  local P, ctx = setup({key = 'bl_final_heart', twists = true, jokers = 5})
  ctx.enc.phase = 2
  local function off()
    local n = 0
    for _, j in ipairs(ctx.jokers) do if j.debuff then n = n + 1 end end
    return n
  end
  P.on_drawn(ctx.blind, {prepped = false})
  eq(off(), 0, 'only after a played hand')
  heart_draw(ctx.jokers)
  P.on_drawn(ctx.blind, {prepped = true})
  eq(off(), 2, "the Heart's pick and the twist's")
  eq(ctx.count('glare'), 0, 'no beam in phase II')
  ctx.enc.phase = 3
  heart_draw(ctx.jokers)
  P.on_drawn(ctx.blind, {prepped = true})
  eq(off(), 2, 'phase III')
  eq(ctx.count('glare'), 1, 'beam in phase III')
end

T['twists: the Heart twist uses the flag, so it never piles up'] = function()
  local P, ctx = setup({key = 'bl_final_heart', twists = true, jokers = 5})
  ctx.enc.phase = 2
  for hand_no = 1, 6 do
    heart_draw(ctx.jokers)
    P.on_drawn(ctx.blind, {prepped = true})
    local n = 0
    for _, j in ipairs(ctx.jokers) do
      if j.debuff then
        n = n + 1
        eq(j.ability.crimson_heart_chosen, true, 'every disabled joker carries the flag')
      end
    end
    eq(n, 2, 'hand ' .. hand_no)
  end
end

T['twists: Cerulean Bell keeps two cards forced and selected'] = function()
  local P, ctx = setup({key = 'bl_final_bell', twists = true, hand = 6})
  ctx.enc.phase = 2
  ctx.hand[1].ability.forced_selection = true -- vanilla's own, selected
  ctx.hand[1].highlighted = true
  P.on_drawn(ctx.blind, {})
  local n = 0
  for _, c in ipairs(ctx.hand) do
    if c.ability.forced_selection then
      n = n + 1
      eq(c.highlighted, true, 'forced card ' .. c.id .. ' selected')
    end
  end
  eq(n, 2)
  eq(ctx.count('highlight'), 1)
end

T['twists: Cerulean Bell also selects a forced card left unselected'] = function()
  local P, ctx = setup({key = 'bl_final_bell', twists = true, hand = 6})
  ctx.enc.phase = 2
  ctx.hand[2].ability.forced_selection = true
  ctx.hand[4].ability.forced_selection = true
  ctx.hand[2].highlighted = true -- vanilla re-selects only while nothing is selected
  P.on_drawn(ctx.blind, {})
  eq(ctx.hand[4].highlighted, true)
  eq(ctx.count('highlight'), 1, 'no new forced card, one selection')
end

T['twists: applied keys are strings (saved data)'] = function()
  local P, ctx = setup({key = 'bl_final_vessel', twists = true})
  ctx.enc.phase = 2
  P.apply_once(ctx.enc, ctx.blind, 2)
  eq(ctx.enc.twists.applied['2'], true)
  eq(ctx.enc.twists.applied[2], nil)
end

T['twists: a hand that skips phase II applies II and III'] = function()
  local P, ctx = setup({key = 'bl_final_vessel', twists = true})
  P.transform(ctx.enc, ctx.blind, 3, 1)
  ctx.advance(2)
  eq(ctx.blind.chips, 1200, 'healed 10% twice')
  eq(ctx.enc.twists.applied['2'], true)
  eq(ctx.enc.twists.applied['3'], true)
end

T['twists: Continue applies a one-shot twist a save cut off, once'] = function()
  local P, ctx = setup({key = 'bl_final_vessel', twists = true})
  ctx.enc.phase = 2 -- saved before the return step
  P.restore(ctx.enc, ctx.blind)
  eq(ctx.blind.chips, 1100)
  P.restore(ctx.enc, ctx.blind)
  eq(ctx.blind.chips, 1100, 'never twice')
end

T['twists: Continue rebuilds the Leaf vines on withered hand cards'] = function()
  local P, ctx = setup({key = 'bl_final_leaf', twists = true, hand = 4})
  ctx.enc.phase = 2
  ctx.enc.twists.leaf_sold = true
  ctx.blind.disabled = true
  SMODS.debuff_card(ctx.hand[3], true, P.LEAF_SOURCE)
  P.restore(ctx.enc, ctx.blind)
  eq(ctx.count('curse_mark'), 1)
  eq(#ctx.args.curse_mark[1], 1, 'one card')
  eq(ctx.args.curse_mark[1][1], ctx.hand[3])
  eq(ctx.args.curse_mark[2], 'vine')
end

T['twists: Continue selects the Bell forced cards again'] = function()
  local P, ctx = setup({key = 'bl_final_bell', twists = true, hand = 5})
  ctx.enc.phase = 2
  ctx.hand[1].ability.forced_selection = true
  ctx.hand[5].ability.forced_selection = true
  P.restore(ctx.enc, ctx.blind)
  ctx.advance(0)
  eq(ctx.hand[1].highlighted, true)
  eq(ctx.hand[5].highlighted, true)
end

T['twists: clear_twists is safe with nothing to clear or no blind'] = function()
  local P, ctx = setup({hand = 3})
  P.clear_twists()
  G.playing_cards = nil
  P.clear_twists()
  G.playing_cards = ctx.hand
  ctx.hand[1].ability.debuff_sources = {[P.LEAF_SOURCE] = true}
  G.GAME.blind = nil -- run teardown
  P.clear_twists()
  eq(ctx.hand[1].ability.debuff_sources[P.LEAF_SOURCE], nil)
end

T['phases.restore: stance and marker come back without replaying; 1.0 saves stay phase I'] = function()
  local P, ctx = setup()
  P.restore(ctx.enc, ctx.blind)
  eq(#ctx.calls, 0, 'no enc.phase: nothing')
  ctx.enc.phase = 3
  P.restore(ctx.enc, ctx.blind)
  eq(ctx.args.set_stance[1], 3)
  eq(ctx.args.set_phase[1], 3)
  eq(ctx.count('hold') + ctx.count('fire') + ctx.count('roar'), 0, 'no replay')
end

T['phases.force_next: II, then III, then nil'] = function()
  local P, ctx = setup()
  eq(P.force_next(), 2)
  ctx.advance(2)
  eq(P.force_next(), 3)
  ctx.advance(2)
  eq(P.force_next(), nil)
  eq(ctx.count('fire'), 2)
end

T['phases.reset: restores our slow motion and the music'] = function()
  local P, ctx = setup()
  P.transform(ctx.enc, ctx.blind, 2, 1)
  P.reset()
  eq(FinalBoss.timescale, 1)
  eq(ctx.count('unduck'), 1)
  ctx.advance(2)
  eq(ctx.count('fire'), 0, 'pending steps cancelled')
end

return T
